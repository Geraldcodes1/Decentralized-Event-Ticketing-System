;; Decentralized Event Ticketing System
;; A platform with anti-scalping measures for event ticket issuance and management

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-EVENT-NOT-FOUND u2)
(define-constant ERR-TICKET-NOT-FOUND u3)
(define-constant ERR-TICKET-CLASS-NOT-FOUND u4)
(define-constant ERR-INVALID-PARAMETERS u5)
(define-constant ERR-SOLD-OUT u6)
(define-constant ERR-INSUFFICIENT-FUNDS u7)
(define-constant ERR-EVENT-ENDED u8)
(define-constant ERR-ALREADY-ATTENDED u9)
(define-constant ERR-TICKET-NOT-OWNED u10)
(define-constant ERR-TICKET-NOT-RESALABLE u11)
(define-constant ERR-PRICE-EXCEEDS-CAP u12)
(define-constant ERR-ALREADY-LISTED u13)
(define-constant ERR-NOT-LISTED u14)
(define-constant ERR-EVENT-NOT-ACTIVE u15)
(define-constant ERR-SALE-NOT-STARTED u16)
(define-constant ERR-SALE-ENDED u17)
(define-constant ERR-REFUND-WINDOW-EXPIRED u18)
(define-constant ERR-TICKET-ALREADY-USED u19)
(define-constant ERR-PURCHASE-LIMIT-EXCEEDED u20)
(define-constant ERR-IDENTITY-VERIFICATION-FAILED u21)
(define-constant ERR-EVENT-CANCELED u22)

;; Status constants
(define-constant EVENT-STATUS-ACTIVE u1)
(define-constant EVENT-STATUS-CANCELED u2)
(define-constant EVENT-STATUS-COMPLETED u3)

(define-constant TICKET-STATUS-VALID u1)
(define-constant TICKET-STATUS-USED u2)
(define-constant TICKET-STATUS-REFUNDED u3)
(define-constant TICKET-STATUS-LISTED u4)

;; Dynamic pricing models
(define-constant PRICE-MODEL-FIXED u1)
(define-constant PRICE-MODEL-TIME-BASED u2)  ;; Increases/decreases based on time to event
(define-constant PRICE-MODEL-DEMAND-BASED u3) ;; Increases/decreases based on percentage sold

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-event-id uint u1)
(define-data-var next-ticket-class-id uint u1)
(define-data-var next-ticket-id uint u1)
(define-data-var next-listing-id uint u1)
(define-data-var platform-fee-percentage uint u250) ;; 2.5% as basis points (1/100 of percent)
(define-data-var max-resale-percentage uint u11000) ;; 110% as basis points (default price cap)

;; Event organizers
(define-map organizers
  { principal: principal }
  { 
    name: (string-utf8 100),
    verification-status: bool,
    events-created: uint,
    joined-at: uint
  }
)
;; Events
(define-map events
  { event-id: uint }
  {
    name: (string-utf8 100),
    description: (string-utf8 1000),
    venue: (string-utf8 200),
    organizer: principal,
    start-date: uint, ;; Block height or Unix timestamp
    end-date: uint,
    status: uint,
    refund-policy: (string-utf8 500),
    refund-window-hours: uint, ;; Hours before event when refunds are still allowed
    identity-verification-required: bool,
    max-tickets-per-buyer: uint,
    sales-start-date: uint,
    sales-end-date: uint,
    image-url: (string-utf8 200),
    created-at: uint,
    total-ticket-count: uint,
    tickets-sold: uint,
    tickets-available: uint
  }
)

;; Ticket classes (e.g., VIP, General Admission)
(define-map ticket-classes
  { ticket-class-id: uint }
  {
    event-id: uint,
    name: (string-utf8 100),
    description: (string-utf8 500),
    base-price: uint, ;; In STX
    total-supply: uint,
    remaining-supply: uint,
    resalable: bool,
    price-model: uint,
    max-resale-price-percentage: uint, ;; Basis points
    dynamic-pricing-params: (list 3 uint) ;; Parameters for dynamic pricing models
  }
)

;; Tickets
(define-map tickets
  { ticket-id: uint }
  {
    event-id: uint,
    ticket-class-id: uint,
    owner: principal,
    purchase-price: uint,
    purchase-date: uint,
    status: uint,
    attended: bool,
    attendance-time: (optional uint),
    verification-code: (buff 32), ;; Hash of secret code for attendance
    resale-price: (optional uint),
    original-owner: principal,
    metadata-hash: (buff 32) ;; Hash of all ticket details + owner identity for verification
  }
)

;; Map for event ticket counts by user
(define-map user-event-tickets
  { event-id: uint, user: principal }
  { count: uint }
)

;; Secondary market listings
(define-map ticket-listings
  { listing-id: uint }
  {
    ticket-id: uint,
    seller: principal,
    price: uint,
    listed-at: uint,
    expires-at: (optional uint)
  }
)

;; Map ticket ID to listing ID
(define-map ticket-to-listing
  { ticket-id: uint }
  { listing-id: uint }
)

;; User identity verification
(define-map user-identity-verification
  { user: principal }
  {
    verified: bool,
    verification-method: (string-utf8 100),
    verification-date: uint,
    verification-hash: (buff 32) ;; Hash of identity documents
  }
)

;; Waitlists for popular events
(define-map event-waitlists
  { event-id: uint, user: principal }
  {
    position: uint,
    requested-at: uint,
    ticket-class-id: uint
  }
)

;; Waitlist counters
(define-map waitlist-counters
  { event-id: uint }
  { count: uint }
)

;; Read-only functions

;; Get event details
(define-read-only (get-event (event-id uint))
  (map-get? events { event-id: event-id })
)

;; Get ticket class details
(define-read-only (get-ticket-class (ticket-class-id uint))
  (map-get? ticket-classes { ticket-class-id: ticket-class-id })
)

;; Get ticket details
(define-read-only (get-ticket (ticket-id uint))
  (map-get? tickets { ticket-id: ticket-id })
)

;; Get ticket listing
(define-read-only (get-ticket-listing (listing-id uint))
  (map-get? ticket-listings { listing-id: listing-id })
)

;; Get listing by ticket
(define-read-only (get-listing-by-ticket (ticket-id uint))
  (match (map-get? ticket-to-listing { ticket-id: ticket-id })
    listing-map (map-get? ticket-listings { listing-id: (get listing-id listing-map) })
    none
  )
)
;; Check if a user has verified identity
(define-read-only (is-identity-verified (user principal))
  (match (map-get? user-identity-verification { user: user })
    verification (get verified verification)
    false
  )
)

;; Calculate current ticket price based on the pricing model
(define-read-only (calculate-current-price (ticket-class-id uint))
  (let
    (
      (ticket-class (unwrap! (get-ticket-class ticket-class-id) u0))
      (event-id (get event-id ticket-class))
      (event (unwrap! (get-event event-id) u0))
      (base-price (get base-price ticket-class))
      (price-model (get price-model ticket-class))
      (params (get dynamic-pricing-params ticket-class))
    )
    
    (if (is-eq price-model PRICE-MODEL-FIXED)
      ;; Fixed price model - return base price
      base-price
      
      (if (is-eq price-model PRICE-MODEL-TIME-BASED)
        ;; Time-based model
        (let
          (
            (time-factor (get-time-price-factor 
                         (get sales-start-date event) 
                         (get start-date event) 
                         block-height
                         (unwrap-panic (element-at params u0))
                         (unwrap-panic (element-at params u1))))
          )
          (if (> time-factor u100)
            ;; Price increase
            (+ base-price (/ (* base-price (- time-factor u100)) u100))
            ;; Price decrease
            (- base-price (/ (* base-price (- u100 time-factor)) u100))
          )
        )
        
        ;; Demand-based model
        (let
          (
            (total-supply (get total-supply ticket-class))
            (remaining-supply (get remaining-supply ticket-class))
            (sold-percentage (if (> total-supply u0)
                               (/ (* (- total-supply remaining-supply) u100) total-supply)
                               u0))
            (max-increase-percentage (unwrap-panic (element-at params u0)))
            (price-increase-factor (/ (* sold-percentage max-increase-percentage) u100))
          )
          (+ base-price (/ (* base-price price-increase-factor) u100))
        )
      )
    )
  )
)

;; Helper function for time-based pricing
(define-read-only (get-time-price-factor (sale-start uint) (event-start uint) (current-block uint) (initial-discount uint) (max-increase uint))
  (let
    (
      (total-period (- event-start sale-start))
      (elapsed-period (- current-block sale-start))
      (progress-percentage (if (> total-period u0)
                            (/ (* elapsed-period u100) total-period)
                            u100))
    )
    ;; Start with discount, move to base price, then to premium as event approaches
    (if (< progress-percentage u50)
      ;; First half: discount gradually reduces
      (- u100 (/ (* (- u50 progress-percentage) initial-discount) u50))
      ;; Second half: premium gradually increases
      (+ u100 (/ (* (- progress-percentage u50) max-increase) u50))
    )
  )
)

;; Check if a ticket is valid for attendance
(define-read-only (is-ticket-valid (ticket-id uint))
  (match (get-ticket ticket-id)
    ticket
    (and
      (is-eq (get status ticket) TICKET-STATUS-VALID)
      (not (get attended ticket))
      (match (get-event (get event-id ticket))
        event 
        (and
          (is-eq (get status event) EVENT-STATUS-ACTIVE)
          (>= block-height (get start-date event))
          (<= block-height (get end-date event))
        )
        false
      )
    )
    false
  )
)

;; Check how many tickets a user has for an event
(define-read-only (get-user-ticket-count (event-id uint) (user principal))
  (default-to { count: u0 } (map-get? user-event-tickets { event-id: event-id, user: user }))
)

;; Public functions

;; Register as event organizer
(define-public (register-organizer (name (string-utf8 100)))
  (begin
    (map-set organizers
      { principal: tx-sender }
      {
        name: name,
        verification-status: false,
        events-created: u0,
        joined-at: block-height
      }
    )
    (ok true)
  )
)

;; Verify an organizer (only contract owner)
(define-public (verify-organizer (organizer-principal principal))
  (let
    (
      (organizer (default-to 
                 { 
                   name: "", 
                   verification-status: false, 
                   events-created: u0, 
                   joined-at: block-height 
                 } 
                 (map-get? organizers { principal: organizer-principal })))
    )

;; Create a new event
(define-public (create-event
  (name (string-utf8 100))
  (description (string-utf8 1000))
  (venue (string-utf8 200))
  (start-date uint)
  (end-date uint)
  (refund-policy (string-utf8 500))
  (refund-window-hours uint)
  (identity-verification-required bool)
  (max-tickets-per-buyer uint)
  (sales-start-date uint)
  (sales-end-date uint)
  (image-url (string-utf8 200))
)
  (let
    (
      (event-id (var-get next-event-id))
      (organizer (default-to 
                 { 
                   name: "", 
                   verification-status: false, 
                   events-created: u0, 
                   joined-at: block-height 
                 } 
                 (map-get? organizers { principal: tx-sender })))
    )
    
    ;; Validate parameters
    (asserts! (> start-date block-height) (err ERR-INVALID-PARAMETERS))
    (asserts! (> end-date start-date) (err ERR-INVALID-PARAMETERS))
    (asserts! (>= sales-start-date block-height) (err ERR-INVALID-PARAMETERS))
    (asserts! (< sales-start-date sales-end-date) (err ERR-INVALID-PARAMETERS))
    (asserts! (< sales-end-date start-date) (err ERR-INVALID-PARAMETERS))
    
    ;; Create the event
    (map-set events
      { event-id: event-id }
      {
        name: name,
        description: description,
        venue: venue,
        organizer: tx-sender,
        start-date: start-date,
        end-date: end-date,
        status: EVENT-STATUS-ACTIVE,
        refund-policy: refund-policy,
        refund-window-hours: refund-window-hours,
        identity-verification-required: identity-verification-required,
        max-tickets-per-buyer: max-tickets-per-buyer,
        sales-start-date: sales-start-date,
        sales-end-date: sales-end-date,
        image-url: image-url,
        created-at: block-height,
        total-ticket-count: u0,
        tickets-sold: u0,
        tickets-available: u0
      }
    )
    
    ;; Update organizer stats
    (map-set organizers
      { principal: tx-sender }
      (merge organizer {
        events-created: (+ (get events-created organizer) u1)
      })
    )
    
    ;; Increment event ID
    (var-set next-event-id (+ event-id u1))
    
    (ok event-id)
  )
)

;; Add a ticket class to an event
(define-public (add-ticket-class
  (event-id uint)
  (name (string-utf8 100))
  (description (string-utf8 500))
  (base-price uint)
  (total-supply uint)
  (resalable bool)
  (price-model uint)
  (max-resale-price-percentage uint)
  (dynamic-pricing-params (list 3 uint))
)
  (let
    (
      (ticket-class-id (var-get next-ticket-class-id))
      (event (unwrap! (get-event event-id) (err ERR-EVENT-NOT-FOUND)))
    )
    
    ;; Check if caller is the event organizer
    (asserts! (is-eq tx-sender (get organizer event)) (err ERR-NOT-AUTHORIZED))
    
    ;; Check if event is still active and sales haven't started
    (asserts! (is-eq (get status event) EVENT-STATUS-ACTIVE) (err ERR-EVENT-NOT-ACTIVE))
    (asserts! (> (get sales-start-date event) block-height) (err ERR-SALE-STARTED))
    
    ;; Validate parameters
    (asserts! (> total-supply u0) (err ERR-INVALID-PARAMETERS))
    (asserts! (<= price-model PRICE-MODEL-DEMAND-BASED) (err ERR-INVALID-PARAMETERS))
    
    ;; Create ticket class
    (map-set ticket-classes
      { ticket-class-id: ticket-class-id }
      {
        event-id: event-id,
        name: name,
        description: description,
        base-price: base-price,
        total-supply: total-supply,
        remaining-supply: total-supply,
        resalable: resalable,
        price-model: price-model,
        max-resale-price-percentage: max-resale-price-percentage,
        dynamic-pricing-params: dynamic-pricing-params
      }
    )
    
    ;; Update event ticket counts
    (map-set events
      { event-id: event-id }
      (merge event {
        total-ticket-count: (+ (get total-ticket-count event) total-supply),
        tickets-available: (+ (get tickets-available event) total-supply)
      })
    )
    
    ;; Increment ticket class ID
    (var-set next-ticket-class-id (+ ticket-class-id u1))
    
    (ok ticket-class-id)
  )
)

;; Buy a ticket directly from primary market
(define-public (buy-ticket (ticket-class-id uint))
  (let
    (
      (ticket-class (unwrap! (get-ticket-class ticket-class-id) (err ERR-TICKET-CLASS-NOT-FOUND)))
      (event-id (get event-id ticket-class))
      (event (unwrap! (get-event event-id) (err ERR-EVENT-NOT-FOUND)))
      (ticket-id (var-get next-ticket-id))
      (current-price (calculate-current-price ticket-class-id))
      (platform-fee (/ (* current-price (var-get platform-fee-percentage)) u10000))
    )
    
    ;; Check event status
    (asserts! (is-eq (get status event) EVENT-STATUS-ACTIVE) (err ERR-EVENT-NOT-ACTIVE))
    
    ;; Check if sales have started and not ended
    (asserts! (>= block-height (get sales-start-date event)) (err ERR-SALE-NOT-STARTED))
    (asserts! (<= block-height (get sales-end-date event)) (err ERR-SALE-ENDED))
    
    ;; Check if tickets are available
    (asserts! (> (get remaining-supply ticket-class) u0) (err ERR-SOLD-OUT))
    
    ;; Check if identity verification is required
    (when (get identity-verification-required event)
      (asserts! (is-identity-verified tx-sender) (err ERR-IDENTITY-VERIFICATION-FAILED))
    )
    
    ;; Check purchase limits
    (let
      (
        (current-count (get count (get-user-ticket-count event-id tx-sender)))
      )
      (asserts! (< current-count (get max-tickets-per-buyer event)) (err ERR-PURCHASE-LIMIT-EXCEEDED))
    )
    
    ;; Transfer payment
    (try! (stx-transfer? (+ current-price platform-fee) tx-sender (get organizer event)))
    
    ;; Create verification code (hash of ticket-id + block-height + user principal)
    (let
      (
        (verification-code (sha256 (concat (concat (unwrap-panic (to-consensus-buff? ticket-id)) 
                                                 (unwrap-panic (to-consensus-buff? block-height)))
                                        (unwrap-panic (to-consensus-buff? tx-sender)))))
        (metadata-hash (sha256 (concat (concat (unwrap-panic (to-consensus-buff? ticket-id)) 
                                            (unwrap-panic (to-consensus-buff? event-id)))
                                  (unwrap-panic (to-consensus-buff? tx-sender)))))
      )
      
      ;; Create the ticket
      (map-set tickets
        { ticket-id: ticket-id }
        {
          event-id: event-id,
          ticket-class-id: ticket-class-id,
          owner: tx-sender,
          purchase-price: current-price,
          purchase-date: block-height,
          status: TICKET-STATUS-VALID,
          attended: false,
          attendance-time: none,
          verification-code: verification-code,
          resale-price: none,
          original-owner: tx-sender,
          metadata-hash: metadata-hash
        }
      )
      
      ;; Update ticket class remaining supply
      (map-set ticket-classes
        { ticket-class-id: ticket-class-id }
        (merge ticket-class {
          remaining-supply: (- (get remaining-supply ticket-class) u1)
        })
      )
      
      ;; Update event stats
      (map-set events
        { event-id: event-id }
        (merge event {
          tickets-sold: (+ (get tickets-sold event) u1),
          tickets-available: (- (get tickets-available event) u1)
        })
      )
      
      ;; Update user ticket count for this event
      (let
        (
          (current-count (get count (get-user-ticket-count event-id tx-sender)))
        )
        (map-set user-event-tickets
          { event-id: event-id, user: tx-sender }
          { count: (+ current-count u1) }
        )
      )
      
      ;; Increment ticket ID
      (var-set next-ticket-id (+ ticket-id u1))
      
      (ok ticket-id)
    )
  )
)

;; List a ticket for resale
(define-public (list-ticket-for-resale (ticket-id uint) (price uint) (expires-at (optional uint)))
  (let
    (
      (ticket (unwrap! (get-ticket ticket-id) (err ERR-TICKET-NOT-FOUND)))
      (ticket-class (unwrap! (get-ticket-class (get ticket-class-id ticket)) (err ERR-TICKET-CLASS-NOT-FOUND)))
      (event (unwrap! (get-event (get event-id ticket)) (err ERR-EVENT-NOT-FOUND)))
      (listing-id (var-get next-listing-id))
    )
    
    ;; Check if caller owns the ticket
    (asserts! (is-eq tx-sender (get owner ticket)) (err ERR-TICKET-NOT-OWNED))
    
    ;; Check if ticket is valid and not already listed
    (asserts! (is-eq (get status ticket) TICKET-STATUS-VALID) (err ERR-TICKET-NOT-RESALABLE))
    
    ;; Check if the ticket is resalable
    (asserts! (get resalable ticket-class) (err ERR-TICKET-NOT-RESALABLE))
    
    ;; Check if event is still active
    (asserts! (is-eq (get status event) EVENT-STATUS-ACTIVE) (err ERR-EVENT-NOT-ACTIVE))
    (asserts! (> (get start-date event) block-height) (err ERR-EVENT-ENDED))
    
    ;; Check price cap
    (let
      (
        (max-price (/ (* (get purchase-price ticket) 
                         (get max-resale-price-percentage ticket-class)) 
                     u10000))
      )
      (asserts! (<= price max-price) (err ERR-PRICE-EXCEEDS-CAP))
    )
    
    ;; Create listing
    (map-set ticket-listings
      { listing-id: listing-id }
      {
        ticket-id: ticket-id,
        seller: tx-sender,
        price: price,
        listed-at: block-height,
        expires-at: expires-at
      }
    )
    
    ;; Map ticket to listing
    (map-set ticket-to-listing
      { ticket-id: ticket-id }
      { listing-id: listing-id }
    )
    
    ;; Update ticket status
    (map-set tickets
      { ticket-id: ticket-id }
      (merge ticket {
        status: TICKET-STATUS-LISTED,
        resale-price: (some price)
      })
    )
      ;; Increment listing ID
    (var-set next-listing-id (+ listing-id u1))
    
    (ok listing-id)
  )
)

;; Remove a ticket listing
(define-public (cancel-listing (listing-id uint))
  (let
    (
      (listing (unwrap! (get-ticket-listing listing-id) (err ERR-NOT-LISTED)))
      (ticket-id (get ticket-id listing))
      (ticket (unwrap! (get-ticket ticket-id) (err ERR-TICKET-NOT-FOUND)))
    )
    
    ;; Check if caller is the seller
    (asserts! (is-eq tx-sender (get seller listing)) (err ERR-NOT-AUTHORIZED))
    
    ;; Check if ticket is listed
    (asserts! (is-eq (get status ticket) TICKET-STATUS-LISTED) (err ERR-NOT-LISTED))
    
    ;; Update ticket status
    (map-set tickets
      { ticket-id: ticket-id }
      (merge ticket {
        status: TICKET-STATUS-VALID,
        resale-price: none
      })
    )
    
    ;; Remove listing
    (map-delete ticket-listings { listing-id: listing-id })
    (map-delete ticket-to-listing { ticket-id: ticket-id })
    
    (ok true)
  )
)

;; Buy a ticket from secondary market
(define-public (buy-secondary-ticket (listing-id uint))
  (let
    (
      (listing (unwrap! (get-ticket-listing listing-id) (err ERR-NOT-LISTED)))
      (ticket-id (get ticket-id listing))
      (ticket (unwrap! (get-ticket ticket-id) (err ERR-TICKET-NOT-FOUND)))
      (event-id (get event-id ticket))
      (event (unwrap! (get-event event-id) (err ERR-EVENT-NOT-FOUND)))
      (price (get price listing))
      (seller (get seller listing))
      (platform-fee (/ (* price (var-get platform-fee-percentage)) u10000))
      (seller-payment (- price platform-fee))
    )
    
    ;; Check if ticket is listed and valid
    (asserts! (is-eq (get status ticket) TICKET-STATUS-LISTED) (err ERR-NOT-LISTED))
    
    ;; Check if listing has expired
    (match (get expires-at listing)
      expiry (asserts! (< block-height expiry) (err ERR-NOT-LISTED))
      true
    )
    
    ;; Check if event is still active
    (asserts! (is-eq (get status event) EVENT-STATUS-ACTIVE) (err ERR-EVENT-NOT-ACTIVE))
    (asserts! (> (get start-date event) block-height) (err ERR-EVENT-ENDED))
    
    ;; Check if identity verification is required
    (when (get identity-verification-required event)
      (asserts! (is-identity-verified tx-sender) (err ERR-IDENTITY-VERIFICATION-FAILED))
    )
    
    ;; Check purchase limits
    (let
      (
        (current-count (get count (get-user-ticket-count event-id tx-sender)))
      )
      (asserts! (< current-count (get max-tickets-per-buyer event)) (err ERR-PURCHASE-LIMIT-EXCEEDED))
    )
    
    ;; Transfer payment
    (try! (stx-transfer? price tx-sender seller))
    (try! (stx-transfer? platform-fee tx-sender (var-get contract-owner)))
    
    ;; Update ticket
    (map-set tickets
      { ticket-id: ticket-id }
      (merge ticket {
        owner: tx-sender,
        status: TICKET-STATUS-VALID,
        resale-price: none,
        metadata-hash: (sha256 (concat (concat (unwrap-panic (to-consensus-buff? ticket-id)) 
                                            (unwrap-panic (to-consensus-buff? event-id)))
                                  (unwrap-panic (to-consensus-buff? tx-sender))))
      })
    )
    
    ;; Update user ticket counts
    (let
      (
        (buyer-count (get count (get-user-ticket-count event-id tx-sender)))
        (seller-count (get count (get-user-ticket-count event-id seller)))
      )
      (map-set user-event-tickets
        { event-id: event-id, user: tx-sender }
        { count: (+ buyer-count u1) }
      )
      
      (map-set user-event-tickets
        { event-id: event-id, user: seller }
        { count: (- seller-count u1) }
      )
    )
    
    ;; Remove listing
    (map-delete ticket-listings { listing-id: listing-id })
    (map-delete ticket-to-listing { ticket-id: ticket-id })
    
    (ok ticket-id)
  )
)

;; Record ticket attendance
(define-public (record-attendance (ticket-id uint) (verification-code (buff 32)))
  (let
    (
      (ticket (unwrap! (get-ticket ticket-id) (err ERR-TICKET-NOT-FOUND)))
      (event-id (get event-id ticket))
      (event (unwrap! (get-event event-id) (err ERR-EVENT-NOT-FOUND)))
    )
    
    ;; Check if event is active and happening now
    (asserts! (is-eq (get status event) EVENT-STATUS-ACTIVE) (err ERR-EVENT-NOT-ACTIVE))
    (asserts! (>= block-height (get start-date event)) (err ERR-INVALID-PARAMETERS))
    (asserts! (<= block-height (get end-date event)) (err ERR-EVENT-ENDED))
    
    ;; Check if ticket is valid
    (asserts! (is-eq (get status ticket) TICKET-STATUS-VALID) (err ERR-TICKET-NOT-FOUND))
    
    ;; Check if ticket hasn't been used
    (asserts! (not (get attended ticket)) (err ERR-TICKET-ALREADY-USED))
    
    ;; Verify the attendance code (only event organizer can verify attendance)
    (asserts! (is-eq tx-sender (get organizer event)) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-eq verification-code (get verification-code ticket)) (err ERR-IDENTITY-VERIFICATION-FAILED))
    
    ;; Update ticket attendance status
    (map-set tickets
      { ticket-id: ticket-id }
      (merge ticket {
        attended: true,
        attendance-time: (some block-height)
      })
    )
    
    (ok true)
  )
)

;; Request a refund for a ticket
(define-public (request-refund (ticket-id uint))
  (let
    (
      (ticket (unwrap! (get-ticket ticket-id) (err ERR-TICKET-NOT-FOUND)))
      (event-id (get event-id ticket))
      (event (unwrap! (get-event event-id) (err ERR-EVENT-NOT-FOUND)))
      (ticket-class (unwrap! (get-ticket-class (get ticket-class-id ticket)) (err ERR-TICKET-CLASS-NOT-FOUND)))
      (refund-cutoff-time (- (get start-date event) (* (get refund-window-hours event) u6))) ;; Assuming 6 blocks per hour
    )
    
    ;; Check if caller owns the ticket
    (asserts! (is-eq tx-sender (get owner ticket)) (err ERR-TICKET-NOT-OWNED))
    
    ;; Check if ticket is valid (not used or already refunded)
    (asserts! (is-eq (get status ticket) TICKET-STATUS-VALID) (err ERR-INVALID-PARAMETERS))
    
    ;; Check if event hasn't been canceled
    (asserts! (not (is-eq (get status event) EVENT-STATUS-CANCELED)) (err ERR-EVENT-CANCELED))
    
    ;; Check if still within refund window
    (asserts! (< block-height refund-cutoff-time) (err ERR-REFUND-WINDOW-EXPIRED))
    
    ;; Calculate refund amount (may include a refund fee in a real implementation)
    (let
      (
        (refund-amount (get p