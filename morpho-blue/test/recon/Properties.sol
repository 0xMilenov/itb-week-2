// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Asserts} from "@chimera/Asserts.sol";
import {BeforeAfter} from "./BeforeAfter.sol";
import {Id, MarketParams} from "src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "src/libraries/MarketParamsLib.sol";
import {IERC20} from "../../src/mocks/interfaces/IERC20.sol";
import "src/libraries/ConstantsLib.sol";

abstract contract Properties is BeforeAfter, Asserts {
  
  using MarketParamsLib for MarketParams;

  /////////////////////////////////////
  ///////// GLOBAL PROPERTIES /////////
  /////////////////////////////////////

  // property: totalBorrowAssets must never exceed totalSupplyAssets
  function property_borrowAssets_le_supplyAssets() public {
    Id id = marketParams.id(); 
    (uint128 totalSupplyAssets,, uint128 totalBorrowAssets,,,) = morpho.market(id);

    t(uint256(totalBorrowAssets) <= uint256(totalSupplyAssets), "borrow assets > supply assets");
  }

  // property: cash and borrow should cover total supply
  function property_cashPlusBorrows_gte_totalSupply() public {
    Id id = marketParams.id();
    (uint128 totalSupplyAssets,, uint128 totalBorrowAssets,,,) = morpho.market(id);

    uint256 cash = IERC20(marketParams.loanToken).balanceOf(address(morpho));
    t(cash + uint256(totalBorrowAssets) >= uint256(totalSupplyAssets), "cash + borrows < supply");
  }

  // property: if the market has zero borrow shares, it must have zero borrow assets
  function property_zeroBorrowShares_implies_zeroBorrowAssets() public {
    Id id = marketParams.id();
    (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = morpho.market(id);

    if (totalBorrowShares == 0) {
      t(totalBorrowAssets == 0, "borrow assets > 0 while borrow shares = 0");
    }
  }

  // property: if the market has zero supple shares, it must have zero supply assets
  function property_zeroSupplyShares_implies_zeroSupplyAssets() public {
    Id id = marketParams.id();
    (uint128 totalSupplyAssets, uint128 totalSupplyShares,,,,) = morpho.market(id);
    if (totalSupplyShares == 0) {
      t(totalSupplyAssets == 0, "supply assets > 0 while supply shares = 0");
    }
  }

  // property: market must stay created
  function property_marketCreated() public {
    Id id = marketParams.id();
    (,,,, uint128 lastUpdate,) = morpho.market(id);
    t(lastUpdate != 0, "market not created");
  }

  // property: id to market must mactch 
  function property_idToMarketParams_matches_setup() public {
    Id id = marketParams.id();
    (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) = morpho.idToMarketParams(id);
    t(loanToken == marketParams.loanToken, "loanToken mismatch");
    t(collateralToken == marketParams.collateralToken, "collateralToken mismatch");
    t(oracle == marketParams.oracle, "oracle mismatch");
    t(irm == marketParams.irm, "irm mismatch");
    t(lltv == marketParams.lltv, "lltv mismatch");
  }

  // property: lastUpdate is never in future
  function property_lastUpdate_le_now() public {
    Id id = marketParams.id();
    (,,,, uint128 lastUpdate,) = morpho.market(id);
    t(lastUpdate <= block.timestamp, "lastUpdate > now");
  }

  // property: fee is always bounded
  function property_fee_le_MAX_FEE() public {
    Id id = marketParams.id();
    (,,,,, uint128 fee) = morpho.market(id);
    t(uint256(fee) <= MAX_FEE, "fee > MAX_FEE");
  }

  // property: sum of known supplyShares is <= market totalSupplyShares
  function property_sum_supplyShares_le_totalSupplyShares() public {
    Id id = marketParams.id();
    (, uint128 totalSupplyShares,,,,) = morpho.market(id);

    address[] memory actors = _getActors();
    uint256 sum;
    for (uint256 i; i < actors.length; i++) {
      (uint256 supplyShares,,) = morpho.position(id, actors[i]);
      sum += supplyShares;
    }

    t(sum <= uint256(totalSupplyShares), "known supplyShares > totalSupplyShares");
  }

  // property: sum of known borrowShares is <= market totalBorrowShares
  function property_sum_borrowShares_le_totalBorrowShares() public {
    Id id = marketParams.id();
    (,,, uint128 totalBorrowShares,,) = morpho.market(id);

    address[] memory actors = _getActors();
    uint256 sum;
    for (uint256 i; i < actors.length; i++) {
      (, uint128 borrowShares,) = morpho.position(id, actors[i]);
      sum += uint256(borrowShares);
    }

    t(sum <= uint256(totalBorrowShares), "known borrowShares > totalBorrowShares");
  }

  // property: protocol holds enough collateral tokens to cover known collateral balances
  function property_collateral_balance_covers_known_collateral() public {
    Id id = marketParams.id();
    address[] memory actors = _getActors();

    uint256 sum;
    for (uint256 i; i < actors.length; i++) {
      (,, uint128 collateral) = morpho.position(id, actors[i]);
      sum += uint256(collateral);
    }

    uint256 bal = IERC20(marketParams.collateralToken).balanceOf(address(morpho));
    t(bal >= sum, "collateral token balance < known collateral");
  }

  // debugging with canaries 
  // function canary_hasRepaid() public returns (bool) {
  //   t(!hasRepaid, "hasRepaid");
  // }

  // function canary_hasLiquidated() public returns (bool) {
  //   t(!hasLiquidated, "hasLiquidated");
  // }
}