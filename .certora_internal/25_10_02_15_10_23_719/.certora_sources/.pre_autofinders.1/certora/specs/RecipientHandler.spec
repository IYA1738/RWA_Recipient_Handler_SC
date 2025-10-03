rule BuyerInvalidSig_ShouldRevert(
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
){
  require buyer  != 0;
  require seller != 0;
  require amount > 0;
  require cost   > 0;
  require cost   < amount;

  handler.h_bindService(serviceId, seller);

  address payTo = address(handler);
  address paymentToken = address(token);
  bytes32 quoteId = keccak256(abi.encode(buyer, paymentToken, seller, serviceId, amount, cost));

  RecipientHandlerHarness.Order o =
    RecipientHandlerHarness.Order(
      buyer,
      payTo,
      paymentToken,
      amount,
      handler.nonces(buyer),
      quoteId,
      serviceId,
      deadline
    );

  RecipientHandlerHarness.PriceQuote q =
    RecipientHandlerHarness.PriceQuote(
      quoteId,
      paymentToken,
      seller,
      amount,
      cost,
      serviceId,
      deadline
    );

  assume !handler.h_checkOrderSig(o, sigBuyer);
  assume  handler.h_checkQuoteSig(q, sigSeller);

  token.setAllowance(buyer, address(handler), amount);

  expect revert;
  handler.payWithEIP712(o, sigBuyer, q, sigSeller, "", "");
}
