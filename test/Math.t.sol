// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Math} from "../src/FairLaunchLimitBlockV3.sol";

contract MathTest is Test {
    using Math for uint256;

    // setup
    function setUp() public {}

    function test_Sqrt() public view {
        uint256 x = 100;
        uint256 y = x.sqrt();
        console.log("sqrt(100) = ", y);
        assertEq(y, 10);

        x = 10000;
        y = x.sqrt();
        console.log("sqrt(10000) = ", y);
        assertEq(y, 100);
    }

    function test_sqrtx96() public view {
        uint256 amount0 = 1000 * 10 ** 18;
        uint256 amount1 = 1 * 10 ** 17;

        // 0.1 bnb / 1000 token = 0.0001 bnb/token = 10000 token/bnb
        uint256 price =    amount1   * 1e18 / amount0; // 1 token1 can be exchanged for 10000 token0

        uint256 scaledPrice = price;
        uint256 sqrtScaledPrice = scaledPrice.sqrt();
        uint160 sqrtPriceX96 = uint160((sqrtScaledPrice << 96) / 1e9);

        console.log("price: ", price);
        console.log("scaledPriceX96: ", sqrtPriceX96);



        
    }
}
