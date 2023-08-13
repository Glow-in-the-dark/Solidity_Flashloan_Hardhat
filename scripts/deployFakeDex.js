const hre = require("hardhat");

async function main() {
  const FakeDex = await hre.ethers.getContractFactory("Dex"); //<< put in the Contract Name.

  // Deploy Dex contract with the arguments for the contructor.
  const fakeDex = await FakeDex.deploy();

  await fakeDex.deployed();
  console.log("FakeDex Contract deployed: ", fakeDex.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
