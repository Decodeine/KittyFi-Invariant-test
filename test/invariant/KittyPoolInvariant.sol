// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../../src/KittyPool.sol";
import "../../src/KittyVault.sol";
import "../../src/KittyCoin.sol";
import "../mocks/MockERC20.sol";
import "./utils/cheats.sol";

contract KittyPoolInvariant {
    StdCheats vm = StdCheats(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    
    KittyPool public kittyPool;
    KittyCoin public kittyCoin;
    MockERC20 public mockWETH;
    MockERC20 public mockWBTC;
    
    address public constant MEOWNTAINER = address(0x1111);
    address public constant USER1 = address(0x2222);
    address public constant USER2 = address(0x3333);
    address public constant MOCK_AAVE_POOL = address(0x4444);
    address public constant MOCK_EUR_FEED = address(0x5555);
    address public constant MOCK_ETH_FEED = address(0x6666);
    address public constant MOCK_BTC_FEED = address(0x7777);
    
    uint256 public constant INITIAL_BALANCE = 1000 * 10**18;
    
    constructor() {
        // Deploy mock tokens
        mockWETH = new MockERC20("Wrapped ETH", "WETH");
        mockWBTC = new MockERC20("Wrapped BTC", "WBTC");
        
        // Deploy KittyPool with mock feeds
        kittyPool = new KittyPool(MEOWNTAINER, MOCK_EUR_FEED, MOCK_AAVE_POOL);
        kittyCoin = KittyCoin(kittyPool.getKittyCoin());
        
        // Give users initial token balances
        mockWETH.mint(USER1, INITIAL_BALANCE);
        mockWETH.mint(USER2, INITIAL_BALANCE);
        mockWBTC.mint(USER1, INITIAL_BALANCE);
        mockWBTC.mint(USER2, INITIAL_BALANCE);
        
        // Create vaults as meowntainer
        vm.prank(MEOWNTAINER);
        kittyPool.meownufactureKittyVault(address(mockWETH), MOCK_ETH_FEED);
        vm.prank(MEOWNTAINER);
        kittyPool.meownufactureKittyVault(address(mockWBTC), MOCK_BTC_FEED);
    }
    
    // INVARIANT 1: Vault creation access control
    function property_onlyMeowntainerCanCreateVaults() public returns (bool) {
        MockERC20 newToken = new MockERC20("New Token", "NEW");
        
        // Non-meowntainer should fail to create vault
        vm.prank(USER1);
        try kittyPool.meownufactureKittyVault(address(newToken), MOCK_ETH_FEED) {
            return false; // Should have failed
        } catch {
            // Expected failure
        }
        
        // Meowntainer should succeed
        vm.prank(MEOWNTAINER);
        try kittyPool.meownufactureKittyVault(address(newToken), MOCK_ETH_FEED) {
            return true; // Should succeed
        } catch {
            return false; // Should not fail
        }
    }
    
    // INVARIANT 2: Vault mapping consistency
    function property_vaultMappingConsistency() public view returns (bool) {
        address wethVault = kittyPool.getTokenToVault(address(mockWETH));
        address wbtcVault = kittyPool.getTokenToVault(address(mockWBTC));
        
        // Both vaults should exist and be different
        return (wethVault != address(0)) && 
               (wbtcVault != address(0)) && 
               (wethVault != wbtcVault);
    }
    
    // INVARIANT 3: Deposit amounts match vault tracking
    function property_depositAmountsMatchVaultTracking() public returns (bool) {
        uint256 depositAmount = 5 * 10**18;
        address wethVaultAddr = kittyPool.getTokenToVault(address(mockWETH));
        
        if (wethVaultAddr == address(0)) return true; // Skip if no vault
        
        KittyVault wethVault = KittyVault(wethVaultAddr);
        
        // Record state before deposit
        uint256 vaultBalanceBefore = mockWETH.balanceOf(wethVaultAddr);
        uint256 totalVaultCollateralBefore = wethVault.totalMeowllateralInVault();
        uint256 userSharesBefore = wethVault.userToCattyNip(USER1);
        
        // User deposits
        vm.prank(USER1);
        mockWETH.approve(wethVaultAddr, depositAmount);
        vm.prank(USER1);
        kittyPool.depawsitMeowllateral(address(mockWETH), depositAmount);
        
        // Check state after deposit
        uint256 vaultBalanceAfter = mockWETH.balanceOf(wethVaultAddr);
        uint256 totalVaultCollateralAfter = wethVault.totalMeowllateralInVault();
        uint256 userSharesAfter = wethVault.userToCattyNip(USER1);
        
        // Verify consistency
        bool balanceIncreased = (vaultBalanceAfter == vaultBalanceBefore + depositAmount);
        bool totalIncreased = (totalVaultCollateralAfter == totalVaultCollateralBefore + depositAmount);
        bool sharesIncreased = (userSharesAfter == userSharesBefore + depositAmount);
        
        return balanceIncreased && totalIncreased && sharesIncreased;
    }
    
    // INVARIANT 4: KittyCoin minting only through pool
    function property_kittyCoinMintingOnlyThroughPool() public returns (bool) {
        uint256 supplyBefore = kittyCoin.totalSupply();
        
        // Direct mint should fail
        vm.prank(USER1);
        try kittyCoin.mint(USER1, 100) {
            return false; // Should have failed
        } catch {
            // Expected failure
        }
        
        // Supply should be unchanged
        return kittyCoin.totalSupply() == supplyBefore;
    }
    
    // INVARIANT 5: Total collateral >= total debt (simplified)
    function property_protocolSolvency() public view returns (bool) {
        // This is a simplified check - in reality we'd need price feeds
        // to convert collateral values to EUR for proper comparison
        
        uint256 totalSupply = kittyCoin.totalSupply();
        
        // Get vault addresses
        address wethVaultAddr = kittyPool.getTokenToVault(address(mockWETH));
        address wbtcVaultAddr = kittyPool.getTokenToVault(address(mockWBTC));
        
        uint256 totalCollateral = 0;
        
        if (wethVaultAddr != address(0)) {
            totalCollateral += mockWETH.balanceOf(wethVaultAddr);
        }
        
        if (wbtcVaultAddr != address(0)) {
            totalCollateral += mockWBTC.balanceOf(wbtcVaultAddr);
        }
        
        // Simplified check: assume 1:1 ratio for this invariant
        // In reality, we'd need proper price conversion
        return totalCollateral > 0 ? totalSupply <= totalCollateral : totalSupply == 0;
    }
    
    // Helper function for deposits
    function makeDeposit(uint256 userIndex, uint256 tokenIndex, uint256 amount) external {
        userIndex = userIndex % 2; // USER1 or USER2
        tokenIndex = tokenIndex % 2; // WETH or WBTC
        amount = amount % (100 * 10**18); // Limit amount
        
        if (amount == 0) return;
        
        address user = userIndex == 0 ? USER1 : USER2;
        MockERC20 token = tokenIndex == 0 ? mockWETH : mockWBTC;
        address vaultAddr = kittyPool.getTokenToVault(address(token));
        
        if (vaultAddr == address(0)) return; // No vault
        if (token.balanceOf(user) < amount) return; // Insufficient balance
        
        vm.prank(user);
        token.approve(vaultAddr, amount);
        vm.prank(user);
        kittyPool.depawsitMeowllateral(address(token), amount);
    }
}
