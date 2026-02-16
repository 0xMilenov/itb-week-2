// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";
import {Id, MarketParams} from "src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "src/libraries/MarketParamsLib.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";
abstract contract DoomsdayTargets is BaseTargetFunctions, Properties {
    using MarketParamsLib for MarketParams;

    modifier stateless() {
        _;
        revert("stateless");
    }

    function doomsday_no_free_lunch(uint256 amount) public stateless {
        Id id = marketParams.id();
        (,,,, uint128 lastUpdate,) = morpho.market(id);
        if (lastUpdate == 0) return;

        amount = (amount % uint256(type(uint88).max)) + 1;
        address actor = _getActor();

        vm.prank(actor);
        (uint256 suppliedAssets, uint256 suppliedShares) =
            morpho.supply(marketParams, amount, 0, actor, hex"");

        vm.prank(actor);
        (uint256 withdrawnAssets,) = morpho.withdraw(marketParams, 0, suppliedShares, actor, actor);

        lte(withdrawnAssets, suppliedAssets, "doomsday: withdrew more than supplied (free lunch)");
    }

    function doomsday_supply_withdraw_roundtrip(uint256 amount) public stateless {
        Id id = marketParams.id();
        (,,,, uint128 lastUpdate,) = morpho.market(id);
        if (lastUpdate == 0) return;

        amount = (amount % uint256(type(uint88).max)) + 1;
        address actor = _getActor();

        vm.prank(actor);
        (uint256 suppliedAssets, uint256 suppliedShares) =
            morpho.supply(marketParams, amount, 0, actor, hex"");

        vm.prank(actor);
        (uint256 withdrawnAssets,) = morpho.withdraw(marketParams, 0, suppliedShares, actor, actor);

        gte(withdrawnAssets + 1, suppliedAssets, "doomsday: supply-withdraw roundtrip lost more than 1 wei");
    }

    function doomsday_repay_all_clears_debt() public stateless {
        Id id = marketParams.id();
        (,,,, uint128 lastUpdate,) = morpho.market(id);
        if (lastUpdate == 0) return;

        address actor = _getActor();
        (, uint128 borrowSharesBefore,) = morpho.position(id, actor);
        if (borrowSharesBefore == 0) return;

        vm.prank(actor);
        morpho.repay(marketParams, 0, borrowSharesBefore, actor, hex"");

        (, uint128 borrowSharesAfter,) = morpho.position(id, actor);
        eq(uint256(borrowSharesAfter), 0, "doomsday: repay all shares did not clear debt");
    }

    function doomsday_accrue_interest_monotonic() public stateless {
        Id id = marketParams.id();
        (uint128 tsaBefore,, uint128 tbaBefore,, uint128 lastUpdate,) = morpho.market(id);
        if (lastUpdate == 0) return;

        morpho.accrueInterest(marketParams);

        (uint128 tsaAfter,, uint128 tbaAfter,, uint128 lastUpdateAfter,) = morpho.market(id);

        gte(uint256(tsaAfter), uint256(tsaBefore), "doomsday: accrue interest decreased supply assets");
        gte(uint256(tbaAfter), uint256(tbaBefore), "doomsday: accrue interest decreased borrow assets");
        gte(uint256(lastUpdateAfter), uint256(lastUpdate), "doomsday: lastUpdate went backwards after accrue");
    }
}