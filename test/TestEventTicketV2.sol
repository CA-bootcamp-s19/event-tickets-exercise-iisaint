pragma solidity ^0.5.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/EventTickets.sol";
import "../contracts/EventTicketsV2.sol";

contract testSecondAccount {
  function callAddEvent(address _contract, string memory _description, string memory _website, uint _ticketsAvailable) public returns (bool r) {
    EventTicketsV2 instance = EventTicketsV2(_contract);
    (r, ) = address(instance).call(abi.encodeWithSelector(instance.addEvent.selector, _description, _website, _ticketsAvailable));
  }

  function callGetRefund(address _contract, uint _eventId) public returns (bool r) {
    EventTicketsV2 instance = EventTicketsV2(_contract);
    (r, ) = address(instance).call(abi.encodeWithSelector(instance.getRefund.selector, _eventId));
  }

  function callEndSale(address _contract, uint _eventId) public returns (bool r) {
    EventTicketsV2 instance = EventTicketsV2(_contract);
    (r, ) = address(instance).call(abi.encodeWithSelector(instance.endSale.selector, _eventId));
  }
}

contract testEventTicketV2 {
  uint public initialBalance = 1 ether;

  address firstAccount = address(this);

  string description = "description";
  string url = "URL";
  uint ticketNumber = 100;

  uint ticketPrice = 100;

  EventTicketsV2 instance;

  function beforeEach() public {
    instance = new EventTicketsV2();
  }

  function testSetup() public {
    address owner = instance.owner();
    Assert.equal(owner, firstAccount, "OWNER should be set to the deploying address");
  }

  function testAddEvent() public {
    testSecondAccount secondAccount = new testSecondAccount();
    bool r;
    r = secondAccount.callAddEvent(address(instance), description, url, ticketNumber);
    Assert.isFalse(r, "only the owner should be able to add an event");
  }

  function testReadEvent() public {
    uint eventId = instance.addEvent(description, url, ticketNumber);
    (string memory _description, string memory _website, uint _ticketsAvailable, uint _sales, bool _isOpen) = instance.readEvent(eventId);

    Assert.equal(_description, description, "the event descriptions should match");
    Assert.equal(_website, url, "the website details should match");
    Assert.equal(_ticketsAvailable, ticketNumber, "the same number of tickets should be available");
    Assert.equal(_sales, 0, "the ticket sales should be 0");
    Assert.equal(_isOpen, true, "the event should be open");
  }

  function testBuyTicketsNotOpen() public {
    uint numberOfTickets = 1;
                
    // event w/ id 1 does not exist, therefore not open
    (bool r, ) = address(instance).call(abi.encodeWithSelector(instance.buyTickets.selector, 1, numberOfTickets));
    Assert.isFalse(r, "tickets should only be able to be purchased when the event is open");
  }

  function testBuyTickets() public {
    uint numberOfTickets = 1;
    uint eventId = instance.addEvent(description, url, ticketNumber);
    (bool r, ) = address(instance).call.value(ticketPrice)(abi.encodeWithSelector(instance.buyTickets.selector, eventId, numberOfTickets));
    Assert.isTrue(r, "buy tickets falied");
    ( , , , uint _sales, ) = instance.readEvent(eventId);
    Assert.equal(_sales, numberOfTickets, "the ticket sales should be 1");
  }

  function testBuyTicketsNotEnoughValue() public {
    uint numberOfTickets = 1;
    uint eventId = instance.addEvent(description, url, ticketNumber);
    (bool r, ) = address(instance).call.value(ticketPrice - 1)(abi.encodeWithSelector(instance.buyTickets.selector, eventId, numberOfTickets));
    Assert.isFalse(r, "buy tickets should be failed");
  }

  function testBuyTicketsNotEnoughNumber() public {
    uint numberOfTickets = 51;
    uint eventId = instance.addEvent(description, url, ticketNumber);
    bool r;
    (r, ) = address(instance).call.value(ticketPrice * numberOfTickets)(abi.encodeWithSelector(instance.buyTickets.selector, eventId, numberOfTickets));
    Assert.isTrue(r, "buy tickets failed");
    (r, ) = address(instance).call.value(ticketPrice * numberOfTickets)(abi.encodeWithSelector(instance.buyTickets.selector, eventId, numberOfTickets));
    Assert.isFalse(r, "buy tickets should be failed");
  }

  function testGetRefund() public {
    bool r;
    uint numberOfTickets = 1;
    uint eventId = instance.addEvent(description, url, ticketNumber);
    (r, ) = address(instance).call.value(ticketPrice)(abi.encodeWithSelector(instance.buyTickets.selector, eventId, numberOfTickets));
    Assert.isTrue(r, "buy tickets falied");

    testSecondAccount secondAccount = new testSecondAccount();
    r = secondAccount.callGetRefund(address(instance), eventId);
    Assert.isFalse(r, "only accounts that have purchased tickets should be able to get a refund");

    (r, ) = address(instance).call(abi.encodeWithSelector(instance.getRefund.selector, eventId));
    Assert.isTrue(r, "getRefund failed");
  }

  function testGetRefundAmount() public {
    bool r;
    uint numberOfTickets = 1;
    uint eventId = instance.addEvent(description, url, ticketNumber);
    uint preSaleAmount = firstAccount.balance;
    (r, ) = address(instance).call.value(ticketPrice)(abi.encodeWithSelector(instance.buyTickets.selector, eventId, numberOfTickets));
    uint postSaleAmount = firstAccount.balance;
    Assert.equal(postSaleAmount, preSaleAmount - ticketPrice, "postSaleAmount = preSaleAmount - ticketPrice");
    (r, ) = address(instance).call(abi.encodeWithSelector(instance.getRefund.selector, eventId));
    Assert.isTrue(r, "getRefund failed");
    postSaleAmount = firstAccount.balance;
    Assert.equal(postSaleAmount, preSaleAmount, "buyer should be fully refunded when calling getRefund()");
  }

  function testGetBuyerNumberTickets() public {
    uint numberToPurchase = 3;
    uint eventId = instance.addEvent(description, url, ticketNumber);
    (bool r, ) = address(instance).call.value(ticketPrice * numberToPurchase)(abi.encodeWithSelector(instance.buyTickets.selector, eventId, numberToPurchase));
    fixWarning(r);
    uint result = instance.getBuyerNumberTickets(eventId);
    Assert.equal(result, numberToPurchase, "getBuyerNumberTickets() should return the number of tickets the msg.sender has purchased.");
  }

  function testEndSale() public {
    uint eventId = instance.addEvent(description, url, ticketNumber);

    testSecondAccount secondAccount = new testSecondAccount();
    bool r = secondAccount.callEndSale(address(instance), eventId);
    Assert.isFalse(r, "only the owner should be able to end the sale and mark it as closed");

    (r, ) = address(instance).call(abi.encodeWithSelector(instance.endSale.selector, eventId));
    Assert.isTrue(r, "endSale is failed");
    
    ( , , , , bool isOpen ) = instance.readEvent(eventId);
    Assert.equal(isOpen , false, "The event isOpen variable should be marked false.");
  }

  // fallback
  function () external payable {

  }

  function fixWarning(bool r) internal pure {
    r;
  }
}