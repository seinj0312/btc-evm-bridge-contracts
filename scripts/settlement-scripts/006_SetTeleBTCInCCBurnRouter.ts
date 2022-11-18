import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import { ethers } from "hardhat";
import { BigNumber, BigNumberish } from "ethers";
const logger = require('node-color-log');

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {deployments, getNamedAccounts, network} = hre;
    const {deploy, log} = deployments;
    const { deployer } = await getNamedAccounts();

    logger.color('blue').log("-------------------------------------------------")
    logger.color('blue').bold().log("Set teleBTC in CC burn...")

    const teleBTC = await deployments.get("TeleBTC")
    const ccBurnRouter = await deployments.get("CCBurnRouter")

    const ccBurnRouterFactory = await ethers.getContractFactory("CCBurnRouter");
    const ccBurnRouterInstance = await ccBurnRouterFactory.attach(
        ccBurnRouter.address
    );

    const setTeleBTCTx = await ccBurnRouterInstance.setTeleBTC(
        teleBTC.address
    )

    await setTeleBTCTx.wait(1)
    console.log("set telebtc in CC burn: ", setTeleBTCTx.hash)

};

export default func;
// func.tags = ["PriceOracle", "BitcoinTestnet"];
