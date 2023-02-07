import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import config from 'config'
import verify from "../helper-functions"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {deployments, getNamedAccounts, network} = hre;
    const {deploy} = deployments;
    const { deployer } = await getNamedAccounts();

    const acceptableDelay = config.get("acceptable_delay");
    const tntToken = config.get("wrapped_matic")

    const deployedContract = await deploy("PriceOracle", {
        from: deployer,
        log: true,
        skipIfAlreadyDeployed: true,
        args: [
            acceptableDelay,
            tntToken
        ],
    });

    if (network.name != "hardhat" && process.env.ETHERSCAN_API_KEY && process.env.VERIFY_OPTION == "1") {
        await verify(deployedContract.address, [
            acceptableDelay,
            tntToken
        ], "contracts/oracle/PriceOracle.sol:PriceOracle")
    }
};

export default func;
func.tags = ["PriceOracle"];
