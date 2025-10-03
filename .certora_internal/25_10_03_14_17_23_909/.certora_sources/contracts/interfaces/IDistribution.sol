// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

/// @title IDistribution
/// @notice Interface for the Distribution contract (USDC commission split + BBB + Fireblock)
interface IDistribution {
    // -------- Events --------
    /// @dev Emitted after a successful distribute() call
    event DistributionExecuted(
        uint256 usdcAmountIn,
        uint256 commission,
        uint256 bbbAmount,
        uint256 fireBlockAmount
    );

    // -------- Read-only getters (match public state vars) --------
    function usdc() external view returns (address);
    function fireBlockWallet() external view returns (address);
    function bbbContract() external view returns (address);

    function commissionRate() external view returns (uint256); // denominator 10_000
    function bbbRate() external view returns (uint256);        // denominator 10_000
    function fireBlockRate() external view returns (uint256);  // denominator 10_000

    // -------- External methods --------
    /// @notice Distribute commission from the given USDC amount
    /// @param usdcAmountIn Total USDC amount used to compute commission
    function distribute(uint256 usdcAmountIn, address contactPerson) external;

    /// @notice Update destination wallet for Fireblocks
    function updateFireBlockWallet(address _newFireBlockWallet) external;

    /// @notice Update BBB (BuyBackBurn) contract address
    function updateBbbContract(address _newBbbContract) external;

    /// @notice Update commission rate (denominator 10_000)
    function updateCommissionRate(uint256 _newRate) external;

    /// @notice Update BBB rate (denominator 10_000)
    function updateBbbRate(uint256 _newRate) external;

    /// @notice Update Fireblocks rate (denominator 10_000)
    function updateFireBlockRate(uint256 _newRate) external;

    /// @notice Withdraw any USDC held by this contract to owner
    function emergencyWithdraw() external;
}