
  using RecipientHandlerHarness as H;
  using MockERC20 as T;

  methods {
    // RecipientHandlerHarness
    H.h_bindService(uint128 serviceId, address seller) external;

    H.payWithEIP712(
      RecipientHandlerHarness.Order o,
      bytes sigBuyer,
      RecipientHandlerHarness.PriceQuote q,
      bytes sigSeller,
      bytes data1,
      bytes data2
    ) external;

    H.nonces(address owner) external returns (uint);

    H.h_checkOrderSig(
      RecipientHandlerHarness.Order o,
      bytes sig
    ) external returns (bool);

    H.h_checkQuoteSig(
      RecipientHandlerHarness.PriceQuote q,
      bytes sig
    ) external returns (bool);

    // MockERC20
    T.mint(address to, uint amount) external;
    T.approve(address spender, uint amount) external;
    T.balanceOf(address who) external returns (uint);
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
    require buyer  != address(0);
    require seller != address(0);
    require amount > 0;
    require cost   > 0;
    require cost   < amount;

    env e;

    // 避免因过期先行 revert
    assume e.block.timestamp < deadline;

    // 绑定服务（用合约自身调用最稳）
    e.msg.H = address(H);
    call e.H.h_bindService(serviceId, seller);

    // 资金与授权（示例：给 buyer 铸币并授权给 handler）
    call e.T.mint(buyer, amount);
    e.msg.sender = buyer;
    call e.T.approve(address(H), amount);

    address payTo        = address(H);
    address paymentToken = address(T);
    bytes32 quoteId = keccak256(abi.encode(buyer, paymentToken, seller, serviceId, amount, cost));
    uint n = handler.nonces(buyer);   // view 调用：不用 call

    RecipientHandlerHarness.Order o =
      RecipientHandlerHarness.Order(
        buyer, payTo, paymentToken, amount, n, quoteId, serviceId, deadline
      );

    RecipientHandlerHarness.PriceQuote q =
      RecipientHandlerHarness.PriceQuote(
        quoteId, paymentToken, seller, amount, cost, serviceId, deadline
      );

    // 只让“买家签名无效”成为失败原因
    assume !H.h_checkOrderSig(o, sigBuyer);
    assume  H.h_checkQuoteSig(q, sigSeller);

    // 由 buyer 发起
    e.msg.sender = buyer;
    call e.H.payWithEIP712@withrevert(o, sigBuyer, q, sigSeller, "", "");

    assert lastReverted;
  }

