# Decentralized Event Ticketing System

A blockchain-based platform for event ticket issuance and management with built-in anti-scalping measures.

## Overview

This smart contract system provides a comprehensive solution for event organizers to create and manage events, issue tickets, and handle the full event lifecycle. It includes features for both primary sales and a controlled secondary market with price caps to prevent scalping.

## Features

- **Event Management**
  - Create and manage events with detailed metadata
  - Set flexible schedules for sales periods and event times
  - Cancel events and handle automatic refunds
  - Event status tracking (active, canceled, completed)

- **Ticket Classes**
  - Create multiple ticket types per event (e.g., VIP, General Admission)
  - Configure dynamic pricing models (fixed, time-based, demand-based)
  - Set ticket supply limits

- **Primary Market**
  - Direct ticket sales to consumers
  - Purchase limits per buyer
  - Optional identity verification requirements
  - Dynamic pricing based on time or demand

- **Secondary Market**
  - Controlled resale marketplace
  - Price caps to prevent scalping (configurable per ticket class)
  - Secure ownership transfers
  - Listing expiration options

- **Attendance & Verification**
  - Digital ticket verification
  - Attendance tracking
  - Anti-fraud verification codes

- **Refund Management**
  - Configurable refund policies
  - Time-based refund windows
  - Automatic refund processing for canceled events

- **Additional Features**
  - Waitlists for sold-out events
  - Identity verification system
  - Platform fees and revenue sharing
  - Contract ownership and administration

## Technical Components

The system consists of the following main components:

1. **Data Structures**
   - Events
   - Ticket Classes
   - Tickets
   - Secondary Market Listings
   - User Identity Verification
   - Waitlists

2. **Core Functions**
   - Event creation and management
   - Ticket issuance and sales
   - Secondary market operations
   - Attendance verification
   - Refund processing

3. **Administrative Functions**
   - Fee management
   - Contract ownership
   - Organizer verification

## Usage Instructions

### For Event Organizers

1. **Registration**
   ```clarity
   (register-organizer "Organizer Name")
   ```

2. **Creating an Event**
   ```clarity
   (create-event 
     "Event Name" 
     "Description" 
     "Venue" 
     start-date 
     end-date 
     "Refund Policy" 
     refund-window-hours 
     identity-verification-required 
     max-tickets-per-buyer 
     sales-start-date 
     sales-end-date 
     "Image URL"
   )
   ```

3. **Adding Ticket Classes**
   ```clarity
   (add-ticket-class 
     event-id 
     "Ticket Class Name" 
     "Description" 
     base-price 
     total-supply 
     resalable 
     price-model 
     max-resale-price-percentage 
     dynamic-pricing-params
   )
   ```

4. **Canceling an Event**
   ```clarity
   (cancel-event event-id)
   ```

5. **Recording Attendance**
   ```clarity
   (record-attendance ticket-id verification-code)
   ```

### For Ticket Buyers

1. **Buying a Ticket (Primary Market)**
   ```clarity
   (buy-ticket ticket-class-id)
   ```

2. **Reselling a Ticket**
   ```clarity
   (list-ticket-for-resale ticket-id price expires-at)
   ```

3. **Buying a Resold Ticket**
   ```clarity
   (buy-secondary-ticket listing-id)
   ```

4. **Requesting a Refund**
   ```clarity
   (request-refund ticket-id)
   ```

5. **Verifying Identity**
   ```clarity
   (verify-user-identity verification-hash)
   ```

6. **Joining a Waitlist**
   ```clarity
   (join-waitlist event-id ticket-class-id)
   ```

## Error Codes

The contract defines various error codes to handle different scenarios:

- `ERR-NOT-AUTHORIZED (u1)`: Caller doesn't have permission for this action
- `ERR-EVENT-NOT-FOUND (u2)`: The requested event doesn't exist
- `ERR-TICKET-NOT-FOUND (u3)`: The requested ticket doesn't exist
- `ERR-SOLD-OUT (u6)`: No more tickets available for purchase
- `ERR-TICKET-NOT-OWNED (u10)`: Caller doesn't own the ticket
- `ERR-PRICE-EXCEEDS-CAP (u12)`: Resale price exceeds allowed maximum

## Testing

The contract comes with a comprehensive test suite that covers all main functionality:

- Primary market operations
- Secondary market operations
- Event management
- Attendance verification
- Refunds and cancellations
- Administrative functions

To run the tests:

1. Install Clarinet: Follow the installation instructions at [Clarinet's documentation](https://github.com/hirosystems/clarinet)
2. Navigate to the project directory
3. Run `clarinet test`

## License

[License information placeholder]

## Contributing

