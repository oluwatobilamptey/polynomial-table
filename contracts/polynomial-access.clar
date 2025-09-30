;; Polynomial Access Management Contract
;; Manages computational resource access, permissions, and payment processing
;; for polynomial computation nodes in the decentralized computational ecosystem.

;; Error Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NODE-NOT-FOUND (err u101))
(define-constant ERR-REQUEST-NOT-FOUND (err u102))
(define-constant ERR-INVALID-PARAMETERS (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-REQUEST-ALREADY-PROCESSED (err u105))
(define-constant ERR-INVALID-STATE (err u106))
(define-constant ERR-ACCESS-EXPIRED (err u107))
(define-constant ERR-ACCESS-REVOKED (err u108))
(define-constant ERR-PAYMENT-FAILED (err u109))
(define-constant ERR-INVALID-PAYMENT-TYPE (err u110))

;; Computational Node Registry Contract Reference
(define-constant COMPUTATIONAL-REGISTRY-CONTRACT .polynomial-registry)

;; Request Status Constants
(define-constant STATUS-PENDING u1)
(define-constant STATUS-APPROVED u2)
(define-constant STATUS-DENIED u3)
(define-constant STATUS-REVOKED u4)
(define-constant STATUS-EXPIRED u5)

;; Payment Type Constants
(define-constant PAYMENT-TYPE-ONE-TIME u1)
(define-constant PAYMENT-TYPE-SUBSCRIPTION u2)

;; Computational Access Request Map
(define-map computational-access-requests
  { request-id: uint }
  {
    requester: principal,
    node-id: uint,
    computational-purpose: (string-ascii 100),
    start-block: uint,
    end-block: uint,
    payment-amount: uint,
    payment-type: uint,
    payment-interval: uint,
    status: uint,
    approved-at: (optional uint),
    last-payment-block: (optional uint)
  }
)

;; Node Access Permissions Map
(define-map computational-node-permissions
  { node-id: uint, requester: principal }
  {
    request-id: uint,
    access-until-block: uint,
    is-revoked: bool
  }
)

;; Computational Node Owners Map
(define-map computational-node-owners
  { node-id: uint }
  {
    owner: principal
  }
)

;; Request Counter for Generating Unique Request IDs
(define-data-var request-counter uint u0)

;; Private Functions
(define-private (is-computational-node-owner (node-id uint) (sender principal))
  (match (get owner (map-get? computational-node-owners { node-id: node-id }))
    owner (is-eq sender owner)
    false
  )
)

(define-private (get-next-request-id)
  (let ((current-id (var-get request-counter)))
    (var-set request-counter (+ current-id u1))
    current-id
  )
)

(define-private (is-access-valid (node-id uint) (requester principal))
  (match (map-get? computational-node-permissions { node-id: node-id, requester: requester })
    permission (and 
                (not (get is-revoked permission))
                (<= block-height (get access-until-block permission)))
    false
  )
)

(define-private (process-computational-payment (payer principal) (payee principal) (amount uint))
  (stx-transfer? amount payer payee)
)

;; Read-Only Functions
(define-read-only (get-computational-access-request (request-id uint))
  (map-get? computational-access-requests { request-id: request-id })
)

(define-read-only (verify-computational-access (node-id uint) (requester principal))
  (is-access-valid node-id requester)
)

;; Public Functions
(define-public (request-computational-access 
                (node-id uint) 
                (computational-purpose (string-ascii 100))
                (duration-blocks uint)
                (payment-amount uint)
                (payment-type uint)
                (payment-interval uint))
  (let (
    (requester tx-sender)
    (request-id (get-next-request-id))
    (start-block block-height)
    (end-block (+ block-height duration-blocks))
  )
    ;; Validate node existence
    (asserts! (is-some (map-get? computational-node-owners { node-id: node-id })) ERR-NODE-NOT-FOUND)
    
    ;; Payment validation
    (asserts! (> payment-amount u0) ERR-INVALID-PARAMETERS)
    (asserts! (or (is-eq payment-type PAYMENT-TYPE-ONE-TIME) 
                  (is-eq payment-type PAYMENT-TYPE-SUBSCRIPTION)) 
              ERR-INVALID-PAYMENT-TYPE)
    
    ;; Subscription payment interval check
    (asserts! (or (is-eq payment-type PAYMENT-TYPE-ONE-TIME) 
                  (> payment-interval u0))
              ERR-INVALID-PARAMETERS)
    
    ;; Record access request
    (map-set computational-access-requests
      { request-id: request-id }
      {
        requester: requester,
        node-id: node-id,
        computational-purpose: computational-purpose,
        start-block: start-block,
        end-block: end-block,
        payment-amount: payment-amount,
        payment-type: payment-type,
        payment-interval: payment-interval,
        status: STATUS-PENDING,
        approved-at: none,
        last-payment-block: none
      }
    )
    
    (ok request-id)
  )
)

(define-public (approve-computational-access (request-id uint))
  (let (
    (sender tx-sender)
    (request (unwrap! (map-get? computational-access-requests { request-id: request-id }) (err ERR-REQUEST-NOT-FOUND)))
    (node-id (get node-id request))
    (requester (get requester request))
    (end-block (get end-block request))
    (payment-amount (get payment-amount request))
  )
    ;; Validate node ownership
    (asserts! (is-computational-node-owner node-id sender) (err ERR-NOT-AUTHORIZED))
    
    ;; Validate request status
    (asserts! (is-eq (get status request) STATUS-PENDING) (err ERR-REQUEST-ALREADY-PROCESSED))
    
    ;; Update access request
    (map-set computational-access-requests
      { request-id: request-id }
      (merge request {
        status: STATUS-APPROVED,
        approved-at: (some block-height)
      })
    )
    
    ;; Grant access permissions
    (map-set computational-node-permissions
      { node-id: node-id, requester: requester }
      {
        request-id: request-id,
        access-until-block: end-block,
        is-revoked: false
      }
    )
    
    (ok true)
  )
)

;; Additional functions similar to original, maintaining core logic
(define-public (revoke-computational-access (node-id uint) (requester principal))
  (let (
    (sender tx-sender)
    (permission (unwrap! (map-get? computational-node-permissions { node-id: node-id, requester: requester }) (err ERR-REQUEST-NOT-FOUND)))
    (request-id (get request-id permission))
  )
    ;; Owner-only access control
    (asserts! (is-computational-node-owner node-id sender) (err ERR-NOT-AUTHORIZED))
    
    ;; Revoke permission
    (map-set computational-node-permissions
      { node-id: node-id, requester: requester }
      (merge permission { is-revoked: true })
    )
    
    (ok true)
  )
)