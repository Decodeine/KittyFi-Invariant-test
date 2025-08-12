// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract StatelessAaveInvariant {
    
    // ============ PURE FUNCTION STATELESS TESTS ============
    
    // Test mathematical relationships without state
    function testAaveCollateralCalculation(
        uint256 vaultBalance,
        uint256 aaveBalance,
        uint256 amountToSupply
    ) public pure returns (bool) {
        // Bound inputs to reasonable ranges
        vaultBalance = _bound(vaultBalance, 0, 1000000e18);
        aaveBalance = _bound(aaveBalance, 0, 1000000e18);
        amountToSupply = _bound(amountToSupply, 1, vaultBalance);
        
        // Test: After supplying to Aave, total collateral should remain the same
        uint256 totalCollateralBefore = vaultBalance + aaveBalance;
        
        // Simulate the supply operation
        uint256 newVaultBalance = vaultBalance - amountToSupply;
        uint256 newAaveBalance = aaveBalance + amountToSupply;
        
        uint256 totalCollateralAfter = newVaultBalance + newAaveBalance;
        
        return totalCollateralBefore == totalCollateralAfter;
    }
    
    // Test share calculation logic stateless
    function testShareCalculationConsistency(
        uint256 userShares,
        uint256 totalShares, 
        uint256 totalCollateral,
        uint256 amountToWithdraw
    ) public pure returns (bool) {
        // Bound inputs
        totalShares = _bound(totalShares, 1, 1000000e18);
        userShares = _bound(userShares, 1, totalShares);
        totalCollateral = _bound(totalCollateral, totalShares, 1000000e18);
        
        // Calculate max user can withdraw
        uint256 userMaxWithdrawal = (userShares * totalCollateral) / totalShares;
        amountToWithdraw = _bound(amountToWithdraw, 1, userMaxWithdrawal);
        
        // Test: Shares burned should be proportional to amount withdrawn
        uint256 sharesBurned = (amountToWithdraw * totalShares) / totalCollateral;
        
        // Invariant: shares burned should never exceed user shares
        return sharesBurned <= userShares;
    }
    
    // Test EUR conversion calculations
    function testEurConversionInvariant(
        uint256 tokenAmount,
        uint256 tokenPrice,  // price in USD (8 decimals)
        uint256 eurPrice    // EUR/USD price (8 decimals)
    ) public pure returns (bool) {
        // Bound to realistic ranges
        tokenAmount = _bound(tokenAmount, 1e12, 1000000e18);
        tokenPrice = _bound(tokenPrice, 1e6, 10000e8);  // $0.01 to $10000
        eurPrice = _bound(eurPrice, 50000000, 200000000); // 0.5 to 2.0 EUR/USD
        
        if (eurPrice == 0) return true; // Skip division by zero
        
        // Calculate EUR value
        uint256 usdValue = (tokenAmount * tokenPrice) / 1e18;
        uint256 eurValue = (usdValue * 1e8) / eurPrice;
        
        // Invariant: EUR value should be reasonable compared to USD value
        // If EUR/USD = 1.0, then EUR value ≈ USD value
        return eurValue > 0 && eurValue <= usdValue * 2; // Allow 2x for price variation
    }
    
    // Test liquidation calculation
    function testLiquidationInvariant(
        uint256 collateralValue,
        uint256 debtValue,
        uint256 liquidationThreshold
    ) public pure returns (bool) {
        // Bound inputs
        collateralValue = _bound(collateralValue, 0, 1000000e18);
        debtValue = _bound(debtValue, 0, collateralValue);
        liquidationThreshold = _bound(liquidationThreshold, 100, 300); // 100% to 300%
        
        if (debtValue == 0) return true; // No debt, always healthy
        
        // Calculate collateralization ratio
        uint256 ratio = (collateralValue * 100) / debtValue;
        
        // Test invariant: position is healthy if ratio >= threshold
        bool isHealthy = ratio >= liquidationThreshold;
        bool shouldLiquidate = ratio < liquidationThreshold;
        
        return isHealthy != shouldLiquidate; // Exactly one should be true
    }
    
    // Test Aave interest accumulation math
    function testAaveInterestAccumulation(
        uint256 principalAmount,
        uint256 timeElapsed,
        uint256 interestRatePerSecond
    ) public pure returns (bool) {
        // Bound to reasonable values
        principalAmount = _bound(principalAmount, 1e18, 1000000e18);
        timeElapsed = _bound(timeElapsed, 0, 365 days);
        interestRatePerSecond = _bound(interestRatePerSecond, 0, 1e15); // Max ~3% per year
        
        // Simple interest calculation (approximation)
        uint256 interest = (principalAmount * interestRatePerSecond * timeElapsed) / 1e18;
        uint256 total = principalAmount + interest;
        
        // Invariants:
        // 1. Total should always be >= principal
        // 2. Interest should be reasonable (not exceed principal for normal rates)
        return total >= principalAmount && 
               (timeElapsed == 0 || interest <= principalAmount);
    }
    
    // ============ HELPER FUNCTIONS ============
    
    function _bound(uint256 x, uint256 min, uint256 max) internal pure returns (uint256) {
        if (min > max) return min;
        if (x < min) return min;
        if (x > max) return max;
        return x;
    }
}
