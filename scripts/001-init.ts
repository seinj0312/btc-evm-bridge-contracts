import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from "hardhat";
import { BitcoinInterface } from '@teleportdao/bitcoin';
import config from 'config';
const logger = require('node-color-log');

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments } = hre;

    const bitcoinNetwork = config.get("bitcoin_network");
    const finalizationParameter = config.get("finalizationParameter");
    const relayerPercentageFee = config.get("relayerPercentageFee");
    const submissionGasUsed = config.get("submissionGasUsed");

    const ZERO_ADD = "0x0000000000000000000000000000000000000000";
    let bitcoinRelayLogic;
    let BitcoinRelayLogicFactory;

    const bitcoinRelayProxy = await deployments.get("BitcoinRelayProxy");

    if (bitcoinNetwork == "mainnet") {
        bitcoinRelayLogic = await deployments.get("BitcoinRelayLogic");
        BitcoinRelayLogicFactory = await ethers.getContractFactory(
            "BitcoinRelayLogic"
        );
    } else {
        bitcoinRelayLogic = await deployments.get("BitcoinRelayLogicTestnet");
        BitcoinRelayLogicFactory = await ethers.getContractFactory(
            "BitcoinRelayLogicTestnet"
        );
    }

    const bitcoinRelayLogicInstance = await BitcoinRelayLogicFactory.attach(
        bitcoinRelayLogic.address
    );
    const bitcoinRelayProxyInstance = await BitcoinRelayLogicFactory.attach(
        bitcoinRelayProxy.address
    );

    const networkName = bitcoinNetwork == "mainnet" ? 'bitcoin' : 'bitcoin_testnet';
    const _bitcoinNetwork = {
        name: networkName,
        connection: {
            api: {
                enabled: true,
                provider: 'BlockStream',
                token: null,
            },
        },
    };
    const bitcoinInterface = new BitcoinInterface(
        _bitcoinNetwork.connection,
        _bitcoinNetwork.name
    );

    // note: NEVER START WITH 0! IT MAKES PROBLEM
    const lastHeight = await bitcoinInterface.getLatestBlockNumber();
    const genesisHeader = await bitcoinInterface.getBlockHeaderHex(lastHeight);
    const periodStartHeight = lastHeight - lastHeight % 2016;
    let periodStart = await bitcoinInterface.getBlockHash(periodStartHeight);
    periodStart = Buffer.from(periodStart , 'hex').reverse().toString('hex');

    logger.color('blue').log("-------------------------------------------------")
    logger.color('blue').bold().log("Initialize BitcoinRelayProxy ...")

    let _ownerProxy = await bitcoinRelayProxyInstance.owner();
    if (_ownerProxy == ZERO_ADD) {
        const initializeTxProxy = await bitcoinRelayProxyInstance.initialize(
            '0x' + genesisHeader,
            lastHeight,
            '0x' + periodStart,
            finalizationParameter,
            relayerPercentageFee,
            submissionGasUsed
        );
        await initializeTxProxy.wait(1);
        console.log("BitcoinRelayProxy initialized: ", initializeTxProxy.hash);
    } else {
        console.log("Already initialized")
    }

    logger.color('blue').log("-------------------------------------------------")
    logger.color('blue').bold().log("Initialize BitcoinRelayLogic ...")

    let _ownerLogic = await bitcoinRelayLogicInstance.owner();
    if (_ownerLogic == ZERO_ADD) {
        const initializeTxProxy = await bitcoinRelayLogicInstance.initialize(
            '0x' + genesisHeader,
            lastHeight,
            '0x' + periodStart,
            finalizationParameter,
            relayerPercentageFee,
            submissionGasUsed
        );
        await initializeTxProxy.wait(1);
        console.log("BitcoinRelayLogic initialized: ", initializeTxProxy.hash);
    } else {
        console.log("Already initialized")
    }
};

export default func;