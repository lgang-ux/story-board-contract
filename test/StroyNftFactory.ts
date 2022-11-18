import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("StroyNftFactory", function () {
  let  StroyNftFactory:any;
  let  stroyNftFactory:any;
  let  StroyNft:any;
  let  stroyNft:any;
  let  owner:any;
  let  addr1:any;

  beforeEach(async function () {
    console.log("==========================");
    StroyNftFactory = await ethers.getContractFactory("StroyNftFactory");
    stroyNftFactory = await StroyNftFactory.deploy();
    await stroyNftFactory.deployed();
    console.log(`deployed to ${stroyNftFactory.address}`);
    [owner,addr1]= await ethers.getSigners();
    StroyNft = await ethers.getContractFactory("StroyNft");
    
    
  });
  
  describe("StroyNftFactory  test",async function () {
    it("createNft", async function () {
       await  stroyNftFactory.createNft("8848","test","test",0);
       const ower= await  stroyNftFactory.getNftOwner("8848");
       const nftAddress =  await  stroyNftFactory.getNftAddress("8848");
       console.log(`createNft to nftAddress ${nftAddress} `);
       stroyNftFactory.safeMint(nftAddress,addr1.address,8848,"1212");
       const  num= await stroyNftFactory.balanceOf(addr1.address);
       console.log(`balanceOf ${addr1.address} => ${num} `);
       //stroyNft =StroyNft.connect(nftAddress,owner);
    });


  //   it("mint nft", async function () {
  //     // const price =await stroyNft.getPrice();
  //     // console.log(`createNft to price ${price} `);
  //  });


  })
});
