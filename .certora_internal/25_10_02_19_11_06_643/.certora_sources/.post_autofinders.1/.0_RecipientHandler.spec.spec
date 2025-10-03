rule PayWithEIP712_ValidSigs_ShouldNotRevert(
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

  env e;

  // 避免“过期”导致的无关 revert
  assume deadline > e.block.timestamp;

  // 绑定服务（用合约自身作为操作者最稳）
  e.msg.sender = address(handler);
  call e.handler.h_bindService(serviceId, seller);

  // 资金准备：给 buyer 足额余额并授权给 handler
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

  // 只在“签名正确”这条路径上验证成功
  assume handler.h_checkOrderSig(o, sigBuyer);
  assume handler.h_checkQuoteSig(q, sigSeller);

  uint buyerBalBefore   = token.balanceOf(buyer);
  uint handlerBalBefore = token.balanceOf(payTo);

  e.msg.sender = buyer;
  call e.handler.payWithEIP712@withrevert(o, sigBuyer, q, sigSeller, "", "");

  // 必须不 revert
  assert !lastReverted;

  // 至少验证“完成交易”的核心效果：扣款给 handler（你的系统后续可能再分账）
  assert token.balanceOf(buyer)   == buyerBalBefore - amount;
  assert token.balanceOf(payTo)   == handlerBalBefore + amount;

  // （可选）nonce 消耗
  assert handler.nonces(buyer) == n + 1;
}
