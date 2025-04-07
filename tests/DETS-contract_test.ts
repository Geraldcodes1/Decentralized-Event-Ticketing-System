/**
 * Test script for Decentralized Event Ticketing System Clarity contract
 */

import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

// Helper function to create a test event
function createEvent(chain, deployer, name, startDate, endDate) {
  const block = chain.mineBlock([
    Tx.contractCall(
      'event-ticketing', // replace with your actual contract name
      'create-event',
      [
        types.utf8(name), // name
        types.utf8('Test event description'), // description
        types.utf8('Test Venue'), // venue
        types.uint(startDate), // start-date
        types.uint(endDate), // end-date
        types.utf8('No refunds after event starts'), // refund-policy
        types.uint(24), // refund-window-hours
        types.bool(false), // identity-verification-required
        types.uint(5), // max-tickets-per-buyer
        types.uint(chain.blockHeight), // sales-start-date
        types.uint(startDate - 1), // sales-end-date
        types.utf8('https://example.com/image.jpg') // image-url
      ],
      deployer.address
    )
  ]);
  return parseInt(block.receipts[0].result.substr(1));
}
// Helper function to add a ticket class
function addTicketClass(chain, deployer, eventId, name, price, supply) {
    const block = chain.mineBlock([
      Tx.contractCall(
        'event-ticketing',
        'add-ticket-class',
        [
          types.uint(eventId), // event-id
          types.utf8(name), // name
          types.utf8('Standard ticket'), // description
          types.uint(price), // base-price
          types.uint(supply), // total-supply
          types.bool(true), // resalable
          types.uint(1), // price-model (PRICE-MODEL-FIXED)
          types.uint(11000), // max-resale-price-percentage (110%)
          types.list([types.uint(10), types.uint(20), types.uint(30)]) // dynamic-pricing-params
        ],
        deployer.address
      )
    ]);
    return parseInt(block.receipts[0].result.substr(1));
  }
  
  // Main test suite
  Clarinet.test({
    name: "Event Ticketing System Test Suite",
    async fn(chain: Chain, accounts: Map<string, Account>) {
      const deployer = accounts.get('deployer')!;
      const user1 = accounts.get('wallet_1')!;
      const user2 = accounts.get('wallet_2')!;
      const user3 = accounts.get('wallet_3')!;
      
      // Test 1: Register as event organizer
      let block = chain.mineBlock([
        Tx.contractCall(
          'event-ticketing',
          'register-organizer',
          [types.utf8('Test Organizer')],
          deployer.address
        )
      ]);
      assertEquals(block.receipts[0].result, '(ok true)');
      
      // Test 2: Create an event
      const startDate = chain.blockHeight + 100;
      const endDate = startDate + 10;
      const eventId = createEvent(chain, deployer, 'Test Concert', startDate, endDate);
      
      // Verify event was created
      let eventResult = chain.callReadOnlyFn(
        'event-ticketing',
        'get-event',
        [types.uint(eventId)],
        deployer.address
      );
      assertEquals(eventResult.result.value['name'].value, 'Test Concert');
      
      // Test 3: Add ticket class to the event
      const ticketClassId = addTicketClass(chain, deployer, eventId, 'General Admission', 100000000, 100);
      
      // Verify ticket class was created
      let ticketClassResult = chain.callReadOnlyFn(
        'event-ticketing',
        'get-ticket-class',
        [types.uint(ticketClassId)],
        deployer.address
      );
      assertEquals(ticketClassResult.result.value['name'].value, 'General Admission');
      assertEquals(ticketClassResult.result.value['base-price'].value, '100000000');
      
      // Test 4: Buy a ticket
      block = chain.mineBlock([
        Tx.contractCall(
          'event-ticketing',
          'buy-ticket',
          [types.uint(ticketClassId)],
          user1.address
        )
      ]);
      const ticketId = parseInt(block.receipts[0].result.substr(1));
    
      // Verify ticket was purchased
      let ticketResult = chain.callReadOnlyFn(
        'event-ticketing',
        'get-ticket',
        [types.uint(ticketId)],
        user1.address
      );
      assertEquals(ticketResult.result.value['owner'].value, user1.address);
      assertEquals(ticketResult.result.value['status'].value, '1'); // TICKET-STATUS-VALID
      
      // Test 5: List a ticket for resale
      block = chain.mineBlock([
        Tx.contractCall(
          'event-ticketing',
          'list-ticket-for-resale',
          [
            types.uint(ticketId),
            types.uint(105000000), // 5% markup
            types.none() // no expiry
          ],
          user1.address
        )
      ]);
      const listingId = parseInt(block.receipts[0].result.substr(1));
      
      // Verify listing was created
      let listingResult = chain.callReadOnlyFn(
        'event-ticketing',
        'get-ticket-listing',
        [types.uint(listingId)],
        user1.address
      );
      assertEquals(listingResult.result.value['seller'].value, user1.address);
      assertEquals(listingResult.result.value['price'].value, '105000000');
        // Test 6: Buy a ticket from secondary market
    block = chain.mineBlock([
        Tx.contractCall(
          'event-ticketing',
          'buy-secondary-ticket',
          [types.uint(listingId)],
          user2.address
        )
      ]);
      assertEquals(block.receipts[0].result, `(ok ${ticketId})`);
      
      // Verify ticket ownership transferred
      ticketResult = chain.callReadOnlyFn(
        'event-ticketing',
        'get-ticket',
        [types.uint(ticketId)],
        user2.address
      );
      assertEquals(ticketResult.result.value['owner'].value, user2.address);
      assertEquals(ticketResult.result.value['status'].value, '1'); // TICKET-STATUS-VALID
      
      // Test 7: Buy another ticket directly for user3
      block = chain.mineBlock([
        Tx.contractCall(
          'event-ticketing',
          'buy-ticket',
          [types.uint(ticketClassId)],
          user3.address
        )
      ]);
      const ticketId2 = parseInt(block.receipts[0].result.substr(1));
         // Test 8: Verify user identity for attendance
    const verificationHash = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
    block = chain.mineBlock([
      Tx.contractCall(
        'event-ticketing',
        'verify-user-identity',
        [types.buff(verificationHash)],
        user3.address
      )
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
    
    // Verify identity was recorded
    let verificationResult = chain.callReadOnlyFn(
      'event-ticketing',
      'is-identity-verified',
      [types.principal(user3.address)],
      deployer.address
    );
    assertEquals(verificationResult.result, 'true');
    
    // Test 9: Request a refund
    // First, advance to within refund window
    chain.mineEmptyBlockUntil(startDate - 30);
    
    block = chain.mineBlock([
      Tx.contractCall(
        'event-ticketing',
        'request-refund',
        [types.uint(ticketId2)],
        user3.address
      )
    ]);
    // Expected result is ok with refund amount
    assertEquals(block.receipts[0].result.includes('ok u'), true);
    
    // Verify ticket was refunded
    ticketResult = chain.callReadOnlyFn(
      'event-ticketing',
      'get-ticket',
      [types.uint(ticketId2)],
      user3.address
    );
    assertEquals(ticketResult.result.value['status'].value, '3'); // TICKET-STATUS-REFUNDED
    
    // Test 10: Advance to event time and record attendance
    chain.mineEmptyBlockUntil(startDate + 1);
    
    // Get verification code from ticket
    let ticketVerificationData = chain.callReadOnlyFn(
      'event-ticketing',
      'generate-ticket-verification-data',
      [types.uint(ticketId)],
      deployer.address
    );
    
    const verificationCode = ticketVerificationData.result.value['verification-code'].value;
    