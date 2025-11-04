(define-constant err-document-not-found (err u600))
(define-constant err-already-signed (err u601))
(define-constant err-not-required-signer (err u602))
(define-constant err-signature-completed (err u603))
(define-constant err-unauthorized (err u604))
(define-constant err-invalid-threshold (err u605))

(define-map signature-requirements
  { document-id: uint }
  {
    initiator: principal,
    required-signers: (list 10 principal),
    threshold: uint,
    created-at-block: uint,
    deadline-block: (optional uint),
    completed: bool
  }
)

(define-map document-signatures
  { document-id: uint, signer: principal }
  {
    signed: bool,
    signed-at-block: (optional uint),
    signature-hash: (optional (buff 32)),
    status: (string-ascii 10)
  }
)

(define-map signature-stats
  { document-id: uint }
  {
    total-required: uint,
    total-signed: uint,
    pending-count: uint,
    completion-block: (optional uint)
  }
)

(define-public (initiate-cosign (document-id uint) (required-signers (list 10 principal)) (threshold uint) (deadline-blocks (optional uint)))
  (let
    (
      (current-block stacks-block-height)
      (deadline (match deadline-blocks blocks (some (+ current-block blocks)) none))
      (signer-count (len required-signers))
    )
    (asserts! (and (> threshold u0) (<= threshold signer-count)) err-invalid-threshold)
    (asserts! (> signer-count u0) err-invalid-threshold)
    
    (map-set signature-requirements
      { document-id: document-id }
      {
        initiator: tx-sender,
        required-signers: required-signers,
        threshold: threshold,
        created-at-block: current-block,
        deadline-block: deadline,
        completed: false
      }
    )
    
    (map-set signature-stats
      { document-id: document-id }
      { total-required: signer-count, total-signed: u0, pending-count: signer-count, completion-block: none }
    )
    
    (ok true)
  )
)

(define-public (sign-document (document-id uint) (signature-hash (buff 32)))
  (let
    (
      (requirements (unwrap! (map-get? signature-requirements { document-id: document-id }) err-document-not-found))
      (current-block stacks-block-height)
      (stats (unwrap! (map-get? signature-stats { document-id: document-id }) err-document-not-found))
      (is-required (is-some (index-of (get required-signers requirements) tx-sender)))
      (existing-sig (map-get? document-signatures { document-id: document-id, signer: tx-sender }))
    )
    (asserts! is-required err-not-required-signer)
    (asserts! (not (get completed requirements)) err-signature-completed)
    (asserts! (match existing-sig sig (not (get signed sig)) true) err-already-signed)
    
    (map-set document-signatures
      { document-id: document-id, signer: tx-sender }
      { signed: true, signed-at-block: (some current-block), signature-hash: (some signature-hash), status: "SIGNED" }
    )
    
    (let
      ((new-signed-count (+ (get total-signed stats) u1)))
      (map-set signature-stats
        { document-id: document-id }
        { total-required: (get total-required stats), total-signed: new-signed-count, pending-count: (- (get total-required stats) new-signed-count), completion-block: (get completion-block stats) }
      )
      
      (if (>= new-signed-count (get threshold requirements))
        (begin
          (map-set signature-requirements { document-id: document-id } (merge requirements { completed: true }))
          (map-set signature-stats { document-id: document-id } (merge (unwrap-panic (map-get? signature-stats { document-id: document-id })) { completion-block: (some current-block) }))
          (ok { completed: true, signatures: new-signed-count })
        )
        (ok { completed: false, signatures: new-signed-count })
      )
    )
  )
)

(define-read-only (get-signature-requirements (document-id uint))
  (map-get? signature-requirements { document-id: document-id })
)

(define-read-only (get-signer-status (document-id uint) (signer principal))
  (map-get? document-signatures { document-id: document-id, signer: signer })
)

(define-read-only (get-signature-stats (document-id uint))
  (map-get? signature-stats { document-id: document-id })
)

(define-read-only (is-fully-signed (document-id uint))
  (match (map-get? signature-requirements { document-id: document-id })
    req (ok (get completed req))
    err-document-not-found
  )
)
