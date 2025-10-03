// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library PermitHelper {
    using SafeERC20 for IERC20;

    // EIP-2612 standard: permit(address owner,address spender,uint256 value,uint256 deadline,uint8 v,bytes32 r,bytes32 s)
    bytes4 constant PERMIT2612_SEL = 0xd505accf;

    // DAI style: permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed,uint8 v,bytes32 r,bytes32 s)
    bytes4 constant DAI_PERMIT_SEL = 0x8fcbaf0c;

    // Uniswap Permit2 fixed address (example)
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    /// @notice Try EIP-2612 or DAI permit calldata. Return true if permit succeeded.
    function tryPermit2612(address token, address _owner, address _spender, bytes calldata permitData)
        internal
        returns (bool)
    {
        if (permitData.length < 4) return false;

        bytes4 selector;
        assembly {
            // calldata pointer to first 4 bytes of permitData
            selector := calldataload(permitData.offset)
        }

        if (selector == PERMIT2612_SEL) {
            // decode after selector
            (address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
                = abi.decode(permitData[4:], (address, address, uint256, uint256, uint8, bytes32, bytes32));
            if (owner != _owner || spender != _spender) return false;

            (bool ok, bytes memory ret) = token.call(abi.encodeWithSelector(
                selector, owner, spender, value, deadline, v, r, s
            ));
            if (!ok) return false;
            // if returned data present and is bool, decode it
            if (ret.length == 0) return true;
            return abi.decode(ret, (bool));
        } else if (selector == DAI_PERMIT_SEL) {
            (address holder, address spender, uint256 nonce, uint256 expiry, bool allowed, uint8 v, bytes32 r, bytes32 s)
                = abi.decode(permitData[4:], (address, address, uint256, uint256, bool, uint8, bytes32, bytes32));
            if (holder != _owner || spender != _spender) return false;

            (bool ok, bytes memory ret) = token.call(abi.encodeWithSelector(
                selector, holder, spender, nonce, expiry, allowed, v, r, s
            ));
            if (!ok) return false;
            if (ret.length == 0) return true;
            return abi.decode(ret, (bool));
        } else {
            return false;
        }
    }

    /// @notice Try Uniswap Permit2 Returns whether call succeeded.
    function tryPermit2(bytes calldata permit2Data) internal returns (bool ok) {
        if (permit2Data.length == 0) return false;
        (ok, ) = PERMIT2.call(permit2Data);
    }

    /// @dev convenience: ensure allowance or revert
    function ensureAllowanceOrRevert(address token, address owner, address spender, uint256 need) internal view {
        require(IERC20(token).allowance(owner, spender) >= need, "ALLOWANCE_MISSING");
    }
}
