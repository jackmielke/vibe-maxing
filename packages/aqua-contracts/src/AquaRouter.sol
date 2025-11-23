// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

/// @custom:license-url https://github.com/1inch/aqua/blob/main/LICENSES/Aqua-Source-1.1.txt
/// @custom:copyright © 2025 Degensoft Ltd

import { Aqua } from "./Aqua.sol";
import { Simulator } from "./libs/Simulator.sol";
import { Multicall } from "./libs/Multicall.sol";

contract AquaRouter is Aqua, Simulator, Multicall { }
