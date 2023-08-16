pragma solidity ^0.8.19;

import './UniswapV2Library.sol';
import './interfaces/IUniswapV2Router02.sol';
import './interfaces/IUniswapV2Pair.sol';
import './interfaces/IUniswapV2Factory.sol';
import './interfaces/IERC20.sol';

contract Arbitrage {
  address public factory; //factory of uniswap (central hub in uni's eco). allow to have some info about the different liquidity pools.
  uint constant deadline = 10 days; // for our trades.
  IUniswapV2Router02 public sushiRouter; // pointer to sushi's router. (central spot contract in sushi's eco). used to execute trade in sushiswap's liquidity pool.
  // internally sushiswap reuses alot of uniswap, which is why the interface we use UniswapV2's router.

  constructor(address _factory, address _sushiRouter) public {
    factory = _factory;  //initialized Uniswap factory
    sushiRouter = IUniswapV2Router02(_sushiRouter);  //initialized sushi router.
  }

  // Trader to monitor price difference between uniswap & sushiswap, (with a custom script)
  // Then we spot a price difference then we call this startArbitrage() function.
  //////////////////////////////////////////////////////////////////////////
  // This is the func() that the trader is going to call, to execute our arbitrage.
  ///////////////////////
  function startArbitrage(
    // the two token we want to use for our arbitrage. E.g Eth & Dai
    address token0, 
    address token1, 
    // one of these is going to be "0", the other one is going to be the amt we want to borrow for our flash loan.
    uint amount0, 
    uint amount1
    // if amt0 = 0, amt1 = 1000, means we are going to borrow for 1000 of amt1. and vice versa.
  ) external {
    address pairAddress = IUniswapV2Factory(factory).getPair(token0, token1); //token0 & token1 order doesn't matter, uniswap knows how to deal with it.
    require(pairAddress != address(0), 'This pool does not exist'); //make sure the liquidity pools of the token pair exist.
    // This is where we initiate the FlashLoan
    // .swap is a lowlevel func() and normally when u trade with uniswap, u call another contract called the "router", and the router behind will hood will call this swap function.
    // But when u want to do a FlashLoan, need to Directly call the swap func on the pair yourself.
    IUniswapV2Pair(pairAddress).swap(
      amount0, // one of this gonna be 0
      amount1, //
      address(this), // this address which is where we want to reieve the tkn we wanna borrow.
      bytes('not empty') // Make sure it's "not empty"
      // This is what's going to trigger the FlashLoan. 
      // Otherwise if EMPTY, it will just tigger a normal swap operation when a trader just want to buy/sell some tokens. And not tigger the FlashLoan.
    );
  }

  // Then uniswap will callback this function here.
  // uniswap is expecting our smart contract to have this function so
  function uniswapV2Call(
    address _sender, //the address that trigger the flashloan. (the address of our arbitrage SC)
    uint _amount0, 
    uint _amount1, 
    bytes calldata _data // same as the .swap bytes data. // can just ignore
  ) external {
    address[] memory path = new address[](2); // an array of address, is going to be used in order to do the trade later.
    uint amountToken = _amount0 == 0 ? _amount1 : _amount0; //amountToken = the amt of token we borrow. (it can be amount 0 or amount 1)
    
    // get addr of the two tkns in the Liquidity pool of uniswap
    address token0 = IUniswapV2Pair(msg.sender).token0();
    address token1 = IUniswapV2Pair(msg.sender).token1();

    // security // ensure the Call comes from one of the pair contract of uniswap
    // do not allow other contracts(maybe malicious) to mess with out arbitrage contract. potentially do weird things.
    require(
      msg.sender == UniswapV2Library.pairFor(factory, token0, token1), 
      'Unauthorized'
    ); 
    require(_amount0 == 0 || _amount1 == 0); // check one of the amount == 0

    //This part populated our pass arrary
    // IMPT, cuz this define the direction of the trade. E.g 
    path[0] = _amount0 == 0 ? token1 : token0; // if _amount0 == 0, means on sushiswap, we are going to sell token1 for token0. if != 0 , then sell token0 for token1
    path[1] = _amount0 == 0 ? token0 : token1;

    IERC20 token = IERC20(_amount0 == 0 ? token1 : token0); // build a pointer to the token we're gonna sell on sushiswap
    
    //allow the router of sushiswap to spend our tokens.
    token.approve(address(sushiRouter), amountToken);

    //we calculate the amt of token we need to reimburse to the flashloan of Uniswap.
    uint amountRequired = UniswapV2Library.getAmountsIn(
      factory, 
      amountToken, 
      path
    )[0];

    // sell the token we borrow from uniswap, and sell it on sushiswap
    uint amountReceived = sushiRouter.swapExactTokensForTokens(
      amountToken, //amount we wanna sell
      amountRequired, //minimum amount of the other token we want to recieve in exchange. (tt's the amt we need to reimburse the Flashloan)
      path, // path to tell sushiswap, what we want to sell, and buy.
      msg.sender, // the address tt's going to receive the token (which is our smartcontract)
      deadline //time limit after which an order will be rejected by sushiswap. // but because it's flashloan,and if price changes, and it's not profitable, tx will revert anyway, so we don't need it, just that we just need to specify something.
    )[1];

    IERC20 otherToken = IERC20(_amount0 == 0 ? token0 : token1); // we get a pointer to the other token as an output from sushiswap
    otherToken.transfer(msg.sender, amountRequired); // reimburse the flashloan of uniswap, with a portion of this "otherToken" 
    otherToken.transfer(tx.origin, amountReceived - amountRequired); //the rest is our profits, that get sends back to us. (tx.origin is the addres that initiate the whole tx.which is myself or the script i used to moniter the price difference btw uni/sushi)
  }
}