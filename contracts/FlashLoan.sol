// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FlashLoanSimpleReceiverBase} from "@aave/core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

contract FlashLoan is FlashLoanSimpleReceiverBase{
    address payable owner; //we want to be able to withdraw fund from this contract, cuz there should be profits, and we want to implement a withdrawal function where only Owner can withdraw.
    
    constructor (address _addressProvider) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider)) {
        owner = payable(msg.sender);
    }
    
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool){
        // we have the borrowed funds
        // add any custom logic (example mock arbitrage)

        // this part then returns it back to the pool.
        uint256 amountOwed = amount + premium; // the amt we need to approve for the pool contract.
        IERC20(asset).approve(address(POOL),amountOwed); // the POOL variable is already setup in "FlashLoanSimpleReceiverBase", via the IPool, and that gives us access to POOL.
        return true;
    }

    // this is going to wrap the actual function call to the pool contract.
    function requestFlashLoan(address _token, uint256 _amount) public {
        address receiverAddress = address(this);
        address asset = _token;
        uint256 amount = _amount;
        bytes memory params = "";
        uint16 referralCode = 0;

        //This part request the flashLoan from the aave POOL
        POOL.flashLoanSimple(
            receiverAddress,
            asset,
            amount,
            params,
            referralCode
        );
        
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can call this function");
        _;
    }


    // writing some utility funcs that will help us for testing
    // 1) use this at the very end, after the flashLoan is completed to see what is the balance
    function getBalance(address _tokenAddress) external view returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    // 2) for withdrawal, onlyOwner can withdraw.
    function withdraw(address _tokenAddress) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    receive() external payable {}

}