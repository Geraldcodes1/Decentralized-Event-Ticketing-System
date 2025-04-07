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
