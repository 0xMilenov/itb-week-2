// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract FoundryTest is Test {
    address constant USER1 = address(0x10000);

    // TODO: Replace with your actual contract instance
    CryticTester Target;

  function setUp() public {
      // TODO: Initialize your contract here
      Target = new CryticTester();
  }

  function test_replay() public {
        _setUpActor(USER1);
        Target.morpho_supply_clamped(1);
        _setUpActor(USER1);
        Target.morpho_supplyCollateral_clamped(2);
        _setUpActor(USER1);
        Target.morpho_borrow(1, 0, address(0x7fa9385be102ac3eac297483dd6233d62b3e1496), address(0xdeadbeef));
        _setUpActor(USER1);
        Target.morpho_repay_clamped(1);
        _setUpActor(USER1);
        Target.canary_hasRepaid();
  }

  function _setUpActor(address actor) internal {
      vm.startPrank(actor);
      // Add any additional actor setup here if needed
  }

  function _delay(uint256 timeInSeconds, uint256 numBlocks) internal {
      vm.warp(block.timestamp + timeInSeconds);
      vm.roll(block.number + numBlocks);
  }
}
