// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// IERC20
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Meme} from "./Meme.sol";
import {IFairLaunch, FairLaunchLimitAmountStruct} from "./IFairLaunch.sol";
import {NoDelegateCall} from "./NoDelegateCall.sol";

interface IUniswapV2Router02 {
    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);
}

interface IUniswapV2Factory {
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

contract FairLaunchLimitAmountToken is IFairLaunch, Meme, ReentrancyGuard, NoDelegateCall {
    using SafeERC20 for IERC20;

    uint256 public price;
    uint256 public amountPerUnits;

    uint256 public mintLimit;
    uint256 public minted;

    bool public started;
    address public launcher;

    address public uniswapRouter;
    address public uniswapFactory;

    uint256 public eachAddressMaxEthers;
    uint256 public totalDistribution;

    uint256 public refundFeeRate;
    address public refundFeeTo;

    uint256 public constant CMD_START = 0.0005 ether;


    constructor(
        FairLaunchLimitAmountStruct memory params
    ) Meme(params.name, params.symbol, params.meta) {
        price = params.price;
        amountPerUnits = params.amountPerUnits;
        started = false;

        launcher = params.launcher;
        meta = params.meta;

        // assert (totalSupply - _researvedTokens) % 2 == 0
        require(
            (params.totalSupply) % 2 == 0,
            "FairMint: totalSupply - _researvedTokens must be even number"
        );

        require(
            ((params.totalSupply) / 2) % params.amountPerUnits == 0,
            "FairMint: totalSupply - _researvedTokens must be divisible by 2 and _amountPerUnits"
        );

        uniswapRouter = params.uniswapRouter;
        uniswapFactory = params.uniswapFactory;

        eachAddressMaxEthers = params.eachAddressLimitEthers;
        totalDistribution = params.totalSupply;
        mintLimit = totalDistribution / 2;

        refundFeeRate = params.refundFeeRate;
        refundFeeTo = params.refundFeeTo;

        _mint(address(this), totalDistribution);
    }

    receive() external payable noDelegateCall {
        if (msg.value == CMD_START && !started) {
            if (minted == mintLimit) {
                start();
            } else {
                require(
                    msg.sender == launcher,
                    "FairMint: only launcher can start"
                );
                start();
            }
        } else {
            mint();
        }
    }

    function mint() internal virtual nonReentrant {
        require(msg.value >= price, "FairMint: value not match");
        require(msg.sender == tx.origin, "FairMint: can not mint to contract.");
        require(!started, "FairMint: already started");

        uint256 units = msg.value / price;
        uint256 realCost = units * price;
        uint256 refund = msg.value - realCost;

        require(
            minted + units * amountPerUnits <= mintLimit,
            "FairMint: exceed max supply"
        );

        require(
            (balanceOf(msg.sender) * price) / amountPerUnits + realCost <=
                eachAddressMaxEthers,
            "FairMint: exceed max mint"
        );

        _transfer(address(this), msg.sender, units * amountPerUnits);
        minted += units * amountPerUnits;

        emit FundEvent(msg.sender, realCost, units * amountPerUnits);

        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }
    }

    function start() private {
        require(!started, "FairMint: already started");
        address _weth = IUniswapV2Router02(uniswapRouter).WETH();
        address _pair = IUniswapV2Factory(uniswapFactory).getPair(
            address(this),
            _weth
        );

        if (_pair == address(0)) {
            _pair = IUniswapV2Factory(uniswapFactory).createPair(
                address(this),
                _weth
            );
        }
        _pair = IUniswapV2Factory(uniswapFactory).getPair(address(this), _weth);
        // assert pair exists
        assert(_pair != address(0));

        // set started
        started = true;

        // add liquidity
        IUniswapV2Router02 router = IUniswapV2Router02(uniswapRouter);
        uint256 balance = balanceOf(address(this));
        uint256 diff = balance - minted;
        // burn diff
        _burn(address(this), diff);
        _approve(address(this), uniswapRouter, type(uint256).max);
        // add liquidity
        (uint256 tokenAmount, uint256 ethAmount, uint256 liquidity) = router
            .addLiquidityETH{value: address(this).balance}(
            address(this),
            minted,
            minted,
            address(this).balance, // eth min
            address(this),
            block.timestamp + 1 days
        );
        _dropLP(_pair);
        emit LaunchEvent(address(this), tokenAmount, ethAmount, liquidity);
    }

    function _dropLP(address lp) internal virtual {
        IERC20 lpToken = IERC20(lp);
        lpToken.safeTransfer(address(0), lpToken.balanceOf(address(this)));
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(Meme) {
        // if not started, only allow refund
        if (!started) {
            if (to == address(this) && from != address(0)) {
                // refund deprecated
            } else {
                // if it is not refund operation, check and revert.
                if (from != address(0) && from != address(this)) {
                    // if it is not INIT action, revert. from address(0) means INIT action. from address(this) means mint action.
                    revert("FairMint: all tokens are locked until launch.");
                }
            }
        } else {
            if (to == address(this) && from != address(0)) {
                revert(
                    "FairMint: You can not send token to contract after launched."
                );
            }
        }
        super._update(from, to, value);
        if (to == address(this) && from != address(0)) {
            _refund(from, value);
        }
    }

    function _refund(address from, uint256 value) internal nonReentrant {
        require(!started, "FairMint: already started");
        require(from == tx.origin, "FairMint: can not refund to contract.");
        require(value >= amountPerUnits, "FairMint: value not match");
        require(value % amountPerUnits == 0, "FairMint: value not match");

        uint256 _eth = (value / amountPerUnits) * price;
        require(_eth > 0, "FairMint: no refund");

        minted -= value;
        //payable(from).transfer(_eth);
        uint256 fee = (_eth * refundFeeRate) / 10000;
        uint256 refund = _eth - fee;
        if (fee > 0) {
            payable(refundFeeTo).transfer(fee);
        }
        payable(from).transfer(refund);
        emit RefundEvent(from, value, _eth);
    }
    
}
