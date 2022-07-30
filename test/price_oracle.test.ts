import { expect } from "chai";
import { deployments, ethers } from "hardhat";
import { BigNumber, Signer} from "ethers";
import { deployMockContract, MockContract } from "@ethereum-waffle/mock-contract";

import { PriceOracle } from "../src/types/PriceOracle";
import { PriceOracle__factory } from "../src/types/factories/PriceOracle__factory";
import { ERC20 } from "../src/types/ERC20";
import { ERC20__factory } from "../src/types/factories/ERC20__factory";


import { takeSnapshot, revertProvider } from "./block_utils";

describe("PriceOracle", async () => {

    // Constants
    let ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

    // Accounts
    let deployer: Signer;
    let signer1: Signer;
    let deployerAddress: string;
    let signer1Address: string;

    // Contracts
    let priceOracle: PriceOracle;
    let erc20: ERC20;
    let _erc20: ERC20;

    // Mock contracts
    let mockPriceProxy: MockContract;

    let snapshotId: any;

    before(async () => {
        // Sets accounts
        [deployer, signer1] = await ethers.getSigners();
        deployerAddress = await deployer.getAddress();
        signer1Address = await signer1.getAddress();

        // Deploys erc20 contracts
        const erc20Factory = new ERC20__factory(deployer);
        erc20 = await erc20Factory.deploy(
            "TestToken",
            "TT",
            1000
        );
        _erc20 = await erc20Factory.deploy(
            "AnotherTestToken",
            "ATT",
            1000
        );
        
        // Deploys collateralPool contract
        const priceOracleFactory = new PriceOracle__factory(deployer);
        priceOracle = await priceOracleFactory.deploy();

        // Mocks price proxy contract
        const AggregatorV3InterfaceContract = await deployments.getArtifact(
            "AggregatorV3Interface"
        );
        mockPriceProxy = await deployMockContract(
            deployer,
            AggregatorV3InterfaceContract.abi
        );

    });

    async function mockFunctions(        
        roundID: number,
        price: number,
        startedAt: number,
        timeStamp: number,
        answeredInRound: number,
        decimals: number
    ): Promise<void> {
        await mockPriceProxy.mock.latestRoundData.returns(
            roundID,
            price,
            startedAt,
            timeStamp,
            answeredInRound
        );
        await mockPriceProxy.mock.decimals.returns(decimals);
    }

    describe("#addExchangeRouter", async () => {

        beforeEach(async() => {
            snapshotId = await takeSnapshot(signer1.provider);
        });

        afterEach(async() => {
            await revertProvider(signer1.provider, snapshotId);
        });

        it("", async function () {
 
        })

    });

    describe("#removeExchangeRouter", async () => {

        beforeEach(async() => {
            snapshotId = await takeSnapshot(signer1.provider);
        });

        afterEach(async() => {
            await revertProvider(signer1.provider, snapshotId);
        });

        it("", async function () {
 
        })

    });

    describe("#setPriceProxy", async () => {

        beforeEach(async() => {
            snapshotId = await takeSnapshot(signer1.provider);
        });

        afterEach(async() => {
            await revertProvider(signer1.provider, snapshotId);
        });

        it("Sets a price proxy", async function () {
            expect(
                await priceOracle.setPriceProxy(erc20.address, _erc20.address, mockPriceProxy.address)
            ).to.emit(priceOracle, 'SetPriceProxy')
        })

    });

    describe("#equivalentOutputAmountFromOracle", async () => {
        let roundID;
        let price: number;
        let startedAt;
        let timeStamp;
        let answeredInRound;
        let decimals;
        // ERC20 decimals
        let erc20Decimals;
        let _erc20Decimals;
        beforeEach(async() => {
            snapshotId = await takeSnapshot(signer1.provider);
        });

        afterEach(async() => {
            await revertProvider(signer1.provider, snapshotId);
        });

        it("Gets equal amount of output token when TT/ATT proxy has been set", async function () {
            let amountIn = 1000; // TT token
            roundID = 1;
            price = 123;
            startedAt = 1;
            timeStamp = 1;
            answeredInRound = 1;
            decimals = 2;
            erc20Decimals = 8;
            _erc20Decimals = 18;
            await priceOracle.setPriceProxy(erc20.address, _erc20.address, mockPriceProxy.address);
            await mockFunctions(roundID, price, startedAt, timeStamp, answeredInRound, decimals);

            expect(
                await priceOracle.equivalentOutputAmountFromOracle(
                    amountIn,
                    erc20Decimals,
                    _erc20Decimals, 
                    erc20.address, 
                    _erc20.address
                )
            ).to.equal(Math.floor(amountIn*price*Math.pow(10, _erc20Decimals - erc20Decimals - decimals)));
        })

        it("Gets equal amount of output token when decimals is zero", async function () {
            let amountIn = 1000;
            roundID = 1;
            price = 1234;
            startedAt = 1;
            timeStamp = 1;
            answeredInRound = 1;
            decimals = 0;
            erc20Decimals = 18;
            _erc20Decimals = 8;
            await priceOracle.setPriceProxy(erc20.address, _erc20.address, mockPriceProxy.address);
            await mockFunctions(roundID, price, startedAt, timeStamp, answeredInRound, decimals);
            expect(
                await priceOracle.equivalentOutputAmountFromOracle(
                    amountIn, 
                    erc20Decimals, 
                    _erc20Decimals, 
                    erc20.address, 
                    _erc20.address
                )
            ).to.equal(Math.floor(amountIn*price*Math.pow(10, _erc20Decimals - erc20Decimals - decimals)));
        })

        it("Gets equal amount of output token when ATT/TT proxy has been set", async function () {
            let amountIn = 1000; // TT token
            roundID = 1;
            price = 12345; // ATT/TT
            startedAt = 1;
            timeStamp = 1;
            answeredInRound = 1;
            decimals = 2;
            erc20Decimals = 18;
            _erc20Decimals = 8;
            await priceOracle.setPriceProxy(_erc20.address, erc20.address, mockPriceProxy.address);
            await mockFunctions(roundID, price, startedAt, timeStamp, answeredInRound, decimals);
            expect(
                await priceOracle.equivalentOutputAmountFromOracle(
                    amountIn, 
                    erc20Decimals, 
                    _erc20Decimals, 
                    erc20.address, 
                    _erc20.address
                )
            ).to.equal(Math.floor((amountIn*Math.pow(10, _erc20Decimals - erc20Decimals + decimals)/price)))
        })

        it("Reverts since one of the tokens doesn't exist", async function () {
            let amountIn = 1000;
            await expect(
                priceOracle.equivalentOutputAmountFromOracle(
                    amountIn, 
                    18, 
                    18, 
                    erc20.address, 
                    deployerAddress
                )
            ).to.revertedWith("PriceOracle: Price proxy does not exist");
        })

    });

    describe("#equivalentOutputAmountFromExchange", async () => {

        beforeEach(async() => {
            snapshotId = await takeSnapshot(signer1.provider);
        });

        afterEach(async() => {
            await revertProvider(signer1.provider, snapshotId);
        });

        it("", async function () {
 
        })

    });

    describe("#equivalentOutputAmount", async () => {

        beforeEach(async() => {
            snapshotId = await takeSnapshot(signer1.provider);
        });

        afterEach(async() => {
            await revertProvider(signer1.provider, snapshotId);
        });

        it("", async function () {
 
        })

    });

});