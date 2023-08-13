const hre = require("hardhat");

async function main() {
  const FlashLoan = await hre.ethers.getContractFactory("FlashLoan"); //<< put in the Contract Name.

  // Deploy FlashLoan contract with the arguments for the contructor.
  const flashLoan = await FlashLoan.deploy(
    "0x0496275d34753A48320CA58103d5220d394FF77F"
  ); // Address of "PoolAddressProvider-Aave" (Of Testnet) https://docs.aave.com/developers/deployed-contracts/v3-testnet-addresses

  await flashLoan.deployed();
  console.log("Flash Loan Contract deployed: ", flashLoan.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
