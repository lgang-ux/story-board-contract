import { ethers } from "hardhat";

async function main() {
  const StroyNftFactory = await ethers.getContractFactory("StroyNftFactory");
  const stroyNftFactory = await StroyNftFactory.deploy();
  await stroyNftFactory.deployed();
  console.log(`deployed to ${stroyNftFactory.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
