// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Asserts} from "@chimera/Asserts.sol";
import {BeforeAfter} from "./BeforeAfter.sol";
import {Id, MarketParams} from "src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "src/libraries/MarketParamsLib.sol";
import {MathLib} from "src/libraries/MathLib.sol";
import {SharesMathLib} from "src/libraries/SharesMathLib.sol";
import {MockERC20} from "@recon/MockERC20.sol";
import {IOracle} from "src/interfaces/IOracle.sol";
import "src/libraries/ConstantsLib.sol";

abstract contract Properties is BeforeAfter, Asserts {
    using MarketParamsLib for MarketParams;
    using MathLib for uint256;
    using SharesMathLib for uint256;

    /////////////////////////////////////
    ///////// GLOBAL PROPERTIES /////////
    /////////////////////////////////////

    function property_borrowAssets_le_supplyAssets() public {
        for (uint256 i; i < _createdMarkets.length; i++) {
            Id id = _createdMarkets[i].id();
            (uint128 totalSupplyAssets,, uint128 totalBorrowAssets,,,) = morpho.market(id);
            lte(uint256(totalBorrowAssets), uint256(totalSupplyAssets), "borrow assets > supply assets");
        }
    }

    function property_zeroBorrowShares_implies_zeroBorrowAssets() public {
        for (uint256 i; i < _createdMarkets.length; i++) {
            Id id = _createdMarkets[i].id();
            (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = morpho.market(id);
            if (totalBorrowShares == 0) {
                eq(uint256(totalBorrowAssets), 0, "borrow assets > 0 while borrow shares = 0");
            }
        }
    }

    // property: if the market has zero supple shares, it must have zero supply assets
    // supply(1), withdraw(999 999 shares), withdraw(1 share) will break this property
    function property_zeroSupplyShares_implies_zeroSupplyAssets() public {
        for (uint256 i; i < _createdMarkets.length; i++) {
            Id id = _createdMarkets[i].id();
            (uint128 totalSupplyAssets, uint128 totalSupplyShares,,,,) = morpho.market(id);
            if (totalSupplyShares == 0) {
                eq(uint256(totalSupplyAssets), 0, "supply assets > 0 while supply shares = 0");
            }
        }
    }

    function property_marketCreated() public {
        for (uint256 i; i < _createdMarkets.length; i++) {
            Id id = _createdMarkets[i].id();
            (,,,, uint128 lastUpdate,) = morpho.market(id);
            t(lastUpdate != 0, "market not created");
        }
    }

    function property_idToMarketParams_recomputes_id() public {
        for (uint256 i; i < _createdMarkets.length; i++) {
            Id id = _createdMarkets[i].id();
            (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) =
                morpho.idToMarketParams(id);
            MarketParams memory mp =
                MarketParams({loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: lltv});
            t(Id.unwrap(mp.id()) == Id.unwrap(id), "id mismatch");
        }
    }

    function property_lastUpdate_le_now() public {
        for (uint256 i; i < _createdMarkets.length; i++) {
            Id id = _createdMarkets[i].id();
            (,,,, uint128 lastUpdate,) = morpho.market(id);
            lte(uint256(lastUpdate), block.timestamp, "lastUpdate > now");
        }
    }

    function property_fee_le_MAX_FEE() public {
        for (uint256 i; i < _createdMarkets.length; i++) {
            Id id = _createdMarkets[i].id();
            (,,,,, uint128 fee) = morpho.market(id);
            lte(uint256(fee), MAX_FEE, "fee > MAX_FEE");
        }
    }

    function property_sum_supplyShares_le_totalSupplyShares() public {
        for (uint256 i; i < _createdMarkets.length; i++) {
            Id id = _createdMarkets[i].id();
            (, uint128 totalSupplyShares,,,,) = morpho.market(id);
            address[] memory actors = _getActors();
            uint256 sum;
            for (uint256 j; j < actors.length; j++) {
                (uint256 supplyShares,,) = morpho.position(id, actors[j]);
                sum += supplyShares;
            }
            lte(sum, uint256(totalSupplyShares), "known supplyShares > totalSupplyShares");
        }
    }

    function property_sum_borrowShares_le_totalBorrowShares() public {
        for (uint256 i; i < _createdMarkets.length; i++) {
            Id id = _createdMarkets[i].id();
            (,,, uint128 totalBorrowShares,,) = morpho.market(id);
            address[] memory actors = _getActors();
            uint256 sum;
            for (uint256 j; j < actors.length; j++) {
                (, uint128 borrowShares,) = morpho.position(id, actors[j]);
                sum += uint256(borrowShares);
            }
            lte(sum, uint256(totalBorrowShares), "known borrowShares > totalBorrowShares");
        }
    }

    function invariant_loan_token_balance_matches() public {
        if (_createdMarkets.length != 1) return; // shared tokens across markets break per-market check
        Id id = _createdMarkets[0].id();
        (uint128 totalSupplyAssets,, uint128 totalBorrowAssets,, uint128 lastUpdate,) = morpho.market(id);
        if (lastUpdate == 0) return;
        MarketParams memory mp = _createdMarkets[0];
        uint256 balance = MockERC20(mp.loanToken).balanceOf(address(morpho));
        gte(balance + uint256(totalBorrowAssets), uint256(totalSupplyAssets), "market: loan accounting deficit");
    }

    function invariant_collateral_balance_sufficient() public {
        if (_createdMarkets.length != 1) return; // shared tokens across markets break per-market check
        Id id = _createdMarkets[0].id();
        (,,,, uint128 lastUpdate,) = morpho.market(id);
        if (lastUpdate == 0) return;
        MarketParams memory mp = _createdMarkets[0];
        address[] memory actors = _getActors();
        uint256 sumCollateral;
        for (uint256 j; j < actors.length; j++) {
            (,, uint128 c) = morpho.position(id, actors[j]);
            sumCollateral += uint256(c);
        }
        uint256 balance = MockERC20(mp.collateralToken).balanceOf(address(morpho));
        gte(balance, sumCollateral, "market: collateral token balance deficit");
    }

    function invariant_market_params_persisted() public {
        for (uint256 i; i < _createdMarkets.length; i++) {
            Id id = _createdMarkets[i].id();
            (,,,, uint128 lastUpdate,) = morpho.market(id);
            if (lastUpdate == 0) continue;
            (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) =
                morpho.idToMarketParams(id);
            MarketParams memory mp = _createdMarkets[i];
            eq(uint256(uint160(loanToken)), uint256(uint160(mp.loanToken)), "market: loan token mismatch");
            eq(uint256(uint160(collateralToken)), uint256(uint160(mp.collateralToken)), "market: collateral token mismatch");
            eq(uint256(uint160(oracle)), uint256(uint160(mp.oracle)), "market: oracle mismatch");
            eq(uint256(uint160(irm)), uint256(uint160(mp.irm)), "market: irm mismatch");
            eq(lltv, mp.lltv, "market: lltv mismatch");
        }
    }

    function invariant_supply_shares_equal_total_all_markets() public {
        address[] memory actors = _getActors();
        for (uint256 m; m < _createdMarkets.length; m++) {
            MarketParams memory mp = _createdMarkets[m];
            Id id = mp.id();
            (, uint128 totalSupplyShares,,, uint128 lastUpdate, uint128 fee) = morpho.market(id);
            if (lastUpdate == 0) continue;
            if (fee != 0) continue; // fee recipient accrued shares not in position.supplyShares
            uint256 sumSupplyShares;
            for (uint256 i; i < actors.length; i++) {
                (uint256 ss,,) = morpho.position(id, actors[i]);
                sumSupplyShares += ss;
            }
            address feeRecipient = morpho.feeRecipient();
            if (feeRecipient != address(0)) {
                bool feeRecipientIsActor;
                for (uint256 i; i < actors.length; i++) {
                    if (actors[i] == feeRecipient) {
                        feeRecipientIsActor = true;
                        break;
                    }
                }
                if (!feeRecipientIsActor) {
                    (uint256 feeRecipientShares,,) = morpho.position(id, feeRecipient);
                    sumSupplyShares += feeRecipientShares;
                }
            }
            eq(sumSupplyShares, uint256(totalSupplyShares), "market: sum of supply shares mismatch");
        }
    }

    function invariant_borrow_shares_equal_total_all_markets() public {
        address[] memory actors = _getActors();
        for (uint256 m; m < _createdMarkets.length; m++) {
            MarketParams memory mp = _createdMarkets[m];
            Id id = mp.id();
            (,,, uint128 totalBorrowShares, uint128 lastUpdate,) = morpho.market(id);
            if (lastUpdate == 0) continue;
            uint256 sumBorrowShares;
            for (uint256 i; i < actors.length; i++) {
                (, uint128 bs,) = morpho.position(id, actors[i]);
                sumBorrowShares += uint256(bs);
            }
            eq(sumBorrowShares, uint256(totalBorrowShares), "market: sum of borrow shares mismatch");
        }
    }

    function invariant_bad_debt_no_borrow_without_collateral_all_markets() public {
        address[] memory actors = _getActors();
        for (uint256 m; m < _createdMarkets.length; m++) {
            Id id = _createdMarkets[m].id();
            (,,,, uint128 lastUpdate,) = morpho.market(id);
            if (lastUpdate == 0) continue;
            for (uint256 i; i < actors.length; i++) {
                (, uint128 borrowShares, uint128 collateral) = morpho.position(id, actors[i]);
                if (collateral == 0) {
                    eq(uint256(borrowShares), 0, "market: borrow shares without collateral");
                }
            }
        }
    }

    function invariant_healthy_positions_at_baseline_price_all_markets() public {
        address[] memory actors = _getActors();
        for (uint256 m; m < _createdMarkets.length; m++) {
            MarketParams memory mp = _createdMarkets[m];
            Id id = mp.id();
            (,,,, uint128 lastUpdate,) = morpho.market(id);
            if (lastUpdate == 0) continue;
            uint256 price = IOracle(mp.oracle).price();
            if (price != ORACLE_PRICE_SCALE) continue;
            for (uint256 i; i < actors.length; i++) {
                address actor = actors[i];
                (, uint128 borrowShares, uint128 collateral) = morpho.position(id, actor);
                if (borrowShares == 0) continue;
                (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = morpho.market(id);
                uint256 maxBorrow =
                    uint256(collateral).mulDivDown(price, ORACLE_PRICE_SCALE).wMulDown(mp.lltv);
                uint256 borrowedAssets =
                    uint256(borrowShares).toAssetsUp(totalBorrowAssets, totalBorrowShares);
                gte(maxBorrow, borrowedAssets, "market: unhealthy position at baseline price");
            }
        }
    }

    /////////////////////////////////////
    ///////// INLINED PROPERTIES ////////
    /////////////////////////////////////

    function invariant_supply_shares_grow_together() public {
        if (_after.supplyShares > _before.supplyShares) {
            gt(_after.totalSupplyShares, _before.totalSupplyShares, "inlined: position supply shares grew but total didn't");
        }
    }

    function invariant_supply_shares_shrink_together() public {
        if (_after.supplyShares < _before.supplyShares) {
            lt(_after.totalSupplyShares, _before.totalSupplyShares, "inlined: position supply shares shrank but total didn't");
        }
    }

    function invariant_borrow_shares_grow_together() public {
        if (_after.borrowShares > _before.borrowShares) {
            gt(_after.totalBorrowShares, _before.totalBorrowShares, "inlined: position borrow shares grew but total didn't");
        }
    }

    function invariant_borrow_shares_shrink_together() public {
        if (_after.borrowShares < _before.borrowShares) {
            lt(_after.totalBorrowShares, _before.totalBorrowShares, "inlined: position borrow shares shrank but total didn't");
        }
    }

    function invariant_lastUpdate_monotonic() public {
        gte(_after.lastUpdate, _before.lastUpdate, "inlined: lastUpdate decreased");
    }

    function invariant_collateral_deposit_reflected_in_balance() public {
        if (_after.collateral > _before.collateral) {
            gt(_after.morphoCollateralBalance, _before.morphoCollateralBalance, "inlined: collateral grew but morpho balance didn't");
        }
    }

    function invariant_collateral_withdraw_reflected_in_balance() public {
        if (_after.collateral < _before.collateral) {
            lt(_after.morphoCollateralBalance, _before.morphoCollateralBalance, "inlined: collateral shrank but morpho balance didn't");
        }
    }
}
