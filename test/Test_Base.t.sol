//SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;
import {Test} from "lib/forge-std/src/Test.sol";
import {RecipientHandler} from "contracts/RecipientHandler.sol";
import {MockDistribution} from "test/Mocks/MockDistribution.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Test_Base is Test{
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public owner = address(0x123abc);
    uint256 sellerPk  =  123;
    uint256 buyerPk = 456;
    address seller;
    address buyer;
    string constant NAME = "Test";
    string constant VERSION = "1";

    uint128 serviceId = uint128(uint256(keccak256(abi.encode(block.timestamp, block.number, msg.sender))));
    uint256 commissionRate = 1000; // 10%
    uint256 price = 1_000e6; // 1000 USDC
    uint256 cost = 100e6; // 100  USDC

    bytes32 quoteId;
    uint64 nowTime;

    uint256 forkId;

    RecipientHandler handler;
    MockDistribution distribution;
    uint256 public constant BPS = 10_000;

    // typehash
    bytes32 constant ORDER_TYPEHASH =
        keccak256(
            "Order(address buyer, address payTo,address paymentToken, uint256 totalAmount, uint256 nonce,bytes32 quoteId, uint128 serviceId, uint64 deadline)"
        );
    bytes32 constant PRICEQUOTE_TYPEHASH =
        keccak256(
            "PriceQuote(bytes32 quoteId,address paymentToken,address seller,uint256 price,uint256 cost,uint128 serviceId,uint64 expiry)"
        );

    bytes32 constant EIP712_DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version, uint256 chainId, address verifyingContract)"
        );

    function domainSeparatorLocal() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN_TYPEHASH,
                    keccak256(bytes("Test")), 
                    keccak256(bytes("1")), 
                    8453, //Base mainnet
                    address(handler) 
                )
            );
    }

    function hashTyped(bytes32 structHash) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19\x01", domainSeparatorLocal(), structHash)
            );
    }

    function sign(
        bytes32 digest,
        uint256 pk
    ) internal pure returns (bytes memory sig) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        sig = abi.encodePacked(r, s, v);
    }
    function setUp() public virtual{
        forkId = vm.createSelectFork(
            "https://base-mainnet.infura.io/v3/c8b8880b688449e098c268f568bf7700"
        );
        //Generate address 
        buyer = vm.addr(buyerPk);
        seller = vm.addr(sellerPk);

        vm.startPrank(owner);
        distribution = new MockDistribution();
        handler = new RecipientHandler("Test", "1", address(distribution), 1_000);
        handler.createService(serviceId, seller);
        vm.stopPrank();

        vm.prank(seller);
        handler.setServiceActive(serviceId);
        deal(USDC, buyer, 100_000e6);
        deal(USDC, address(handler), 100_000e6);
        vm.startPrank(buyer);
        IERC20(USDC).approve(address(handler), type(uint256).max);
        vm.stopPrank();
        vm.deal(buyer, 100 ether);
        vm.deal(seller, 100 ether);

        nowTime = uint64(block.timestamp);
        quoteId = keccak256("q-1");
    }
}