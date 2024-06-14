// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FairLaunchLimitAmountFactory} from "../src/FairLaunchLimitAmountFactory.sol";
import {FairLaunchLimitBlockFactory} from "../src/FairLaunchLimitBlockFactory.sol";
import {IFairLaunch, FairLaunchLimitBlockStruct, FairLaunchLimitAmountStruct} from "../src/IFairLaunch.sol";

contract FairLaunchFactoryTest is Test {
    FairLaunchLimitAmountFactory public amountFactory;
    FairLaunchLimitBlockFactory public blockFactory;

    function setUp() public {
        amountFactory = new FairLaunchLimitAmountFactory();
        blockFactory = new FairLaunchLimitBlockFactory(address(1));
    }

    function test_createFairLaunchLimitAmount() public {
        amountFactory.setFeeTo(address(1));

        FairLaunchLimitAmountStruct
            memory params = FairLaunchLimitAmountStruct({
                price: 0.01 ether,
                amountPerUnits: 100,
                totalSupply: 10000 * 10 ** 18,
                launcher: address(1),
                uniswapRouter: address(2),
                uniswapFactory: address(3),
                name: "TestToken",
                symbol: "TT",
                meta: "[]",
                eachAddressLimitEthers: 0.1 ether,
                refundFeeRate: 0,
                refundFeeTo: address(1)
            });
        address _addr = amountFactory.getFairLaunchLimitAmountAddress(1, params);

        console.log("FairLaunchLimitAmount address: ", _addr);

        uint256 price = amountFactory.price();
        vm.deal(address(this), price);

        vm.expectEmit(true, true, false, false);
        emit IFairLaunch.Deployed(_addr, 1);
        amountFactory.deployFairLaunchLimitAmountContract{value: price}(1, params);
        

        // address(1) balance should be price
        assertEq(address(1).balance, price);
    }

    function test_createFairLaunchLimitBlock() public {
        blockFactory.setFeeTo(address(1));

        uint256 afterBlock = block.number + 100;
        FairLaunchLimitBlockStruct memory params2 = FairLaunchLimitBlockStruct({
            totalSupply: 10000 * 10 ** 18,
            uniswapRouter: address(2),
            uniswapFactory: address(3),
            name: "TestToken",
            symbol: "TT",
            meta: "[]",
            afterBlock: afterBlock,
            softTopCap: 0,
            refundFeeRate: 0,
            refundFeeTo: address(1)
        });

        address _addr = blockFactory.getFairLaunchLimitBlockAddress(0, params2);

        console.log("FairLaunchLimitBlock address: ", _addr);

        uint256 price = blockFactory.price();
        vm.deal(address(this), price);

        vm.expectEmit(true, true, false, false);
        emit IFairLaunch.Deployed(_addr, 2);
        blockFactory.deployFairLaunchLimitBlockContract{value: price}(0, params2);

        // address(1) balance should be price
        assertEq(address(1).balance, price);
    }
}
