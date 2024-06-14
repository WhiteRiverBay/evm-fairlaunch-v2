// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// IERC20
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// SafeERC20
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

interface IUniswapV2Pair {
    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);
}

interface IUniswapV2Factory {
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
}

struct LockItemStruct {
    uint id;
    address owner;
    // token address
    address lpToken;
    // init amount
    uint256 initLPAmount;
    // if it is 0, never unlock
    uint256 unlockBlock;
    // lock block
    uint256 lockBlock;
    // if it is 0, never reinvest
    uint256 reInvestMinBlock;
    // last reinvest block
    uint256 lastReInvestBlock;
    // token 0 amount per LP at the time of lock
    uint256 token0amount;
    // token 1 amount per LP at the time of lock
    uint256 token1amount;
    // last token0amount
    uint256 lastToken0amount;
    // last token1amount
    uint256 lastToken1amount;
    // last amount
    uint256 lastLPAmount;
    // init reverse
    uint256 initReserve0;
    uint256 initReserve1;
}

contract LockAndEarnContractV2 {
    using SafeERC20 for IERC20;

    uint public idTracker;

    address public uniswapFactory;
    address public uniswapRouter;

    mapping(uint => LockItemStruct) public lockItems;

    event Lock(
        uint id,
        address owner,
        address token,
        uint256 amount,
        uint256 unlockBlock,
        uint256 lockBlock,
        uint256 reInvestMinBlock,
        uint256 lastReInvestBlock
    );
    event Withdraw(uint id, address owner, address token, uint256 amount);
    event ReInvest(uint id, address owner, address token, uint256 amount);

    constructor() {
        // no fucking owner
    }

    function lock(LockItemStruct memory _item) external {
        // lock in
    }

    function withdraw(uint _id) external {
        // withdraw LP
    }

    function reInvest(uint _id) external {
        // re invest
        // drop token to black hole
        // use wETH to buy token and drop to black hole
    }

    function getImpermanentLoss(
        uint _id
    )
        external
        view
        returns (
            uint256 token0Amount,
            uint256 token1Amount,
            uint256 impermanentLoss
        )
    {
        LockItemStruct memory item = lockItems[_id];

        IUniswapV2Pair pair = IUniswapV2Pair(item.lpToken);

        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        uint256 totalSupply = pair.totalSupply();
        uint256 userBalance = item.lastLPAmount;

        // 用户所占份额
        uint256 userShare = (userBalance * 1e18) / totalSupply;

        // 用户的代币数量
        token0Amount = (uint256(reserve0) * userShare) / 1e18;
        token1Amount = (uint256(reserve1) * userShare) / 1e18;

        // 初始价格和当前价格
        uint256 initialPrice = (uint256(item.initReserve0) * 1e18) /
            uint256(item.initReserve1);
        uint256 currentPrice = (uint256(reserve0) * 1e18) / uint256(reserve1);

        // 计算无常损失
        if (currentPrice > initialPrice) {
            impermanentLoss =
                ((currentPrice - initialPrice) * userShare) /
                currentPrice;
        } else {
            impermanentLoss =
                ((initialPrice - currentPrice) * userShare) /
                initialPrice;
        }
    }
}
