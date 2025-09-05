(define-constant err-unauthorized (err u300))
(define-constant err-document-not-found (err u301))
(define-constant err-access-denied (err u302))
(define-constant err-permission-exists (err u303))
(define-constant err-permission-not-found (err u304))
(define-constant err-invalid-permission-type (err u305))

(define-constant permission-view u1)
(define-constant permission-share u2)
(define-constant permission-manage u3)

(define-map document-permissions
  { document-id: uint, grantee: principal }
  {
    permission-level: uint,
    granted-by: principal,
    granted-at-block: uint,
    expires-at-block: (optional uint),
    active: bool
  }
)

(define-map document-access-settings
  { document-id: uint }
  {
    owner: principal,
    is-private: bool,
    default-permission: uint,
    total-grants: uint
  }
)

(define-map permission-history
  { document-id: uint, grantee: principal, action-id: uint }
  {
    action-type: (string-ascii 10),
    performed-by: principal,
    performed-at-block: uint,
    permission-level: uint
  }
)

(define-data-var next-action-id uint u1)

(define-public (set-document-private (document-id uint) (is-private bool))
  (let
    (
      (current-settings (map-get? document-access-settings { document-id: document-id }))
    )
    (match current-settings
      settings (asserts! (is-eq tx-sender (get owner settings)) err-unauthorized)
      (map-set document-access-settings
        { document-id: document-id }
        {
          owner: tx-sender,
          is-private: is-private,
          default-permission: permission-view,
          total-grants: u0
        }
      )
    )
    
    (map-set document-access-settings
      { document-id: document-id }
      (merge (default-to 
        { owner: tx-sender, is-private: is-private, default-permission: permission-view, total-grants: u0 }
        current-settings)
        { is-private: is-private }
      )
    )
    (ok true)
  )
)

(define-public (grant-access (document-id uint) (grantee principal) (permission-level uint) (expires-at-block (optional uint)))
  (let
    (
      (settings (unwrap! (map-get? document-access-settings { document-id: document-id }) err-document-not-found))
      (current-block stacks-block-height)
      (action-id (var-get next-action-id))
    )
    (asserts! (is-eq tx-sender (get owner settings)) err-unauthorized)
    (asserts! (or (is-eq permission-level permission-view) (is-eq permission-level permission-share) (is-eq permission-level permission-manage)) err-invalid-permission-type)
    (asserts! (is-none (map-get? document-permissions { document-id: document-id, grantee: grantee })) err-permission-exists)
    
    (map-set document-permissions
      { document-id: document-id, grantee: grantee }
      {
        permission-level: permission-level,
        granted-by: tx-sender,
        granted-at-block: current-block,
        expires-at-block: expires-at-block,
        active: true
      }
    )
    
    (map-set permission-history
      { document-id: document-id, grantee: grantee, action-id: action-id }
      {
        action-type: "GRANT",
        performed-by: tx-sender,
        performed-at-block: current-block,
        permission-level: permission-level
      }
    )
    
    (map-set document-access-settings
      { document-id: document-id }
      (merge settings { total-grants: (+ (get total-grants settings) u1) })
    )
    
    (var-set next-action-id (+ action-id u1))
    (ok true)
  )
)

(define-public (revoke-access (document-id uint) (grantee principal))
  (let
    (
      (settings (unwrap! (map-get? document-access-settings { document-id: document-id }) err-document-not-found))
      (permission (unwrap! (map-get? document-permissions { document-id: document-id, grantee: grantee }) err-permission-not-found))
      (action-id (var-get next-action-id))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender (get owner settings)) err-unauthorized)
    
    (map-set document-permissions
      { document-id: document-id, grantee: grantee }
      (merge permission { active: false })
    )
    
    (map-set permission-history
      { document-id: document-id, grantee: grantee, action-id: action-id }
      {
        action-type: "REVOKE",
        performed-by: tx-sender,
        performed-at-block: current-block,
        permission-level: (get permission-level permission)
      }
    )
    
    (var-set next-action-id (+ action-id u1))
    (ok true)
  )
)

(define-read-only (has-access (document-id uint) (user principal))
  (let
    (
      (settings (map-get? document-access-settings { document-id: document-id }))
      (permission (map-get? document-permissions { document-id: document-id, grantee: user }))
      (current-block stacks-block-height)
    )
    (match settings
      doc-settings
        (if (get is-private doc-settings)
          (if (is-eq user (get owner doc-settings))
            true
            (match permission
              perm (and 
                (get active perm)
                (match (get expires-at-block perm)
                  expiry (< current-block expiry)
                  true
                )
              )
              false
            )
          )
          true
        )
      true
    )
  )
)

(define-read-only (get-document-access-settings (document-id uint))
  (map-get? document-access-settings { document-id: document-id })
)

(define-read-only (get-user-permission (document-id uint) (user principal))
  (map-get? document-permissions { document-id: document-id, grantee: user })
)