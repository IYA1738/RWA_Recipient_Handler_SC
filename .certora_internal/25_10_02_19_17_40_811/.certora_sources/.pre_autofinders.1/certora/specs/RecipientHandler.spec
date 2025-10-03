rule PayWithEIP712_InvalidBuyerSig_ShouldRevert(
  RecipientHandlerHarness handler,
  MockERC20 token,
  address buyer,
  address seller,
  uint128 serviceId,
  uint amount,
  uint cost,
  uint64 deadline,
  bytes sigBuyer,
  bytes sigSeller
) {
  require buyer  != 0;
  require seller != 0;
  require amount > 0;
  require cost   > 0;
  require cost   < amount;

  env e;
  assume deadline > e.block.timestamp;

  e.msg.sender = address(handler);
  call e.handler.h_bindService(serviceId, seller);

  call e.token.mint(buyer, amount);
  e.msg.sender = buyer;
  call e.token.approve(address(handler), amount);

  address payTo        = address(handler);
  address paymentToken = address(token);
  bytes32 quoteId = keccak256(abi.encode(buyer, paymentToken, seller, serviceId, amount, cost));
  uint n = handler.nonces(buyer);

  RecipientHandlerHarness.Order o =
    RecipientHandlerHarness.Order(
      buyer, payTo, paymentToken, amount, n, quoteId, serviceId, deadline
    );

  RecipientHandlerHarness.PriceQuote q =
    RecipientHandlerHarness.PriceQuote(
      quoteId, paymentToken, seller, amount, cost, serviceId, deadline
    );

  assume !handler.h_checkOrderSig(o, sigBuyer);
  assume  handler.h_checkQuoteSig(q, sigSeller);

  e.msg.sender = buyer;
  call e.handler.payWithEIP712@withrevert(o, sigBuyer, q, sigSeller, "", "");

  assert lastReverted;
}
