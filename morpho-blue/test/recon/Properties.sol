// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Asserts} from "@chimera/Asserts.sol";
import {BeforeAfter} from "./BeforeAfter.sol";
import {Id, MarketParams} from "src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "src/libraries/MarketParamsLib.sol";
import {IERC20} from "../../src/mocks/interfaces/IERC20.sol";

abstract contract Properties is BeforeAfter, Asserts {
  
  using MarketParamsLib for MarketParams;

  /////////////////////////////////////
  ///////// GLOBAL PROPERTIES /////////
  /////////////////////////////////////

  // property: totalBorrowAssets must never exceed totalSupplyAssets
  function invariant_borrowAssets_le_supplyAssets() public {
    Id id = marketParams.id(); 
    (uint128 totalSupplyAssets,, uint128 totalBorrowAssets,,,) = morpho.market(id);

    t(uint256(totalBorrowAssets) <= uint256(totalSupplyAssets), "borrow assets > supply assets");
  }

  // property: cash and borrow should cover total supply
  // if we have more then 1 market with the same loan token this will break!
  // if we add add 'dynamic market' we should comment it.
  function invariant_cashPlusBorrows_gte_totalSupply() public {
    Id id = marketParams.id();
    (uint128 totalSupplyAssets,, uint128 totalBorrowAssets,,,) = morpho.market(id);

    uint256 cash = IERC20(marketParams.loanToken).balanceOf(address(morpho));
    t(cash + uint256(totalBorrowAssets) >= uint256(totalSupplyAssets), "cash + borrows < supply");
  }

  // property: if the market has zero borrow shares, it must have zero borrow assets
  function invariant_zeroBorrowShares_implies_zeroBorrowAssets() public {
    Id id = marketParams.id();
    (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = morpho.market(id);

    if (totalBorrowShares == 0) {
      t(totalBorrowAssets == 0, "borrow assets > 0 while borrow shares = 0");
    }
  }

  // property: if the market has zero supple shares, it must have zero supply assets
  function invariant_zeroSupplyShares_implies_zeroSupplyAssets() public {
    Id id = marketParams.id();
    (uint128 totalSupplyAssets, uint128 totalSupplyShares,,,,) = morpho.market(id);
    if (totalSupplyShares == 0) {
      t(totalSupplyAssets == 0, "supply assets > 0 while supply shares = 0");
    }
  }

  // property: market must stay created
  function invariant_marketCreated() public {
    Id id = marketParams.id();
    (,,,, uint128 lastUpdate,) = morpho.market(id);
    t(lastUpdate != 0, "market not created");
  }

  // property: id to market must mactch 
  function invariant_idToMarketParams_matches_setup() public {
    Id id = marketParams.id();
    (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) = morpho.idToMarketParams(id);
    t(loanToken == marketParams.loanToken, "loanToken mismatch");
    t(collateralToken == marketParams.collateralToken, "collateralToken mismatch");
    t(oracle == marketParams.oracle, "oracle mismatch");
    t(irm == marketParams.irm, "irm mismatch");
    t(lltv == marketParams.lltv, "lltv mismatch");
  }

  // debugging with canaries 
  // function canary_hasRepaid() public returns (bool) {
  //   t(!hasRepaid, "hasRepaid");
  // }

  // function canary_hasLiquidated() public returns (bool) {
  //   t(!hasLiquidated, "hasLiquidated");
  // }
}