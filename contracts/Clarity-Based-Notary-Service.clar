(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-input (err u103))
(define-constant err-unauthorized (err u104))

(define-data-var next-document-id uint u1)
(define-data-var service-fee uint u1000000)
(define-data-var total-documents uint u0)

(define-map documents
  { document-id: uint }
  {
    hash: (buff 32),
    title: (string-ascii 100),
    notarizer: principal,
    timestamp: uint,
    stacks-stacks-block-height: uint,
    fee-paid: uint,
    metadata: (string-ascii 200)
  }
)

(define-map document-hash-to-id
  { hash: (buff 32) }
  { document-id: uint }
)

(define-map user-documents
  { user: principal, document-id: uint }
  { exists: bool }
)

(define-map user-document-count
  { user: principal }
  { count: uint }
)

(define-map notary-stats
  { notary: principal }
  {
    total-notarized: uint,
    total-fees-earned: uint,
    first-notarization: uint
  }
)

(define-public (notarize-document (hash (buff 32)) (title (string-ascii 100)) (metadata (string-ascii 200)))
  (let
    (
      (document-id (var-get next-document-id))
      (current-fee (var-get service-fee))
      (caller tx-sender)


      (current-block stacks-block-height)
      (current-time stacks-block-height)
    )
    (asserts! (> (len hash) u0) err-invalid-input)
    (asserts! (> (len title) u0) err-invalid-input)
    (asserts! (is-none (map-get? document-hash-to-id { hash: hash })) err-already-exists)
    
    (try! (stx-transfer? current-fee caller contract-owner))
    
    (map-set documents
      { document-id: document-id }
      {
        hash: hash,
        title: title,
        notarizer: caller,
        timestamp: current-time,
        stacks-stacks-block-height: current-block,
        fee-paid: current-fee,
        metadata: metadata
      }
    )
    
    (map-set document-hash-to-id
      { hash: hash }
      { document-id: document-id }
    )
    
    (map-set user-documents
      { user: caller, document-id: document-id }
      { exists: true }
    )
    
    (let
      (
        (current-user-count (default-to u0 (get count (map-get? user-document-count { user: caller }))))
      )
      (map-set user-document-count
        { user: caller }
        { count: (+ current-user-count u1) }
      )
    )
    
    (let
      (
        (current-stats (map-get? notary-stats { notary: caller }))
        (current-total (default-to u0 (get total-notarized current-stats)))
        (current-fees (default-to u0 (get total-fees-earned current-stats)))
        (first-time (default-to current-time (get first-notarization current-stats)))
      )
      (map-set notary-stats
        { notary: caller }
        {
          total-notarized: (+ current-total u1),
          total-fees-earned: (+ current-fees current-fee),
          first-notarization: first-time
        }
      )
    )
    
    (var-set next-document-id (+ document-id u1))
    (var-set total-documents (+ (var-get total-documents) u1))
    
    (ok document-id)
  )

)
(define-read-only (get-document (document-id uint))
  (map-get? documents { document-id: document-id })
)

(define-read-only (get-document-by-hash (hash (buff 32)))
  (match (map-get? document-hash-to-id { hash: hash })
    doc-info (get-document (get document-id doc-info))
    none
  )
)

(define-read-only (verify-document (hash (buff 32)))
  (match (get-document-by-hash hash)
    document-data
      (ok (some {
        document-id: (unwrap! (get document-id (map-get? document-hash-to-id { hash: hash })) (err u0)),
        title: (get title document-data),
        notarizer: (get notarizer document-data),
        timestamp: (get timestamp document-data),
        stacks-stacks-block-height: (get stacks-stacks-block-height document-data),
        verified: true
      }))
    (ok none)
  )
)

(define-read-only (get-user-document-count (user principal))
  (default-to u0 (get count (map-get? user-document-count { user: user })))
)

(define-read-only (is-user-document (user principal) (document-id uint))
  (default-to false (get exists (map-get? user-documents { user: user, document-id: document-id })))
)

(define-read-only (get-notary-stats (notary principal))
  (map-get? notary-stats { notary: notary })
)

(define-read-only (get-service-fee)
  (var-get service-fee)
)

(define-read-only (get-total-documents)
  (var-get total-documents)
)

(define-read-only (get-next-document-id)
  (var-get next-document-id)
)

(define-public (update-service-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-fee u0) err-invalid-input)
    (var-set service-fee new-fee)
    (ok true)
  )
)

(define-public (withdraw-fees (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-input)
    (try! (stx-transfer? amount (as-contract tx-sender) recipient))
    (ok true)
  )
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (document-exists (document-id uint))
  (is-some (map-get? documents { document-id: document-id }))
)

(define-read-only (hash-is-notarized (hash (buff 32)))
  (is-some (map-get? document-hash-to-id { hash: hash }))
)
