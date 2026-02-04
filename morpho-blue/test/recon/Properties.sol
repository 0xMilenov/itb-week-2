// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Asserts} from "@chimera/Asserts.sol";
import {BeforeAfter} from "./BeforeAfter.sol";

abstract contract Properties is BeforeAfter, Asserts {

  // debugging with canaries 
  // function canary_hasRepaid() public returns (bool) {
  //   t(!hasRepaid, "hasRepaid");
  // }

  // function canary_hasLiquidated() public returns (bool) {
  //   t(!hasLiquidated, "hasLiquidated");
  // }
}