pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// AMM is a contract that allows to swap between token0 and token1
// The caller must have approved the GassLessTransfer contract to transfer its tokens (AMM will use transferFrom)
interface AMM{
    // Swap amount0 of token0 for token1
    function swapExactAmount0In(uint amount0) external;
}

// Users can deposit token0 to this contract and wait for a relayer to do swap for token1
contract GaslessTransfer is ReentrancyGuard {

    AMM amm;
    IERC20 token0;
    IERC20 token1;

    mapping(address => uint) public balances0;
    mapping(address => uint) public balances1;
    mapping(address => uint) public swapLimit;

    constructor(AMM amm_param, IERC20 t0, IERC20 t1){
        require(address(amm_param) != address(0));
        require(address(t0) != address(0));
        require(address(t1) != address(0));
        amm = amm_param;
        token0 = t0;
        token1 = t1;

        // Unlimited approve of the amm for token0
        // This is needed for the swaps
        token0.approve(address(amm_param), 2**256-1);
    }

    // User can deposit their token0
    function deposit(uint amount) external nonReentrant {
        token0.transferFrom(msg.sender, address(this), amount);
        balances0[msg.sender] += amount;
    }

    // User can withdraw their token0 and token1
    // We follow the check effect interaction pattern
    function withdraw(uint amount0, uint amount1) external nonReentrant {
        balances0[msg.sender] -= amount0;
        token0.transfer(msg.sender, amount0);

        balances1[msg.sender] -= amount1;
        token1.transfer(msg.sender, amount1);
    }

    // User can withdraw all their token0 and token1
    // nonReentrant to protect from reentrancies
    function withdrawAll() external nonReentrant {
        balances0[msg.sender] = 0;
        token0.transfer(msg.sender, balances0[msg.sender]);

        balances1[msg.sender] = 0;
        token1.transfer(msg.sender, balances1[msg.sender]);
    }

    function setSwapLimit(uint amount) external
    {
        swapLimit[msg.sender] = amount;
    }

    // Allow anyone to exchange some of of the token0 for token1
    // tokenToReceive is here to prevent sandwich attack
    // nonReentrant to protect from reentrancies
    function swapToken0toToken1(address from) external nonReentrant {

        uint balance0 = balances0[from];
        uint tokenToReceive = swapLimit[from];

        // balance1_before is used for slippage protection
        uint balance1_before = token1.balanceOf(address(this));

        amm.swapExactAmount0In(balance0);

        // Check the slippage
        uint balance1_after = token1.balanceOf(address(this));
        require(balance1_after >= balance1_before + tokenToReceive);

        // Remove the user balance
        balances0[from] = 0;
        // Add the new token to the destination
        balances1[from] = tokenToReceive;
    }

}
