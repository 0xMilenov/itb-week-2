// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Setup} from "./Setup.sol";
import {Id, MarketParams} from "src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "src/libraries/MarketParamsLib.sol";
import {MockERC20} from "@recon/MockERC20.sol";

// ghost variables for tracking state variable values before and after function calls
abstract contract BeforeAfter is Setup {
    using MarketParamsLib for MarketParams;

    struct Vars {
        // Market-level state
        uint256 totalSupplyAssets;
        uint256 totalSupplyShares;
        uint256 totalBorrowAssets;
        uint256 totalBorrowShares;
        uint256 lastUpdate;
        uint256 fee;
        // Position-level state (current actor)
        uint256 supplyShares;
        uint256 borrowShares;
        uint256 collateral;
        // Token balances
        uint256 morphoLoanBalance;
        uint256 morphoCollateralBalance;
        uint256 actorLoanBalance;
        uint256 actorCollateralBalance;
    }

    Vars internal _before;
    Vars internal _after;

    modifier updateGhosts {
        __before();
        _;
        __after();
    }

    function __before() internal {
        if (_createdMarkets.length == 0) return;
        Id id = marketParams.id();

        (uint128 tsa, uint128 tss, uint128 tba, uint128 tbs, uint128 lu, uint128 f) = morpho.market(id);
        _before.totalSupplyAssets = uint256(tsa);
        _before.totalSupplyShares = uint256(tss);
        _before.totalBorrowAssets = uint256(tba);
        _before.totalBorrowShares = uint256(tbs);
        _before.lastUpdate = uint256(lu);
        _before.fee = uint256(f);

        address actor = _getActor();
        (uint256 ss, uint128 bs, uint128 c) = morpho.position(id, actor);
        _before.supplyShares = ss;
        _before.borrowShares = uint256(bs);
        _before.collateral = uint256(c);

        _before.morphoLoanBalance = MockERC20(marketParams.loanToken).balanceOf(address(morpho));
        _before.morphoCollateralBalance = MockERC20(marketParams.collateralToken).balanceOf(address(morpho));
        _before.actorLoanBalance = MockERC20(marketParams.loanToken).balanceOf(actor);
        _before.actorCollateralBalance = MockERC20(marketParams.collateralToken).balanceOf(actor);
    }

    function __after() internal {
        if (_createdMarkets.length == 0) return;
        Id id = marketParams.id();

        (uint128 tsa, uint128 tss, uint128 tba, uint128 tbs, uint128 lu, uint128 f) = morpho.market(id);
        _after.totalSupplyAssets = uint256(tsa);
        _after.totalSupplyShares = uint256(tss);
        _after.totalBorrowAssets = uint256(tba);
        _after.totalBorrowShares = uint256(tbs);
        _after.lastUpdate = uint256(lu);
        _after.fee = uint256(f);

        address actor = _getActor();
        (uint256 ss, uint128 bs, uint128 c) = morpho.position(id, actor);
        _after.supplyShares = ss;
        _after.borrowShares = uint256(bs);
        _after.collateral = uint256(c);

        _after.morphoLoanBalance = MockERC20(marketParams.loanToken).balanceOf(address(morpho));
        _after.morphoCollateralBalance = MockERC20(marketParams.collateralToken).balanceOf(address(morpho));
        _after.actorLoanBalance = MockERC20(marketParams.loanToken).balanceOf(actor);
        _after.actorCollateralBalance = MockERC20(marketParams.collateralToken).balanceOf(actor);
    }
}
