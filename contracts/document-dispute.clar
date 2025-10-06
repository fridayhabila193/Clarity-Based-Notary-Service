(define-constant err-dispute-not-found (err u500))
(define-constant err-dispute-closed (err u501))
(define-constant err-insufficient-stake (err u502))
(define-constant err-already-voted (err u503))
(define-constant err-document-not-found (err u504))
(define-constant err-invalid-vote (err u505))
(define-constant err-unauthorized (err u506))

(define-constant dispute-stake-amount u5000000)
(define-constant voting-period-blocks u1440)
(define-constant min-votes-required u5)

(define-data-var next-dispute-id uint u1)

(define-map disputes
  { dispute-id: uint }
  {
    document-id: uint,
    challenger: principal,
    dispute-reason: (string-ascii 200),
    stake-amount: uint,
    created-at-block: uint,
    voting-ends-at-block: uint,
    total-votes: uint,
    votes-uphold: uint,
    votes-reject: uint,
    resolved: bool,
    outcome: (optional bool)
  }
)

(define-map dispute-votes
  { dispute-id: uint, voter: principal }
  {
    vote-direction: bool,
    voted-at-block: uint,
    voter-reputation: uint
  }
)

(define-map document-disputes
  { document-id: uint }
  {
    total-disputes: uint,
    active-dispute-id: (optional uint),
    upheld-disputes: uint
  }
)

(define-public (raise-dispute (document-id uint) (reason (string-ascii 200)))
  (let
    (
      (dispute-id (var-get next-dispute-id))
      (current-block stacks-block-height)
      (voting-deadline (+ current-block voting-period-blocks))
      (doc-disputes (default-to { total-disputes: u0, active-dispute-id: none, upheld-disputes: u0 }
                     (map-get? document-disputes { document-id: document-id })))
    )
    (asserts! (> (len reason) u0) err-invalid-vote)
    (asserts! (is-none (get active-dispute-id doc-disputes)) err-dispute-closed)
    
    (try! (stx-transfer? dispute-stake-amount tx-sender (as-contract tx-sender)))
    
    (map-set disputes
      { dispute-id: dispute-id }
      {
        document-id: document-id,
        challenger: tx-sender,
        dispute-reason: reason,
        stake-amount: dispute-stake-amount,
        created-at-block: current-block,
        voting-ends-at-block: voting-deadline,
        total-votes: u0,
        votes-uphold: u0,
        votes-reject: u0,
        resolved: false,
        outcome: none
      }
    )
    
    (map-set document-disputes
      { document-id: document-id }
      {
        total-disputes: (+ (get total-disputes doc-disputes) u1),
        active-dispute-id: (some dispute-id),
        upheld-disputes: (get upheld-disputes doc-disputes)
      }
    )
    
    (var-set next-dispute-id (+ dispute-id u1))
    (ok dispute-id)
  )
)

(define-public (vote-on-dispute (dispute-id uint) (vote-uphold bool) (voter-reputation uint))
  (let
    (
      (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) err-dispute-not-found))
      (current-block stacks-block-height)
      (existing-vote (map-get? dispute-votes { dispute-id: dispute-id, voter: tx-sender }))
    )
    (asserts! (not (get resolved dispute)) err-dispute-closed)
    (asserts! (< current-block (get voting-ends-at-block dispute)) err-dispute-closed)
    (asserts! (is-none existing-vote) err-already-voted)
    
    (map-set dispute-votes
      { dispute-id: dispute-id, voter: tx-sender }
      {
        vote-direction: vote-uphold,
        voted-at-block: current-block,
        voter-reputation: voter-reputation
      }
    )
    
    (map-set disputes
      { dispute-id: dispute-id }
      {
        document-id: (get document-id dispute),
        challenger: (get challenger dispute),
        dispute-reason: (get dispute-reason dispute),
        stake-amount: (get stake-amount dispute),
        created-at-block: (get created-at-block dispute),
        voting-ends-at-block: (get voting-ends-at-block dispute),
        total-votes: (+ (get total-votes dispute) u1),
        votes-uphold: (if vote-uphold (+ (get votes-uphold dispute) u1) (get votes-uphold dispute)),
        votes-reject: (if vote-uphold (get votes-reject dispute) (+ (get votes-reject dispute) u1)),
        resolved: (get resolved dispute),
        outcome: (get outcome dispute)
      }
    )
    
    (ok true)
  )
)

(define-public (resolve-dispute (dispute-id uint))
  (let
    (
      (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) err-dispute-not-found))
      (current-block stacks-block-height)
      (votes-uphold (get votes-uphold dispute))
      (votes-reject (get votes-reject dispute))
      (total-votes (get total-votes dispute))
      (dispute-upheld (> votes-uphold votes-reject))
      (doc-disputes (unwrap! (map-get? document-disputes { document-id: (get document-id dispute) }) err-document-not-found))
    )
    (asserts! (not (get resolved dispute)) err-dispute-closed)
    (asserts! (>= current-block (get voting-ends-at-block dispute)) err-dispute-closed)
    (asserts! (>= total-votes min-votes-required) err-invalid-vote)
    
    (map-set disputes
      { dispute-id: dispute-id }
      (merge dispute { resolved: true, outcome: (some dispute-upheld) })
    )
    
    (let
      ((stake-transfer-result
        (if dispute-upheld
          (stx-transfer? (get stake-amount dispute) (as-contract tx-sender) (get challenger dispute))
          (ok true))))
      
      (try! stake-transfer-result)
      
      (map-set document-disputes
        { document-id: (get document-id dispute) }
        {
          total-disputes: (get total-disputes doc-disputes),
          active-dispute-id: none,
          upheld-disputes: (if dispute-upheld (+ (get upheld-disputes doc-disputes) u1) (get upheld-disputes doc-disputes))
        })
        
      (ok dispute-upheld))
  )
)

(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes { dispute-id: dispute-id })
)

(define-read-only (get-vote (dispute-id uint) (voter principal))
  (map-get? dispute-votes { dispute-id: dispute-id, voter: voter })
)

(define-read-only (get-document-dispute-summary (document-id uint))
  (map-get? document-disputes { document-id: document-id })
)

(define-read-only (is-voting-active (dispute-id uint))
  (match (map-get? disputes { dispute-id: dispute-id })
    dispute (ok (and (not (get resolved dispute)) (< stacks-block-height (get voting-ends-at-block dispute))))
    err-dispute-not-found
  )
)
