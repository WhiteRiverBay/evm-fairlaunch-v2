// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Create2} from "openzeppelin-contracts/contracts/utils/Create2.sol";
import {FairLaunchLimitAmountToken} from "./FairLaunchLimitAmount.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IFairLaunch, FairLaunchLimitAmountStruct} from "./IFairLaunch.sol";

/**
To new issuers, in order to avoid this situation, 
please use the factory contract to deploy the Token contract when deploying new contracts in the future. 

Please use a new address that has not actively initiated transactions on any chain to deploy. 
The factory contract can create the same address on each evm chain through the create2 function. 
If a player transfers ETHs to the wrong chain, you can also help the player get his ETH back by refunding his money by deploying a contract on a specific chain.
 */
contract FairLaunchLimitAmountFactory is IFairLaunch, ReentrancyGuard {

    uint256 public price;
    address public owner;
    address public feeTo;

    address public refundFeeTo;
    uint256 public refundFeeRate;

    uint256 public constant FAIR_LAUNCH_LIMIT_AMOUNT = 1;
    uint256 public constant FAIR_LAUNCH_LIMIT_BLOCK = 2;

    // owner modifier
    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setPrice(uint256 _price) public onlyOwner {
        price = _price;
    }

    function setOwner(address _owner) public onlyOwner {
        owner = _owner;
    }

    function setFeeTo(address _feeTo) public onlyOwner {
        feeTo = _feeTo;
    }

    function setRefundFeeTo(address _refundFeeTo) public onlyOwner {
        refundFeeTo = _refundFeeTo;
    }

    function setRefundFeeRate(uint256 _refundFeeRate) public onlyOwner {
        refundFeeRate = _refundFeeRate;
    }

    function getFairLaunchLimitAmountAddress(
        uint256 salt,
        FairLaunchLimitAmountStruct memory params
    ) public view returns (address)  {
        bytes32 _salt = keccak256(abi.encodePacked(salt));
        
        params.refundFeeRate = refundFeeRate;
        params.refundFeeTo = refundFeeTo;

        return
            Create2.computeAddress(
                _salt,
                keccak256(
                    abi.encodePacked(
                        type(FairLaunchLimitAmountToken).creationCode,
                        abi.encode(
                            params
                        )
                    )
                )
            );
    }

    function deployFairLaunchLimitAmountContract(
        uint256 salt,
        FairLaunchLimitAmountStruct memory params
    ) public payable nonReentrant {

        params.refundFeeRate = refundFeeRate;
        params.refundFeeTo = refundFeeTo;

        if (feeTo != address(0) && price > 0) {
            require(msg.value >= price, "insufficient price");

            (bool success, ) = payable(feeTo).call{value: msg.value}("");
            require(success, "Transfer failed.");
        }
        bytes32 _salt = keccak256(abi.encodePacked(salt));
        bytes memory bytecode = abi.encodePacked(
            type(FairLaunchLimitAmountToken).creationCode,
            abi.encode(
                params
            )
        );
        address addr = Create2.deploy(0, _salt, bytecode);
        emit Deployed(addr, FAIR_LAUNCH_LIMIT_AMOUNT);
    }

}
