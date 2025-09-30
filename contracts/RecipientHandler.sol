//SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import  "./interfaces/IDistribution.sol";
import "./libraries/Errors.sol";
import "./libraries/Constants.sol";
import "./libraries/PermitHelper.sol";

contract RecipientHandler is Pausable, Ownable, Nonces{
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using PermitHelper for *;

    struct Order{
        address buyer; //buyer's address
        address payTo; //normally pay to the SC's address first
        address paymentToken; // which one token use to pay
        uint256 totalAmount; //unit : 1 wei
        uint256 nonce; //For EIP712 Sig
        bytes32 quoteId; 
        uint128 serviceId;  //sync with the Id which in off-chain database
        uint64 deadline;//For EIP712 Sig
    }

    //Avoid Store too much data of price and cost on chain
    struct PriceQuote{
        bytes32 quoteId;   
        address paymentToken;
        address seller;
        uint256 price;       
        uint256 cost;
        uint128 serviceId;      
        uint64 expiry;      
    }
    bytes32 public constant PRICEQUOTE_TYPEHASH = keccak256(
        "PriceQuote(bytes32 quoteId,address paymentToken,address seller,uint256 price,uint256 cost,uint128 serviceId,uint64 expiry)"
    );

    bytes32 public constant ORDER_TYPEHASH = keccak256(
        "Order(address buyer, address payTo,address paymentToken, uint256 totalAmount, uint256 nonce,bytes32 quoteId, uint128 serviceId, uint64 deadline)"
    );
    mapping(address => mapping(address => uint256)) private sellersProfit; //sellet => token => profitAmount
    mapping(uint128 => bool) serviceActive;
    mapping(uint128 => address) serviceToSeller; //serviceId => Seller's address
    mapping(bytes32 => bool) public revokedQuote; // quoteId => revoked?

    uint256 private immutable _domainChainId;
    bytes32 private immutable DOMAIN_SEPARATOR;

    address public distributionSC;  // SC refers to Smart Contract

    uint256 public commissionRate;  // e.g. 1_000 = 10%
    uint256 public constant BPS = 10_000;


    /// @dev Reentrancy lock flag. Works like OpenZeppelin's ReentrancyGuard,
    uint8 private unlocked = 1; 

       

    event QuoteRevoked(address indexed seller, bytes32 indexed quoteId);
    event QuoteUnrevoked(address indexed seller, bytes32 indexed quoteId);
    event SellerClaimed(address indexed seller, address indexed token, uint256 claimAmount);
    event UserPaid(address indexed buyer, address indexed seller, uint256 totalAmount, uint128 serviceId);
    event CreatedService(address indexed seller,uint128 indexed serviceId);

    //EIP712
    function payWithEIP712(
        Order calldata order,
        bytes calldata sig,
        PriceQuote calldata quote,
        bytes calldata sellerQuoteSig,
        bytes calldata permit2612,
        bytes calldata permit2Data)
    external 
    lock
    whenNotPaused {
        uint64 deadline  = order.deadline;
        if(deadline < block.timestamp)      revert Errors.SigExpired();
        if(order.payTo != address(this))    revert Errors.NotPayTo();
        if(!serviceActive[order.serviceId]) revert Errors.InactivateService();

        if (order.quoteId != quote.quoteId)                   revert Errors.BadParas();
        if (order.serviceId != quote.serviceId)               revert Errors.BadParas();
        if (order.paymentToken != quote.paymentToken)         revert Errors.BadParas();
        if (order.totalAmount != quote.price)                 revert Errors.PriceMismatch();

        if (revokedQuote[quote.quoteId])                       revert Errors.QuoteRevoked();
        //At the same time, it was verified that the price is not 0
        if (quote.cost == 0 || quote.cost >= quote.price)     revert Errors.WrongCost();
        if (quote.expiry < block.timestamp)                   revert Errors.SigExpired();
    
       _useCheckedNonce(order.buyer, order.nonce);
       bytes32 digest= _hashTypedDataV4(keccak256(
        abi.encode(
            ORDER_TYPEHASH,
            order.buyer,
            order.payTo,
            order.paymentToken,
            order.totalAmount,
            order.nonce,
            order.quoteId,
            order.serviceId,
            order.deadline
        )));
        if(digest.recover(sig) != order.buyer){
            revert Errors.NotBuyer();
        }

        bytes32 quoteDigest = _hashTypedDataV4(keccak256(abi.encode(
            PRICEQUOTE_TYPEHASH,
            quote.quoteId,
            quote.paymentToken,
            quote.seller,
            quote.price,
            quote.cost,
            quote.serviceId,
            quote.expiry
        )));
        address recoveredSeller = quoteDigest.recover(sellerQuoteSig);
        if (recoveredSeller != quote.seller) revert Errors.NotSeller();

        address boundSeller = serviceToSeller[order.serviceId];
        if (boundSeller == address(0)) revert Errors.ServiceNotExists();
        if (recoveredSeller != boundSeller) revert Errors.NotSeller();

        bool ok = false;
        if (permit2Data.length > 0) {
            ok = PermitHelper.tryPermit2(permit2Data);
        }
        if (!ok && permit2612.length > 0) {
            ok = PermitHelper.tryPermit2612(order.paymentToken, order.buyer, address(this), permit2612);
        }
        if (!ok) {
            PermitHelper.ensureAllowanceOrRevert(order.paymentToken, order.buyer, address(this), order.totalAmount);
        }

        _settle(
        order.buyer,
        order.paymentToken,
        quote.seller,
        order.serviceId,
        quote.price,
        quote.cost
    );
    }

    function _settle(
    address buyer,
    address paymentToken,
    address seller,
    uint128 serviceId,
    uint256 amount,       // = quote.price
    uint256 cost          // = quote.cost
    ) internal {
        if(buyer == address(0) || paymentToken == address(0) || seller == address(0)){
            revert Errors.ZeroAddress();
        }
        //serviceId ,amount and cost were verified by **payWithEIP712**
        IERC20 token = IERC20(paymentToken);
        token.safeTransferFrom(buyer, address(this),amount);

        uint256 netProfit =  amount - cost;
        uint256 commission = Math.mulDiv(netProfit,  commissionRate, 10_000);
        sellersProfit[seller][paymentToken] += (amount - commission);
        if(commission > 0){
            IERC20(paymentToken).safeTransfer(distributionSC, commission);
            IDistribution(distributionSC).distribute(commission, address(0));
        }
        emit UserPaid(buyer,seller,amount,serviceId);
    }

    //Pull-payment
   function claim(address token, uint256 claimAmount)external lock{
        if(token == address(0)){
            revert Errors.ZeroAddress();
        }
        if(claimAmount == 0){
            revert Errors.ZeroAmount();
        }
        uint256 releasableAmount = sellersProfit[msg.sender][token];
        if(releasableAmount < claimAmount){
            revert Errors.InsufficientBal();
        }
        sellersProfit[msg.sender][token] -= claimAmount;
        IERC20(token).safeTransfer(msg.sender, claimAmount);
        emit SellerClaimed(msg.sender,token,claimAmount);
   }

    function _hashTypedDataV4(bytes32 structHash) internal view returns(bytes32){
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        require(chainId == _domainChainId,"Wrong Chain"); 
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR,structHash));
    }

    //Seller revokes quote
    function revokeQuote(PriceQuote calldata quote, bytes calldata sellerQuoteSig) external {
        bytes32 qd = _hashTypedDataV4(keccak256(abi.encode(
            PRICEQUOTE_TYPEHASH,
            quote.quoteId,
            quote.paymentToken,
            quote.seller,
            quote.price,
            quote.cost,
            quote.serviceId,
            quote.expiry
        )));
        require(qd.recover(sellerQuoteSig) == quote.seller, "BadQuoteSig");
        require(msg.sender == quote.seller, "NotQuoteSeller");

        revokedQuote[quote.quoteId] = true;
        emit QuoteRevoked(msg.sender, quote.quoteId);
    }

    function unrevokeQuote(PriceQuote calldata quote, bytes calldata sellerQuoteSig) external {
        bytes32 qd = _hashTypedDataV4(keccak256(abi.encode(
            PRICEQUOTE_TYPEHASH,
            quote.quoteId,
            quote.paymentToken,
            quote.seller,
            quote.price,
            quote.cost,
            quote.serviceId,
            quote.expiry
        )));
        require(qd.recover(sellerQuoteSig) == quote.seller, "BadQuoteSig");
        require(msg.sender == quote.seller, "NotQuoteSeller");

        revokedQuote[quote.quoteId] = false;
        emit QuoteUnrevoked(msg.sender, quote.quoteId);
    }


    function setServiceActive(uint128 serviceId) external{
        address serviceOwner = serviceToSeller[serviceId];
        if(msg.sender!= serviceOwner){
            revert Errors.NotSeller();
        }
        serviceActive[serviceId] = !serviceActive[serviceId];
    }

    function setCommissionRate(uint256 _commissionRate) external onlyOwner{
        if(_commissionRate == 0 || _commissionRate > BPS){
            revert Errors.BadParas();
        }
        commissionRate = _commissionRate;
    }

    function setDistributionSC(address _distributionSC) external onlyOwner{
        if(_distributionSC == address(0)){
            revert Errors.ZeroAddress();
        }
        distributionSC = _distributionSC;
    }

    function createService(uint128 serviceId, address seller) external onlyOwner{
        if(serviceToSeller[serviceId] != address(0)){
            revert Errors.DuplicatedServiceId();
        }
        if(seller == address(0)){
            revert Errors.ZeroAddress();
        }
        serviceToSeller[serviceId] = seller;
        emit CreatedService(seller, serviceId);
    }

    function nextNonce(address user) external view returns (uint256) {
        return nonces(user); //  OZ Nonces
    }


    //---------------------Modifier------------------
    /// @dev Use 1/2 instead of 0/1 to avoid expensive 0 ↔ non-0 SSTORE operations.
    ///      This ensures state changes are always non-0 ↔ non-0 (5000 gas) 
    ///      instead of 0 ↔ non-0 (21000 gas).
    modifier lock {
        require(unlocked == 1,"Locked");
        unlocked = 2;
        _;
        unlocked = 1;
    }

    //-------------------Pause---------------------
    function pause() external onlyOwner{
        _pause();
    }

    function unpause() external onlyOwner{
        _unpause();
    }
    constructor(string memory name, string memory version,address _distributionSC, uint256 _commissionRate) Ownable(msg.sender){
        uint256 chainId;
        assembly{
            chainId := chainid()
        }
        _domainChainId = chainId;
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version, uint256 chainId, address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                _domainChainId,
                address(this)
            )
        );
        if(_distributionSC == address(0)){
            revert Errors.ZeroAddress();
        }
        distributionSC = _distributionSC;
        if(_commissionRate == 0 || _commissionRate > 10_000){
            revert Errors.BadParas();
        }
        commissionRate = _commissionRate;
    }
    fallback() external payable{revert ("No ETH");}

    receive()  external payable{revert ("No ETH");}
}