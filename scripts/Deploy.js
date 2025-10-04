//constructor(string memory name, string memory version,address _distributionSC, uint256 _commissionRate)
const {ethers,run}=  require("hardhat");
require("dotenv").config();

async function main(){
    const name  = "RecipientHandler";
    const version = "1";
    const distributionSC =  "0xaA9DF6B11026a77562A0FC4EF4Bd1d91C9f05998";
    const commissionRate = 3000;  //30%
    const args  = [name,version,distributionSC,commissionRate];
    const factory = await ethers.getContractFactory("RecipientHandler");
    const contract = await factory.deploy(...args);
    await contract.waitForDeployment();
    console.log("Contract deployed to:", contract.target);
    await run("verify:verify",{
        address : contract.target,
        constructorArguments: args,
    });
    console.log("Verified:", await factory.getAddress())
}

main().catch((error)=>{
    console.error(error);
    process.exitCode=1;
})