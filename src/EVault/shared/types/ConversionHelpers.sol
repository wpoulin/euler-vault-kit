// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {MarketCache} from "./MarketCache.sol";
import "../Constants.sol";

function conversionTotals(MarketCache memory marketCache) pure returns (uint256 totalAssets, uint256 totalShares) {
    unchecked {
        totalAssets =
            marketCache.cash.toUint() + marketCache.totalBorrows.toAssetsUp().toUint() + VIRTUAL_DEPOSIT_AMOUNT;
        totalShares = marketCache.totalShares.toUint() + VIRTUAL_DEPOSIT_AMOUNT;
    }
}