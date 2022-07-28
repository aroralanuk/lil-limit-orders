// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import '@openzeppelin/contracts/access/Ownable.sol';

import "./GaslessTransfer.sol";

// CFMM is a contract that allows to swap between token0 and token0
// The caller must have approved the GaslessTransfer contract to transfer its tokens (AMM will use transferFrom)
contract CFMM is Ownable, AMM {
  address public token0;
  address public token1;
  constructor() public {}

  function setTokens(address _token0, address _token1) public onlyOwner {
    token0 = _token0;
    token1 = _token1;
  }

  function addLiquidity(address token_address, uint amount) public onlyOwner {
    IERC20(token_address).transferFrom(msg.sender, address(this), amount);
  }

  function swap(address from, address to, uint amount) public {
    require((from == token0 && to == token1) || (from == token1 && to == token0), "Invalid tokens");
    require(IERC20(from).balanceOf(msg.sender) >= amount, "Not enough to swap");
    uint swapAmount = getSwapPrice(from, to, amount);
    IERC20(from).transferFrom(msg.sender, address(this), amount);
    IERC20(to).approve(address(this), swapAmount);
    IERC20(to).transferFrom(address(this), msg.sender, swapAmount);
  }

  // Swap amount0 of token0 for token0
    function swapExactAmount0In(uint amount0) external {
        swap(address(token0), address(token1), amount0);
    }


  function getSwapPrice(address from, address to, uint amount) public view returns(uint){
    return((amount * IERC20(to).balanceOf(address(this)))/IERC20(from).balanceOf(address(this)));
  }


  function balanceOf(address token, address account) public view returns (uint){
    return IERC20(token).balanceOf(account);
  }
}
