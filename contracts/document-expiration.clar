(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-document-not-found (err u201))
(define-constant err-document-expired (err u202))
(define-constant err-already-expired (err u203))
(define-constant err-invalid-duration (err u204))
(define-constant err-unauthorized (err u205))

(define-data-var renewal-fee uint u500000)
(define-data-var max-extension-blocks uint u144000)

(define-map document-expiration
  { document-id: uint }
  {
    expires-at-block: uint,
    renewable: bool,
    renewal-count: uint,
    original-notarizer: principal
  }
)

(define-map renewal-history
  { document-id: uint, renewal-number: uint }
  {
    renewed-at-block: uint,
    renewed-by: principal,
    extension-blocks: uint
  }
)

(define-public (set-document-expiration (document-id uint) (duration-blocks uint) (renewable bool))
  (let
    (
      (current-block stacks-block-height)
      (expires-at (+ current-block duration-blocks))
    )
    (asserts! (> duration-blocks u0) err-invalid-duration)
    (asserts! (<= duration-blocks (var-get max-extension-blocks)) err-invalid-duration)
    
    (map-set document-expiration
      { document-id: document-id }
      {
        expires-at-block: expires-at,
        renewable: renewable,
        renewal-count: u0,
        original-notarizer: tx-sender
      }
    )
    (ok expires-at)
  )
)

(define-public (renew-document (document-id uint) (extension-blocks uint))
  (let
    (
      (current-block stacks-block-height)
      (current-fee (var-get renewal-fee))
      (doc-exp (unwrap! (map-get? document-expiration { document-id: document-id }) err-document-not-found))
      (current-expiry (get expires-at-block doc-exp))
      (current-renewals (get renewal-count doc-exp))
      (new-expiry (+ current-expiry extension-blocks))
    )
    (asserts! (get renewable doc-exp) err-unauthorized)
    (asserts! (> extension-blocks u0) err-invalid-duration)
    (asserts! (<= extension-blocks (var-get max-extension-blocks)) err-invalid-duration)
    
    (try! (stx-transfer? current-fee tx-sender contract-owner))
    
    (map-set document-expiration
      { document-id: document-id }
      {
        expires-at-block: new-expiry,
        renewable: (get renewable doc-exp),
        renewal-count: (+ current-renewals u1),
        original-notarizer: (get original-notarizer doc-exp)
      }
    )
    
    (map-set renewal-history
      { document-id: document-id, renewal-number: (+ current-renewals u1) }
      {
        renewed-at-block: current-block,
        renewed-by: tx-sender,
        extension-blocks: extension-blocks
      }
    )
    
    (ok new-expiry)
  )
)

(define-read-only (is-document-valid (document-id uint))
  (match (map-get? document-expiration { document-id: document-id })
    doc-exp (ok (< stacks-block-height (get expires-at-block doc-exp)))
    (ok true)
  )
)

(define-read-only (get-document-expiration (document-id uint))
  (map-get? document-expiration { document-id: document-id })
)

(define-read-only (get-renewal-history (document-id uint) (renewal-number uint))
  (map-get? renewal-history { document-id: document-id, renewal-number: renewal-number })
)

(define-read-only (blocks-until-expiry (document-id uint))
  (match (map-get? document-expiration { document-id: document-id })
    doc-exp (ok (some (- (get expires-at-block doc-exp) stacks-block-height)))
    (ok none)
  )
)

(define-public (update-renewal-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set renewal-fee new-fee)
    (ok true)
  )
)

(define-read-only (get-renewal-fee)
  (var-get renewal-fee)
)
