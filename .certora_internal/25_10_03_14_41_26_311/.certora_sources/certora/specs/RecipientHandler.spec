
  using RecipientHandlerHarness as H;
  using MockERC20 as T;

  methods {
   
    function H.h_bindService(uint128 serviceId, address seller) external;

    function H.payWithEIP712(
      RecipientHandlerHarness.Order o,
      bytes sigBuyer,
      RecipientHandlerHarness.PriceQuote q,
      bytes sigSeller,
      bytes data1,
      bytes data2
    ) external;

    function H.nonces(address owner) external returns (uint);

    function H.h_checkOrderSig(
      RecipientHandlerHarness.Order o,
      bytes signature
    ) external returns (bool);

    function H.h_checkQuoteSig(
      RecipientHandlerHarness.PriceQuote q,
      bytes signature
    ) external returns (bool);

    // MockERC20
    function T.mint(address to, uint amount) external;
    function T.approve(address spender, uint amount) external;
    function T.balanceOf(address who) external returns (uint);
  }

  rule PayWithEIP712_InvalidBuyerSig_ShouldRevert(
    address buyer,
    address seller,
    uint128 serviceId,
    uint amount,
    uint cost,
    uint64 deadline,
    bytes sigBuyer,
    bytes sigSeller
  ) {
    require(buyer  != address(0));
    require(seller != address(0));
    require(amount > 0);
    require(cost   > 0);
    require(cost   < amount);

    env e;

    // 避免因过期先行 revert
    require(e.block.timestamp < deadline);

    // 绑定服务（用合约自身调用最稳）
    H.h_bindService(serviceId, seller);

    // 资金与授权（示例：给 buyer 铸币并授权给 handler）
    T.mint(buyer, amount);
    e.msg.sender = buyer;
    T.approve(address(H), amount);

    address payTo        = address(H);
    address paymentToken = address(T);
    bytes32 quoteId = keccak256(abi.encode(buyer, paymentToken, seller, serviceId, amount, cost));
    uint n = H.nonces(buyer);   

    H.Order o =
      H.Order(
        buyer, payTo, paymentToken, amount, n, quoteId, serviceId, deadline
      );

    H.PriceQuote q =
      H.PriceQuote(
        quoteId, paymentToken, seller, amount, cost, serviceId, deadline
      );

    // 只让“买家签名无效”成为失败原因
    assume !H.h_checkOrderSig(o, sigBuyer);
    assume  H.h_checkQuoteSig(q, sigSeller);

    // 由 buyer 发起
    e.msg.sender = buyer;
    H.payWithEIP712@withrevert(o, sigBuyer, q, sigSeller, "", "");

    assert lastReverted;
  }

