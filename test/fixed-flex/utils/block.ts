import {ethers} from "hardhat";

async function mineBlocks(count = BigInt(1)) {
    const provider = ethers.provider;

    for (let i = 0; i < count; i++) {
        await provider.send("evm_mine");
    }
}

export {mineBlocks}
