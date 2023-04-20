import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import config from 'config';
import verify from "../helper-functions";
import { BitcoinInterface } from '@teleportdao/bitcoin';

var path = require('path');
var fs = require('fs');
var tempFilePath = path.join(__dirname, '..', '.env');

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {deployments, getNamedAccounts, network} = hre;
    const {deploy} = deployments;
    const { deployer } = await getNamedAccounts();

    let bitcoinNetwork = config.get("bitcoin_network");
    let tdtToken = config.get("tdt_token");

    const networkName = bitcoinNetwork == "testnet" ? 'bitcoin' : 'bitcoin_testnet';
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
    let bitcoinInterface = new BitcoinInterface(
        _bitcoinNetwork.connection,
        _bitcoinNetwork.name
    );

    // Deploys BitcoinRelay
    // note: NEVER START WITH 0! IT MAKES PROBLEM
    let blockCount = await bitcoinInterface.getLatestBlockNumber();
    let height;
    if (blockCount > 5) {
        height = blockCount - 5;
    } else {
        height = blockCount;
    }

    let genesisHeader = await bitcoinInterface.getBlockHeaderHex(height);
    let periodStartHeight = height - height%2016;
    let periodStart = await bitcoinInterface.getBlockHeaderHex(periodStartHeight);
    periodStart = Buffer.from(periodStart , 'hex').reverse().toString('hex');

    var blockHeight = "BLOCK_HEIGHT=" + height + "\n";
    fs.appendFileSync(tempFilePath, blockHeight);

    let deployedContract;

    if (bitcoinNetwork == "mainnet") {
        deployedContract = await deploy("BitcoinRelay", {
            from: deployer,
            log: true,
            skipIfAlreadyDeployed: true,
            args: [
                '0x' + genesisHeader,
                height,
                '0x' + periodStart,
                tdtToken.address
            ],
        });
    } else {
        deployedContract = await deploy("BitcoinRelayTestnet", {
            from: deployer,
            log: true,
            skipIfAlreadyDeployed: true,
            args: [
                '0x' + genesisHeader,
                height,
                '0x' + periodStart,
                tdtToken.address
            ],
        });
    }

    if (network.name != "hardhat" && process.env.ETHERSCAN_API_KEY && process.env.VERIFY_OPTION == "1") {

        let theBlockHeight = await process.env.BLOCK_HEIGHT;
        let height = Number(theBlockHeight)
        let genesisHeader = await bitcoinInterface.getBlockHeaderHex(height);
        let periodStartHeight = height - height%2016;
        let periodStart = await bitcoinInterface.getBlockHeaderHex(periodStartHeight);
        periodStart = Buffer.from(periodStart , 'hex').reverse().toString('hex');

        if (bitcoinNetwork == "mainnet") {
            await verify(deployedContract.address, [
                '0x' + genesisHeader,
                height,
                '0x' + periodStart,
                tdtToken.address
            ], "contracts/relay/BitcoinRelay.sol:BitcoinRelay")
        } else {
            await verify(deployedContract.address, [
                '0x' + genesisHeader,
                height,
                '0x' + periodStart,
                tdtToken.address
            ], "contracts/relay/BitcoinRelayTestnet.sol:BitcoinRelayTestnet")
        }
        
    }
};

export default func;
func.tags = ["BitcoinRelay"];
