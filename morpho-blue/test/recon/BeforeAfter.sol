// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Setup} from "./Setup.sol";
import {Id, MarketParams} from "src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "src/libraries/MarketParamsLib.sol";

// ghost variables for tracking state variable values before and after function calls
abstract contract BeforeAfter is Setup {
    using MarketParamsLib for MarketParams;
    struct Vars {
        uint256 totalSupplyAssets;
        uint256 totalBorrowAssets;
        uint256 __ignore__;
    }

    Vars internal _before;
    Vars internal _after;

    modifier updateGhosts {
        __before();
        _;
        __after();
    }

    function __before() internal {
        if (trackedMarketIds.length == 0) return;
        Id id = marketParams.id();
        (uint128 supply,, uint128 borrow,,,) = morpho.market(id);
        _before.totalSupplyAssets = supply;
        _before.totalBorrowAssets = borrow;
    }

    function __after() internal {
        if (trackedMarketIds.length == 0) return;
        Id id = marketParams.id();
        (uint128 supply,, uint128 borrow,,,) = morpho.market(id);
        _after.totalSupplyAssets = supply;
        _after.totalBorrowAssets = borrow;
    }
}