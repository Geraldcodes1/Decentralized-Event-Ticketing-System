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