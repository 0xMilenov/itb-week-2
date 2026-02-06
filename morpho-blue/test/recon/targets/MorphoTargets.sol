// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

import "src/Morpho.sol";
import {Id, MarketParams} from "src/interfaces/IMorpho.sol";

abstract contract MorphoTargets is
    BaseTargetFunctions,
    Properties
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///
    function morpho_supply_clamped(uint256 assets) public {
        morpho_supply(assets, 0, _getActor(), hex"");
    }

    function morpho_supplyCollateral_clamped(uint256 assets) public {
        morpho_supplyCollateral(assets, _getActor(), hex"");
    }

    function morpho_liquidate_clamped(uint256 seizedAssets, bytes memory data, uint256 entropy) public {
        // improve coverage using other actor to achieve liquidator =! borrower
        address[] memory actors = _getActors();
        address borrower = actors[entropy % actors.length];
        morpho_liquidate(borrower, seizedAssets, 0, data);
    }

    function morpho_repay_clamped(uint256 assets) public {
        morpho_repay(assets, 0, _getActor(), hex"");
    }

    function morpho_liquidate_assets(uint256 seizedAssets, bytes memory data) public {
        morpho_liquidate(_getActor(), seizedAssets, 0, data);
    }

    function morpho_liquidate_shares(uint256 shares, bytes memory data) public {
        morpho_liquidate(_getActor(), 0, shares, data);
    }

    function morpho_withdraw_clamped(uint256 assets) public {
        // to be sure we have enough shares
        morpho_supply_clamped(assets + 1);
        morpho_withdraw(assets, 0, _getActor(), _getActor());
    }

    // bad dept
    function morpho_liquidate_badDebt_clamped(uint256 collateral) public {
        // safe and useful range
        collateral = (collateral % 1000) + 1;

        morpho_supply_clamped(1);
        morpho_supplyCollateral_clamped(collateral);

        oracle.setPrice(1e30);
        morpho_borrow(1, 0, _getActor(), _getActor());

        oracle.setPrice(0);
        morpho_liquidate(_getActor(), collateral, 0, hex"");
    }

    // dynamic market creation
    function morpho_createMarket_clamped(uint8 index, uint256 entropy) public {
        
        uint256 lltv = enabledLltvs[entropy % enabledLltvs.length];
        
        address[] memory assets = _getAssets();
        address loanToken = assets[index % assets.length];
        address collateralToken = _getAsset();

        // avoid loanToken to be equal with colalteralToken
        if (loanToken == collateralToken && assets.length > 1) {
            loanToken = assets[(index + 1) % assets.length];
        }

        MarketParams memory mp = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken, 
            oracle: address(oracle),
            irm: address(irm),
            lltv: lltv
        });

        morpho_createMarket(mp);
    }

    // switch markets
    function morpho_switchMarket(uint256 entropy) public {
        if (trackedMarketIds.length == 0) return;

        Id id = trackedMarketIds[entropy % trackedMarketIds.length];
        (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) = morpho.idToMarketParams(id);

        marketParams = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracle,
            irm: irm,
            lltv: lltv
        });
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function morpho_accrueInterest() public asActor {
        morpho.accrueInterest(marketParams);
    }

    function morpho_borrow(uint256 assets, uint256 shares, address onBehalf, address receiver) public asActor {
        morpho.borrow(marketParams, assets, shares, onBehalf, receiver);
    }

    function morpho_createMarket(MarketParams memory mp) public asActor {
        morpho.createMarket(mp);

        marketParams = mp;
        _trackMarket(mp);
    }

    function morpho_enableIrm(address irm) public asActor {
        morpho.enableIrm(irm);
    }

    function morpho_enableLltv(uint256 entropy) public asActor {
        uint256 lltv = 7e17 + (entropy % 26) * 1e16; // 70%-95% range
        morpho.enableLltv(lltv);
        // if call didn't revert track it
        enabledLltvs.push(lltv);
    }

    function morpho_flashLoan(address token, uint256 assets, bytes memory data) public asActor {
        morpho.flashLoan(token, assets, data);
    }

    function morpho_liquidate(address borrower, uint256 seizedAssets, uint256 repaidShares, bytes memory data) public asActor {
        morpho.liquidate(marketParams, borrower, seizedAssets, repaidShares, data);
        // hasLiquidated = true;
    }

    function morpho_repay(uint256 assets, uint256 shares, address onBehalf, bytes memory data) public asActor {
        morpho.repay(marketParams, assets, shares, onBehalf, data);
        // hasRepaid = true;
    }

    function morpho_setAuthorization(address authorized, bool newIsAuthorized) public asActor {
        morpho.setAuthorization(authorized, newIsAuthorized);
    }

    function morpho_setAuthorizationWithSig(Authorization memory authorization, Signature memory signature) public asActor {
        morpho.setAuthorizationWithSig(authorization, signature);
    }

    function morpho_setFee(uint256 newFee) public asActor {
        morpho.setFee(marketParams, newFee);
    }

    function morpho_setFeeRecipient(address newFeeRecipient) public asActor {
        morpho.setFeeRecipient(newFeeRecipient);
    }

    function morpho_setOwner(address newOwner) public asActor {
        morpho.setOwner(newOwner);
    }

    function morpho_supply(uint256 assets, uint256 shares, address onBehalf, bytes memory data) public asActor {
        morpho.supply(marketParams, assets, shares, onBehalf, data);
    }

    function morpho_supplyCollateral(uint256 assets, address onBehalf, bytes memory data) public asActor {
        morpho.supplyCollateral(marketParams, assets, onBehalf, data);
    }

    function morpho_withdraw(uint256 assets, uint256 shares, address onBehalf, address receiver) public asActor {
        morpho.withdraw(marketParams, assets, shares, onBehalf, receiver);
    }

    function morpho_withdrawCollateral(uint256 assets, address onBehalf, address receiver) public asActor {
        morpho.withdrawCollateral(marketParams, assets, onBehalf, receiver);
    }
}