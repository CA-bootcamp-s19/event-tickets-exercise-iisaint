pragma solidity ^0.5.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/EventTickets.sol";
import "../contracts/EventTicketsV2.sol";

contract testSecondAccount {
  function callEndSale(address _EventTickets) public returns (bool r) {
    EventTickets instance = EventTickets(_EventTickets);
    (r, ) = address(instance).call(abi.encodeWithSelector(instance.endSale.selector));
  }

  function () external payable {

  }
}
contract TestEventTicket {
  // Truffle will send the TestSupplyChain 1 ether after deploying the contract.
  uint public initialBalance = 1 ether;

  address firstAccount = address(this);

  string description = "description";
  string url = "URL";
  uint ticketNumber = 100;

  uint ticketPrice = 100;

  EventTickets instance;

  function beforeEach() public {
    instance = new EventTickets(description, url, ticketNumber);
  }

  function testSetup() public {
    address owner = instance.owner();
    Assert.equal(owner, firstAccount, "the deploying address should be the owner");

    ( , , , , bool isOpen) = instance.readEvent();
    Assert.equal(isOpen, true, "the event should be open");
  }

  function testReadEvent() public {
    (string memory _description, string memory _url, uint _ticketAvabilable, uint _sales, ) = instance.readEvent();
    Assert.equal(_description, description, "the event descriptions should match");
    Assert.equal(_url, url, "the event urls should match");
    Assert.equal(_ticketAvabilable, ticketNumber, "the number of tickets for sale should be set");
    Assert.equal(_sales, 0, "the ticket sales should be 0");
  }

  function testBuyTicketsWhenOpen() public {
    (bool r, ) = address(instance).call.value(ticketPrice)(abi.encodeWithSelector(instance.buyTickets.selector, 1));
    Assert.isTrue(r, "buy ticket failed");

    ( , , , uint _sales, ) = instance.readEvent();
    Assert.equal(_sales, 1, "the ticket sales should be 1");
  }
  function testBuyTicketsNotEnoughPaid() public {
    (bool r, ) = address(instance).call.value(ticketPrice - 1)(abi.encodeWithSelector(instance.buyTickets.selector, 1));
    Assert.isFalse(r, "tickets should only be able to be purchased when the msg.value is greater than or equal to the ticket cost");
  }
  function testBuyTicketsNotEnoughRemaining() public {
    bool r;
    (r, ) = address(instance).call.value(ticketPrice * 50)(abi.encodeWithSelector(instance.buyTickets.selector, 50));
    fixWarning(r);
    (r, ) = address(instance).call.value(ticketPrice * 51)(abi.encodeWithSelector(instance.buyTickets.selector, 51));
    Assert.isFalse(r, "tickets should only be able to be purchased when there are enough remaining");
  }
  function testBuyTicketsBuyerTicketCount() public {
    (bool r, ) = address(instance).call.value(ticketPrice * 2)(abi.encodeWithSelector(instance.buyTickets.selector, 2));
    fixWarning(r);
    uint count = instance.getBuyerTicketCount(firstAccount);
    Assert.equal(count, 2, "the buyer should have 2 tickets in their account");
  }

  function testBuyTicketsSalesCount() public {
    (bool r, ) = address(instance).call.value(ticketPrice * 2)(abi.encodeWithSelector(instance.buyTickets.selector, 2));
    fixWarning(r);
    ( , , , uint sales, ) = instance.readEvent();
    Assert.equal(sales, 2, "the event should have 2 sales recorded");
  }

  function testBuyTicketRefundAnySurplusFunds() public {
    uint paymentAmount = ticketPrice * 5;
    uint preSaleAmount = firstAccount.balance;
    (bool r, ) = address(instance).call.value(paymentAmount)(abi.encodeWithSelector(instance.buyTickets.selector, 1));
    fixWarning(r);
    uint postSaleAmount = firstAccount.balance;
    Assert.equal(postSaleAmount, preSaleAmount - ticketPrice, "overpayment should be refunded");
  }

  function testGetRefund() public {
    bool r;
    uint preSaleAmount = firstAccount.balance;
    (r, ) = address(instance).call.value(ticketPrice)(abi.encodeWithSelector(instance.buyTickets.selector, 1));
    uint postSaleAmount = firstAccount.balance;
    Assert.equal(postSaleAmount, preSaleAmount - ticketPrice, "postSaleAmount = preSaleAmount - ticketPrice");
    (r, ) = address(instance).call(abi.encodeWithSelector(instance.getRefund.selector));
    Assert.isTrue(r, "getRefund failed");
    postSaleAmount = firstAccount.balance;
    Assert.equal(postSaleAmount, preSaleAmount, "buyer should be fully refunded when calling getRefund()");
  }

  function testEndSale() public {
    (bool r, ) = address(instance).call(abi.encodeWithSelector(instance.endSale.selector));
    Assert.isTrue(r, "endSale failed");
    
    ( , , , , bool isOpen) = instance.readEvent();
    Assert.equal(isOpen, false, "ticket sales should be closed when the owner calls endSale()");
  }

  function testEndSaleNotOnwer() public {
    testSecondAccount secondAccount = new testSecondAccount(); 
    bool r = secondAccount.callEndSale(address(instance));
    Assert.isFalse(r, "addresses other than the owner should not be able to close the event");
  }

  function testEndSaleBuyTicket() public {
    bool r;
    (r, ) = address(instance).call(abi.encodeWithSelector(instance.endSale.selector));
    Assert.isTrue(r, "endSale failed");
    
    (r, ) = address(instance).call.value(ticketPrice)(abi.encodeWithSelector(instance.buyTickets.selector, 1));
    Assert.isFalse(r, "tickets should be able to be purchased when the event is not open");
  }

  function testEndSaleOwnerBalance() public {
    bool r;
    uint preSaleAmount = firstAccount.balance;
    (r, ) = address(instance).call.value(ticketPrice)(abi.encodeWithSelector(instance.buyTickets.selector, 1));
    uint postSaleAmount = firstAccount.balance;
    Assert.equal(postSaleAmount, preSaleAmount - ticketPrice, "postSaleAmount = preSaleAmount - ticketPrice");
    (r, ) = address(instance).call(abi.encodeWithSelector(instance.endSale.selector));
    Assert.isTrue(r, "endEvent failed");
    postSaleAmount = firstAccount.balance;
    Assert.equal(postSaleAmount, preSaleAmount, "the contract balance should be transferred to the owner when the event is closed");
  }

  // helper function
  function fixWarning(bool r) internal pure {
    r;
  }
  
  // fallback to receive refund
  function () external payable {

  }
}