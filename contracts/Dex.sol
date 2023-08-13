// contracts/FlashLoan.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

contract Dex {
    address payable public owner;

    // Aave ERC20 Token addresses on Sepolia (Not-Goerli) network
    address private immutable daiAddress =
        0x68194a729C2450ad26072b3D33ADaCbcef39D574;
        //0xDF1742fE5b0bFc12331D8EAec6b478DfDbD31464;
    address private immutable usdcAddress =
        0xda9d4f9b69ac6C22e444eD9aF0CfC043b7a7f53f;
        //0xA2025B15a1757311bfD68cb14eaeFCc237AF5b43;

    IERC20 private dai;
    IERC20 private usdc;

    // exchange rate indexes
    uint256 dexARate = 90;  // 90, meaning i can buy DAI token for the price of 90 cents on the USDC
    uint256 dexBRate = 100; // 100, meaning it is a 1-to-1 value between DAI and USDC

    // keeps track of individuals' dai balances
    mapping(address => uint256) public daiBalances;

    // keeps track of individuals' USDC balances
    mapping(address => uint256) public usdcBalances;

    constructor() {
        owner = payable(msg.sender);
        dai = IERC20(daiAddress);
        usdc = IERC20(usdcAddress);
    }

    function depositUSDC(uint256 _amount) external {
        usdcBalances[msg.sender] += _amount;
        uint256 allowance = usdc.allowance(msg.sender, address(this));
        require(allowance >= _amount, "Check the token allowance");
        usdc.transferFrom(msg.sender, address(this), _amount);
    }

    function depositDAI(uint256 _amount) external {
        daiBalances[msg.sender] += _amount;
        uint256 allowance = dai.allowance(msg.sender, address(this));
        require(allowance >= _amount, "Check the token allowance");
        dai.transferFrom(msg.sender, address(this), _amount);
    }

    function buyDAI() external {
        uint256 daiToReceive = ((usdcBalances[msg.sender] / dexARate) * 100) *
            (10**12);
        dai.transfer(msg.sender, daiToReceive);
    }

    function sellDAI() external {
        uint256 usdcToReceive = ((daiBalances[msg.sender] * dexBRate) / 100) /
            (10**12);
        usdc.transfer(msg.sender, usdcToReceive);
    }

    function getBalance(address _tokenAddress) external view returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    function withdraw(address _tokenAddress) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the contract owner can call this function"
        );
        _;
    }

    receive() external payable {}
}