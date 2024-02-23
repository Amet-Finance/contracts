import {ethers} from "hardhat";

function generateWallet() {
    return ethers.Wallet.createRandom();
}

export {
    generateWallet
}
