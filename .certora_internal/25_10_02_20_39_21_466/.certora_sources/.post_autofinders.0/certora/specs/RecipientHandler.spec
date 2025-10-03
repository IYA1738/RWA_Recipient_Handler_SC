// --- 需要的 method 声明（按你的合约名/签名改名即可） ---
method h_bindService(uint128 serviceId, address seller);
method payWithEIP712(
    RecipientHandlerHarness.Order o,
    bytes sigBuyer,
    RecipientHandlerHarness.PriceQuote q,
    bytes sigSeller,
    bytes data1,
    bytes data2
);
method nonces(address owner) returns uint;
method h_checkOrderSig(RecipientHandlerHarness.Order o, bytes sig) returns bool;
method h_checkQuoteSig(RecipientHandlerHarness.PriceQuote q, bytes sig) returns bool;

// ERC20
method mint(address to, uint amount);
method approve(address spender, uint amount);
method balanceOf(address who) returns uint;


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

  // 避免因为过期先行 revert
  assume e.block.timestamp < deadline;

  // 绑定服务（由合约自己发起最稳）
  e.msg.sender = address(handler);
  call e.handler.h_bindService(serviceId, seller);

  // 资金与授权
  call e.token.mint(buyer, amount);     // 若没有 mint，用 ghost/assume balance 也行
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

  // 只让“买家签名无效”成为失败原因
  assume !handler.h_checkOrderSig(o, sigBuyer);
  assume  handler.h_checkQuoteSig(q, sigSeller);

  // 由 buyer 调用
  e.msg.sender = buyer;
  call e.handler.payWithEIP712@withrevert(o, sigBuyer, q, sigSeller, "", "");

  assert lastReverted;
}
