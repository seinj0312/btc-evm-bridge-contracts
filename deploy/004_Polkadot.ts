import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import { BigNumber, BigNumberish } from "ethers";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {deployments, getNamedAccounts} = hre;
    const {deploy} = deployments;
    const { deployer } = await getNamedAccounts();

    const tokenName = "Polkadot"
    const tokenSymbol = "DOT"
    const initialSupply = BigNumber.from(10).pow(18).mul(100000)

    await deploy("ERC20AsDot", {
        from: deployer,
        log: true,
        skipIfAlreadyDeployed: true,
        args: [
            tokenName,
            tokenSymbol,
            initialSupply
        ],
    });
};

export default func;
func.tags = ["ERC20AsDot"];
