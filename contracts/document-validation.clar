(define-constant err-document-not-found (err u400))
(define-constant err-already-validated (err u401))
(define-constant err-invalid-score (err u402))
(define-constant err-unauthorized (err u403))

(define-data-var validation-fee uint u100000)
(define-data-var min-validation-count uint u3)

(define-map document-validations
  { document-id: uint, validator: principal }
  {
    validation-score: uint,
    validated-at-block: uint,
    validator-reputation: uint
  }
)

(define-map notarizer-reputation
  { notarizer: principal }
  {
    total-score: uint,
    validation-count: uint,
    trust-rating: uint,
    last-updated: uint
  }
)

(define-map validation-summary
  { document-id: uint }
  {
    total-validations: uint,
    average-score: uint,
    consensus-reached: bool,
    validation-hash: (buff 32)
  }
)

(define-public (validate-document (document-id uint) (score uint) (validation-hash (buff 32)))
  (let
    (
      (current-block stacks-block-height)
      (current-fee (var-get validation-fee))
      (existing-validation (map-get? document-validations { document-id: document-id, validator: tx-sender }))
      (validator-rep (default-to { total-score: u0, validation-count: u0, trust-rating: u50, last-updated: u0 }
                      (map-get? notarizer-reputation { notarizer: tx-sender })))
    )
    (asserts! (is-none existing-validation) err-already-validated)
    (asserts! (and (<= score u100) (>= score u0)) err-invalid-score)
    (asserts! (> (len validation-hash) u0) err-invalid-score)
    
    (try! (stx-transfer? current-fee tx-sender (as-contract tx-sender)))
    
    (map-set document-validations
      { document-id: document-id, validator: tx-sender }
      {
        validation-score: score,
        validated-at-block: current-block,
        validator-reputation: (get trust-rating validator-rep)
      }
    )
    
    (map-set notarizer-reputation
      { notarizer: tx-sender }
      {
        total-score: (+ (get total-score validator-rep) score),
        validation-count: (+ (get validation-count validator-rep) u1),
        trust-rating: (/ (+ (get total-score validator-rep) score) (+ (get validation-count validator-rep) u1)),
        last-updated: current-block
      }
    )
    
    (update-validation-summary document-id)
  )
)

(define-private (update-validation-summary (document-id uint))
  (let
    (
      (current-summary (default-to { total-validations: u0, average-score: u0, consensus-reached: false, validation-hash: 0x00 }
                       (map-get? validation-summary { document-id: document-id })))
      (new-total (+ (get total-validations current-summary) u1))
    )
    (begin
      (map-set validation-summary
        { document-id: document-id }
        {
          total-validations: new-total,
          average-score: (get average-score current-summary),
          consensus-reached: (>= new-total (var-get min-validation-count)),
          validation-hash: (get validation-hash current-summary)
        }
      )
      (ok true)
    )
  )
)

(define-read-only (get-document-validation-summary (document-id uint))
  (map-get? validation-summary { document-id: document-id })
)

(define-read-only (get-notarizer-reputation (notarizer principal))
  (map-get? notarizer-reputation { notarizer: notarizer })
)

(define-read-only (get-validator-score (document-id uint) (validator principal))
  (map-get? document-validations { document-id: document-id, validator: validator })
)
