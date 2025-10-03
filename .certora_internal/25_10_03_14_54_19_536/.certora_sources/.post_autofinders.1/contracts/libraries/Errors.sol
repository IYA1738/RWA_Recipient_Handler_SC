//SPDX-License-Identifier:MIT
pragma solidity  ^0.8.20;

library Errors {
    error InsufficientBal();
    error InAuthorized();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidSig();
    error NotBuyer();
    error BadParas();
    error NotSeller();
    error NotPayTo();
    error SigExpired();
    error ServiceNotExists();
    error InvalidPayAmount();
    error DuplicatedNonce();
    error DuplicatedServiceId();
    error WrongCost();
    error Reused();
    error InactivateService();
    error QuoteRevoked();
    error PriceMismatch();
} 