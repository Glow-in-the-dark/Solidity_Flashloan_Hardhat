// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FlashLoanSimpleReceiverBase} from "@aave/core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

//create an interface to the Dex contract, for our FlashLoanArbitrage contract to talk to the Dex.sol contract
interface IDex {
    function depositUSDC(uint256 _amount) external;
    function depositDAI(uint256 _amount) external;
    function buyDAI() external;
    function sellDAI() external;
}


contract FlashLoan is FlashLoanSimpleReceiverBase{
    address payable owner; //we want to be able to withdraw fund from this contract, cuz there should be profits, and we want to implement a withdrawal function where only Owner can withdraw.
    
    // Aave's ERC20 Token addresses on Sepolia (Not-Goerli) network
    address private immutable daiAddress =
        0x68194a729C2450ad26072b3D33ADaCbcef39D574;
    address private immutable usdcAddress =
        0xda9d4f9b69ac6C22e444eD9aF0CfC043b7a7f53f;
    address private immutable dexContractAddress =
        0xB8De86Fce1BDE6e3D33CEb00C4e3F0c7D5C6752d; // the deployed FakeDex contract addr

    IERC20 private dai;
    IERC20 private usdc;
    IDex private dexContract;


    constructor (address _addressProvider) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider)) {
        owner = payable(msg.sender);

        // instantiate the new address of tokens & dex contracts in constructor
        dai = IERC20(daiAddress);
        usdc = IERC20(usdcAddress);
        dexContract = IDex(dexContractAddress);
    }
    
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool){
        // 
        // This contract now has the Funds requested
        //
        // Our CUSTOM logic goes here:
        // Arbitrage pperation
        dexContract.depositUSDC(1000000000); // 1000 USDC
        dexContract.buyDAI(); //bought Dai at discount, and transfer back to us.
        dexContract.depositDAI(dai.balanceOf(address(this))); // We deposited the DAI we had, back into the Dex contract, to facilitate selling,
        dexContract.sellDAI(); // Sell those DAI, into more USDC, and now we have more than enough USDC to pay for it.
        
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

    /// Some methods for the USDC & DAI tokens
    // There is one additional step before we request out loan, we need to approve some USDC and DAI,
    // so that the Dex contract can pull those amounts for our deposit
    // UNFORTUNATELY, we cannot do all in one step ? (cuz these approvals need to be available on the blockchain, before any of these functions run)
    // so that adds one extra step to the process.
    // But good news is we don't need to hold those funds, in order to approve them.
    // (e.g, we can have a balance of 0 USDC, and put through an approval of 1000(> 0), or whatever we intend to borrow )
    function approveUSDC(uint256 _amount) external returns (bool) {
        return usdc.approve(dexContractAddress, _amount);
    }

    function allowanceUSDC() external view returns (uint256) {
        return usdc.allowance(address(this), dexContractAddress);
    }

    function approveDAI(uint256 _amount) external returns (bool) {
        return dai.approve(dexContractAddress, _amount);
    }

    function allowanceDAI() external view returns (uint256) {
        return dai.allowance(address(this), dexContractAddress);
    }

    receive() external payable {}

}