// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {CryticAsserts} from "@chimera/CryticAsserts.sol";
import {TargetFunctions} from "./TargetFunctions.sol";
import {Id, MarketParams} from "src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "src/libraries/MarketParamsLib.sol";

/// Run with `--test-mode optimization` and this contract.
contract CryticOptimizer is TargetFunctions, CryticAsserts {
    using MarketParamsLib for MarketParams;

    constructor() payable {
        setup();
    }

    function echidna_opt_assets_for_1e6_shares() public view returns (int256) {
        Id id = marketParams.id();
        (uint128 totalSupplyAssets, uint128 totalSupplyShares,,,,) = morpho.market(id);

        // SharesMathLib.toAssetsUp(shares) == shares * (totalAssets + 1) / (totalShares + 1e6), rounding up.
        uint256 shares = 1e6;
        uint256 assets = (shares * (uint256(totalSupplyAssets) + 1) + (uint256(totalSupplyShares) + 1e6) - 1)
            / (uint256(totalSupplyShares) + 1e6);

        return _toInt256Capped(assets);
    }

    function echidna_opt_unowned_assets_when_no_shares() public view returns (int256) {
        Id id = marketParams.id();
        (uint128 totalSupplyAssets, uint128 totalSupplyShares,,,,) = morpho.market(id);

        if (totalSupplyShares != 0) return 0;
        return _toInt256Capped(uint256(totalSupplyAssets));
    }

    function _toInt256Capped(uint256 x) internal pure returns (int256) {
        uint256 max = uint256(type(int256).max);
        if (x > max) return type(int256).max;
        return int256(x);
    }
}

