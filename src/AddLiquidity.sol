// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

// IERC20
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// ERC20
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

interface IUniLocker {
    function lock(
        address lpToken,
        uint256 amountOrId,
        uint256 unlockBlock
    ) external returns (uint256 id);
}

interface IUniswapV3Factory {
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);

    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool);
}

interface INonfungiblePositionManager {
    function WETH9() external pure returns (address);

    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function mint(
        MintParams calldata params
    )
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable returns (address pool);

    function refundETH() external payable;

    function multicall(
        bytes[] calldata data
    ) external payable returns (bytes[] memory results);
}

contract AddLiquidityToken is ERC20 {
    using Math for uint256;
    using SafeERC20 for IERC20;

    uint24 public poolFee = 2500;

    // contructor
    constructor() ERC20("TT1", "TT1") {
        _mint(msg.sender, 10000 * 1e18);
    }

    function _multiCallInitAndMint(
        INonfungiblePositionManager _positionManager,
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        uint256 totalAdd
    ) private {
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (amount0, amount1) = (amount1, amount0);
        }
        // 1 - create pool
        bytes memory dataCreate = abi.encodeWithSelector(
            _positionManager.createAndInitializePoolIfNecessary.selector,
            token0,
            token1,
            poolFee,
            getSqrtPriceX96(amount0, amount1)
        );

        // 2 - mint liquidity
        bytes memory dataMint = abi.encodeWithSelector(
            _positionManager.mint.selector,
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: poolFee,
                tickLower: -887272,
                tickUpper: 887272,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: (amount0 * 98) / 100,
                amount1Min: (amount1 * 98) / 100,
                recipient: address(this),
                deadline: block.timestamp + 1 hours
            })
        );

        // 3 - refund eth
        bytes memory dataRefund = abi.encodeWithSelector(
            _positionManager.refundETH.selector
        );

        bytes[] memory data = new bytes[](1);
        data[0] = dataCreate;
        // data[1] = dataMint;
        // data[2] = dataRefund;

        _positionManager.multicall{value: totalAdd}(data);
    }

    function getSqrtPriceX96(
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (uint160) {
        require(amount0 > 0 && amount1 > 0, "Amounts must be greater than 0");

        // Calculate the price ratio
        uint256 price = (amount1 * 1e18) / amount0; // Scaling by 1e18 for precision
        // Calculate the square root of the price ratio
        uint256 sqrtPrice = price.sqrt();
        // Scale by 2^96
        uint256 sqrtPriceX96Full = (sqrtPrice << 96) / 1e9; // Adjust scaling factor
        // Return the result as uint160
        return uint160(sqrtPriceX96Full);
    }
}

library Math {
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 result = a;
        uint256 k = a / 2 + 1;
        while (k < result) {
            result = k;
            k = (a / k + k) / 2;
        }
        return result;
    }
}
