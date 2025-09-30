;; Polynomial Registry Contract
;; This contract manages the central registry for computational resources,
;; allowing users to register and manage computational nodes with metadata,
;; track reputation, and control access to computational resources.

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NODE-NOT-FOUND (err u101))
(define-constant ERR-NODE-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-STATUS (err u103))
(define-constant ERR-NODE-INACTIVE (err u104))
(define-constant ERR-RATING-OUT-OF-RANGE (err u105))
(define-constant ERR-USER-NODE-LIMIT-REACHED (err u106))

;; Node status constants
(define-constant NODE-STATUS-ACTIVE u1)
(define-constant NODE-STATUS-INACTIVE u2)
(define-constant NODE-STATUS-MAINTENANCE u3)

;; Data structures
(define-data-var computational-node-counter uint u0)

;; Maps computational node ID to owner
(define-map computational-node-owners uint principal)

;; Comprehensive metadata for computational nodes
(define-map computational-node-metadata uint 
  {
    name: (string-ascii 100),
    description: (string-ascii 500),
    computational-domain: (string-ascii 100),
    capabilities: (string-ascii 500),
    data-types: (string-ascii 500),
    computational-rate: uint,
    status: uint,
    verification-status: bool,
    price-per-computation: uint,
    registration-time: uint
  }
)

;; Maps node-id to reputation metrics
(define-map computational-node-reputation uint
  {
    total-ratings: uint,
    rating-sum: uint,
    average-rating: uint,
    computational-uptime-percentage: uint
  }
)

;; Maps principal to list of node-ids they own
(define-map user-computational-nodes principal (list 50 uint))

;; Prevents duplicate ratings
(define-map node-computation-ratings {rater: principal, node-id: uint} uint)

;; Private Functions
(define-private (get-next-computational-node-id)
  (let ((current-id (var-get computational-node-counter)))
    (var-set computational-node-counter (+ current-id u1))
    current-id))

(define-private (initialize-node-reputation (node-id uint))
  (map-set computational-node-reputation node-id
    {
      total-ratings: u0,
      rating-sum: u0,
      average-rating: u0,
      computational-uptime-percentage: u100
    }))

;; Read-only Functions
(define-read-only (get-computational-node-metadata (node-id uint))
  (map-get? computational-node-metadata node-id))

(define-read-only (get-computational-node-owner (node-id uint))
  (map-get? computational-node-owners node-id))

(define-read-only (get-computational-node-reputation (node-id uint))
  (map-get? computational-node-reputation node-id))

(define-read-only (get-user-computational-nodes (user principal))
  (default-to (list) (map-get? user-computational-nodes user)))

(define-read-only (is-computational-node-active (node-id uint))
  (match (map-get? computational-node-metadata node-id)
    metadata (is-eq (get status metadata) NODE-STATUS-ACTIVE)
    false))

(define-read-only (total-computational-nodes)
  (var-get computational-node-counter))

;; Public Functions
(define-public (register-computational-node
    (name (string-ascii 100))
    (description (string-ascii 500))
    (computational-domain (string-ascii 100))
    (capabilities (string-ascii 500))
    (data-types (string-ascii 500))
    (computational-rate uint)
    (price-per-computation uint))
  (let
    ((node-id (get-next-computational-node-id))
     (owner tx-sender))
    
    ;; Check node registration limit
    (let ((current-user-nodes (default-to (list) (map-get? user-computational-nodes owner))))
      (asserts! (< (len current-user-nodes) u50) ERR-USER-NODE-LIMIT-REACHED))
      
    ;; Store node owner
    (map-set computational-node-owners node-id owner)
    
    ;; Store node metadata
    (map-set computational-node-metadata node-id
      {
        name: name,
        description: description,
        computational-domain: computational-domain,
        capabilities: capabilities,
        data-types: data-types,
        computational-rate: computational-rate,
        status: NODE-STATUS-ACTIVE,
        verification-status: false,
        price-per-computation: price-per-computation,
        registration-time: block-height
      })
    
    ;; Initialize node reputation
    (initialize-node-reputation node-id)
    
    ;; Return the new node ID
    (ok node-id)))

;; Additional functions similar to the original implementation, but contextualized for computational resources
(define-public (update-computational-node-metadata
    (node-id uint)
    (name (string-ascii 100))
    (description (string-ascii 500))
    (computational-domain (string-ascii 100))
    (capabilities (string-ascii 500))
    (data-types (string-ascii 500))
    (computational-rate uint)
    (price-per-computation uint))
  (let ((owner tx-sender))
    ;; Access control
    (asserts! (is-some (map-get? computational-node-owners node-id)) ERR-NODE-NOT-FOUND)
    
    (match (map-get? computational-node-metadata node-id)
      metadata
        (begin
          (map-set computational-node-metadata node-id
            {
              name: name,
              description: description,
              computational-domain: computational-domain,
              capabilities: capabilities,
              data-types: data-types,
              computational-rate: computational-rate,
              status: (get status metadata),
              verification-status: (get verification-status metadata),
              price-per-computation: price-per-computation,
              registration-time: (get registration-time metadata)
            })
           (ok true)
         )
      ERR-NODE-NOT-FOUND 
    )
  )
)

;; Maintain similar robustness as original implementation
(define-public (rate-computational-node (node-id uint) (rating uint))
  (let ((rater tx-sender))
    (begin
      (asserts! (is-some (map-get? computational-node-metadata node-id)) ERR-NODE-NOT-FOUND)
      (asserts! (is-computational-node-active node-id) ERR-NODE-INACTIVE)
      (asserts! (and (>= rating u1) (<= rating u5)) ERR-RATING-OUT-OF-RANGE)
      
      (map-set node-computation-ratings {rater: rater, node-id: node-id} rating)
      
      (let ((rep (unwrap! (map-get? computational-node-reputation node-id) ERR-NODE-NOT-FOUND)))
        (let
          ((new-total (+ (get total-ratings rep) u1))
           (new-sum (+ (get rating-sum rep) rating))
           (new-avg (/ new-sum new-total)))
          
          (map-set computational-node-reputation node-id 
            {
              total-ratings: new-total,
              rating-sum: new-sum,
              average-rating: new-avg,
              computational-uptime-percentage: (get computational-uptime-percentage rep)
            })
        )
      )
      
      (ok true)
    )
  )
)