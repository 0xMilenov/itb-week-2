// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {BaseSetup} from "@chimera/BaseSetup.sol";
import {vm} from "@chimera/Hevm.sol";

// Managers
import {ActorManager} from "@recon/ActorManager.sol";
import {AssetManager} from "@recon/AssetManager.sol";

// Helpers
import {Utils} from "@recon/Utils.sol";

// Your deps
import "src/Morpho.sol";

import {Id, MarketParams, Market} from "src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "src/libraries/MarketParamsLib.sol";
import {OracleMock} from "src/mocks/OracleMock.sol";

// we need a new mock irm contract, because the morpho's mock irm doesnt have a setter
contract MockIRM {
    uint256 internal _borrowRate;

    function setBorrowRate(uint256 newBorrowRate) external {
        _borrowRate = newBorrowRate;
    }

    function borrowRate(MarketParams memory marketParams, Market memory market) public view returns (uint256) {
        return _borrowRate;
    }

    function borrowRateView(MarketParams memory marketParams, Market memory market) public view returns (uint256) {
        return borrowRate(marketParams, market);
    }
}


abstract contract Setup is BaseSetup, ActorManager, AssetManager, Utils {
    using MarketParamsLib for MarketParams;

    Morpho morpho;
    MockIRM irm;
    // we can use morpho's mock oracle
    OracleMock oracle;
    MarketParams marketParams;


    // bounded list to track markets for dynamic market creation
    Id[] internal trackedMarketIds;
    uint256 internal constant MAX_TRACKED_MARKETS = 5;
    mapping(bytes32 => bool) internal isTracked;

    // track enabled lltvs because totally random lltv will make createMarket often to revert
    uint256[] internal enabledLltvs;

    // Canary tracking variables
    // bool internal hasRepaid;
    // bool internal hasLiquidated;
    
    /// === Setup === ///
    /// This contains all calls to be performed in the tester constructor, both for Echidna and Foundry
    function setup() internal virtual override {
        // core protocol
        morpho = new Morpho(_getActor());

        // interest rate contract
        irm = new MockIRM();

        // oracle
        oracle = new OracleMock();

        oracle.setPrice(1e36);

        // two assets from AssetManager - collateral and loan tokens
        _newAsset(18);
        _newAsset(18);

        // configure the market || loan to value is 80%
        morpho.enableIrm(address(irm));
        morpho.enableLltv(8e17);
        // track the lltv
        enabledLltvs.push(8e17);

        address[] memory assets = _getAssets();
        marketParams = MarketParams({
            loanToken: assets[1],
            collateralToken: assets[0],
            oracle: address(oracle),
            irm: address(irm),
            lltv: 8e17
        });

        morpho.createMarket(marketParams);

        _trackMarket(marketParams);

        // approve and mint using AssetManager
        address[] memory approvalArray = new address[](1);
        approvalArray[0] = address(morpho);

        _finalizeAssetDeployment(_getActors(), approvalArray, type(uint88).max);
    }

    // helper function for dynamic market creation and tracking
    function _trackMarket(MarketParams memory mp) internal {
        Id id = mp.id();
        bytes32 key = Id.unwrap(id);
        if (isTracked[key]) return;
        if (trackedMarketIds.length >= MAX_TRACKED_MARKETS) return;

        isTracked[key] = true;
        trackedMarketIds.push(id);
    }


    /// === MODIFIERS === ///
    /// Prank admin and actor
    
    modifier asAdmin {
        vm.prank(address(this));
        _;
    }

    modifier asActor {
        vm.prank(address(_getActor()));
        _;
    }
}
