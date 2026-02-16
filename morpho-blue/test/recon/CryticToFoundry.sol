// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";

import "forge-std/console2.sol";

import {Test} from "forge-std/Test.sol";
import {TargetFunctions} from "./TargetFunctions.sol";


// forge test --match-contract CryticToFoundry -vv
contract CryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    function setUp() public {
        setup();

        targetContract(address(this));
    }

    // forge test --match-test test_property_zeroSupplyShares_implies_zeroSupplyAssets_ -vvv 
    function test_property_zeroSupplyShares_implies_zeroSupplyAssets_() public {

        // supply(1) asset --> mints 1 000 000 shares ( 1e6 )
        morpho_supply_clamped(1);

        // withdraw(0 assets, 999 999 shares) --> burns shares, transfers 0 assets
        morpho_withdraw_burnShares();

        // withdraw(0 assets, 1 shares) --> burns shares, transfers 0 assets
        morpho_withdraw_burnShares();

        // we still have 1 asset inside and 0 shares
        property_zeroSupplyShares_implies_zeroSupplyAssets();

        // tldr of the bug - next user can be tricked into supplying more than intended if they supply via shares and have high allowance

    }

    // forge test --match-test test_crytic -vvv
    function test_crytic_borrow() public {
        morpho_supply_clamped(1e18);
        morpho_supplyCollateral_clamped(1e18);

        oracle_setPrice(1e30);

        morpho_borrow(1e6, 0, address(this), address(this));
    }

    function test_crytic_liquidate() public {
        morpho_supply_clamped(1e18);
        morpho_supplyCollateral_clamped(1e18);

        oracle_setPrice(1e30);

        morpho_borrow(1e6, 0, _getActor(), _getActor());

        oracle_setPrice(0);
        
        morpho_liquidate(_getActor(), 1e6, 0, "");
    }

    function test_crytic_repay() public {
        morpho_supply_clamped(1e18);
        morpho_supplyCollateral_clamped(1e18);

        oracle_setPrice(1e30);

        morpho_borrow(1e6, 0, _getActor(), _getActor());

        morpho_repay(1e6, 0, _getActor(), "");
    }

    function test_crytic_withdraw() public {

        morpho_supply_clamped(1e18);

        // withdraw by assets
        morpho_withdraw(1e17, 0, _getActor(), _getActor());

        // withdraw by shares
        morpho_withdraw(0, 1, _getActor(), _getActor());
    }

    // forge test --match-test test_canary_hasLiquidated_2h9i -vvv
    // function test_canary_hasLiquidated_2h9i() public {
      
    //    vm.roll(56841);
    //    vm.warp(1285285);
    //    morpho_supplyCollateral_clamped(1512536621177987977);
      
    //    vm.roll(56841);
    //    vm.warp(1285285);
    //    morpho_borrow(0, 1, 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496, 0x9BB7e7E8003393a93347AD03aa6f72078931218d);

    //    vm.roll(56841);
    //    vm.warp(1285285);
    //    oracle_setPrice(0);
      
    //    vm.roll(56841);
    //    vm.warp(1285285);

    //    morpho_liquidate_clamped(4577637173559, hex"", 0);
      
    //    vm.roll(56841);
    //    vm.warp(1285285);
    //    canary_hasLiquidated();
    // }
   		

    // forge test --match-test test_canary_hasRepaid_7133 -vvv
    // function test_canary_hasRepaid_7133() public {
    
    //     morpho_supply_clamped(1);
    
    //     morpho_supplyCollateral_clamped(2);
    
    //     morpho_borrow(1,0,0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496,0x00000000000000000000000000000000DeaDBeef);
    
    //     morpho_repay_clamped(1);
    
    //     canary_hasRepaid();
    
    // }

    function test_scenario_liquidate_when_healthy() public {
        scenario_liquidate_when_healthy(); // should not revert (liquidate reverts, we catch it)
    }

    function test_crytic_flashLoan_clamped() public {
        morpho_flashLoan_clamped(1e6);
    }

    function test_crytic_withdrawCollateral_clamped() public {
        morpho_withdrawCollateral_clamped(1e17);
    }

    function test_crytic_setFee_clamped() public {
        morpho_setFee_clamped(1);
    }

    function test_crytic_setFeeRecipient_clamped() public {
        morpho_setFeeRecipient_clamped(0);
    }

    function test_crytic_setOwner_clamped() public {
        morpho_setOwner_clamped(1);
    }

    // liduidate with bad debt
    function test_crytic_liquidate_bad_dept() public {
        morpho_supply_clamped(1);
        morpho_supplyCollateral_clamped(100);

        oracle_setPrice(1e30);
        morpho_borrow(1, 0, _getActor(), _getActor());

        oracle_setPrice(0);
        morpho_liquidate(_getActor(), 100, 0, "");
    }
}