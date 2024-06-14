// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IFairLaunchToken is IERC20Metadata {
    // bool public started;
    function started() external view returns (bool);
    // uint256 public totalDispatch;
    function totalDispatch() external view returns (uint256);
    // uint256 public untilBlockNumber;
    function untilBlockNumber() external view returns (uint256);
    // uint256 public totalEthers;
    function totalEthers() external view returns (uint256);
    // uint256 public softTopCap;
    function softTopCap() external view returns (uint256);
}