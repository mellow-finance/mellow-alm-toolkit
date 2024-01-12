import hre from "hardhat";
import { expect } from "chai";
import { ethers, getNamedAccounts, deployments } from "hardhat";
import { BigNumber } from "@ethersproject/bignumber";
import {
    encodeToBytes,
    mint,
    mintUniV3Position_USDC_WETH,
    withSigner,
} from "../library/Helpers";
import { contract } from "../library/setup";
import { ERC20RootVault, ERC20Vault, UniV3Vault } from "../types";
import { combineVaults, setupVault } from "../../deploy/0000_utils";
import { ERC20 } from "../library/Types";
import { abi as INonfungiblePositionManager } from "@uniswap/v3-periphery/artifacts/contracts/interfaces/INonfungiblePositionManager.sol/INonfungiblePositionManager.json";
import { abi as ISwapRouter } from "@uniswap/v3-periphery/artifacts/contracts/interfaces/ISwapRouter.sol/ISwapRouter.json";

type CustomContext = {
    erc20Vault: ERC20Vault;
    erc20RootVault: ERC20RootVault;
    curveRouter: string;
    preparePush: (tickLower: number, tickUpper: number) => any;
};

type DeployOptions = {};

contract<UniV3Vault, DeployOptions, CustomContext>("UniV3Vault", function () {
    const uniV3PoolFee = 3000;

    before(async () => {
        this.deploymentFixture = deployments.createFixture(
            async (_, __?: DeployOptions) => {
                await deployments.fixture();
                const { read } = deployments;

                const {
                    uniswapV3PositionManager,
                    curveRouter,
                    uniswapV3Router,
                } = await getNamedAccounts();
                this.curveRouter = curveRouter;
                this.swapRouter = await ethers.getContractAt(
                    ISwapRouter,
                    uniswapV3Router
                );

                this.swapTokens = async (
                    senderAddress: string,
                    recipientAddress: string,
                    tokenIn: ERC20,
                    tokenOut: ERC20,
                    amountIn: BigNumber
                ) => {
                    await withSigner(senderAddress, async (senderSigner) => {
                        await tokenIn
                            .connect(senderSigner)
                            .approve(
                                this.swapRouter.address,
                                ethers.constants.MaxUint256
                            );
                        let params = {
                            tokenIn: tokenIn.address,
                            tokenOut: tokenOut.address,
                            fee: uniV3PoolFee,
                            recipient: recipientAddress,
                            deadline: ethers.constants.MaxUint256,
                            amountIn: amountIn,
                            amountOutMinimum: 0,
                            sqrtPriceLimitX96: 0,
                        };
                        await this.swapRouter
                            .connect(senderSigner)
                            .exactInputSingle(params);
                    });
                };

                this.positionManager = await ethers.getContractAt(
                    INonfungiblePositionManager,
                    uniswapV3PositionManager
                );

                this.preparePush = async (
                    tickLower: number,
                    tickUpper: number
                ) => {
                    const result = await mintUniV3Position_USDC_WETH({
                        fee: 3000,
                        tickLower: tickLower,
                        tickUpper: tickUpper,
                        usdcAmount: BigNumber.from(10).pow(6).mul(3000),
                        wethAmount: BigNumber.from(10).pow(18),
                    });
                    await this.positionManager.functions[
                        "safeTransferFrom(address,address,uint256)"
                    ](
                        this.deployer.address,
                        this.subject.address,
                        result.tokenId
                    );
                };

                const tokens = [this.weth.address, this.usdc.address]
                    .map((t) => t.toLowerCase())
                    .sort();

                const startNft =
                    (await read("VaultRegistry", "vaultsCount")).toNumber() + 1;

                let uniV3VaultNft = startNft;
                let erc20VaultNft = startNft + 1;

                this.uniV3Helper = await ethers.getContract("UniV3Helper");

                await setupVault(hre, uniV3VaultNft, "UniV3VaultGovernance", {
                    createVaultArgs: [
                        tokens,
                        this.deployer.address,
                        uniV3PoolFee,
                        this.uniV3Helper.address,
                    ],
                });
                await setupVault(hre, erc20VaultNft, "ERC20VaultGovernance", {
                    createVaultArgs: [tokens, this.deployer.address],
                });

                await combineVaults(
                    hre,
                    erc20VaultNft + 1,
                    [erc20VaultNft, uniV3VaultNft],
                    this.deployer.address,
                    this.deployer.address
                );
                const erc20Vault = await read(
                    "VaultRegistry",
                    "vaultForNft",
                    erc20VaultNft
                );
                const uniV3Vault = await read(
                    "VaultRegistry",
                    "vaultForNft",
                    uniV3VaultNft
                );
                const erc20RootVault = await read(
                    "VaultRegistry",
                    "vaultForNft",
                    erc20VaultNft + 1
                );

                this.erc20Vault = await ethers.getContractAt(
                    "ERC20Vault",
                    erc20Vault
                );

                this.subject = await ethers.getContractAt(
                    "UniV3Vault",
                    uniV3Vault
                );

                this.erc20RootVault = await ethers.getContractAt(
                    "ERC20RootVault",
                    erc20RootVault
                );

                for (let address of [
                    this.deployer.address,
                    this.subject.address,
                    this.erc20Vault.address,
                ]) {
                    await mint(
                        "USDC",
                        address,
                        BigNumber.from(10).pow(18).mul(3000)
                    );
                    await mint(
                        "WETH",
                        address,
                        BigNumber.from(10).pow(18).mul(3000)
                    );
                    await this.weth.approve(
                        address,
                        ethers.constants.MaxUint256
                    );
                    await this.usdc.approve(
                        address,
                        ethers.constants.MaxUint256
                    );
                }

                this.calculateTokensOwed = async () => {
                    const uniV3Nft = await this.subject.uniV3Nft();
                    let result: BigNumber[] = [];
                    await withSigner(this.subject.address, async (signer) => {
                        const positionManager = await ethers.getContractAt(
                            INonfungiblePositionManager,
                            await this.subject.positionManager()
                        );
                        result = await positionManager
                            .connect(signer)
                            .callStatic.collect({
                                tokenId: uniV3Nft,
                                recipient: this.subject.address,
                                amount0Max: BigNumber.from(2).pow(100),
                                amount1Max: BigNumber.from(2).pow(100),
                            });
                    });
                    return result;
                };

                this.getUniV3Tick = async () => {
                    let pool = await ethers.getContractAt(
                        "IUniswapV3Pool",
                        await this.subject.pool()
                    );

                    const currentState = await pool.slot0();
                    return BigNumber.from(currentState.tick);
                };

                this.checkCalculation = async () => {
                    const { amount0, amount1 } =
                        await this.calculateTokensOwed();
                    const positionInfo = await this.uniV3Helper.getFeesByNft(
                        await this.subject.uniV3Nft()
                    );
                    expect(amount0.sub(positionInfo.fees0).toNumber()).to.be.eq(
                        0
                    );
                    expect(amount1.sub(positionInfo.fees1).toNumber()).to.be.eq(
                        0
                    );
                };

                return this.subject;
            }
        );
    });

    beforeEach(async () => {
        await this.deploymentFixture();
        await mint(
            "USDC",
            this.subject.address,
            BigNumber.from(10).pow(6).mul(100_000)
        );
        await mint(
            "WETH",
            this.subject.address,
            BigNumber.from(10).pow(18).mul(500)
        );
        await mint(
            "WETH",
            this.deployer.address,
            BigNumber.from(10).pow(18).mul(4000)
        );
        await mint(
            "USDC",
            this.deployer.address,
            BigNumber.from(10).pow(6).mul(400_000)
        );

        const currentTick = await this.getUniV3Tick();
        let tickLower = currentTick.div(120).mul(120).toNumber() - 120;
        let tickUpper = tickLower + 240;

        await this.preparePush(tickLower, tickUpper);
        await this.subject.push(
            [this.usdc.address, this.weth.address],
            [BigNumber.from(10).pow(6).mul(1000), BigNumber.from(10).pow(18)],
            encodeToBytes(
                ["uint256", "uint256", "uint256"],
                [
                    ethers.constants.Zero,
                    ethers.constants.Zero,
                    ethers.constants.MaxUint256,
                ]
            )
        );
    });

    describe("integration test", () => {
        it("works correctly", async () => {
            await mint(
                "WETH",
                this.subject.address,
                BigNumber.from(10).pow(18).mul(4000)
            );
            await mint(
                "USDC",
                this.subject.address,
                BigNumber.from(10).pow(18).mul(1000)
            );
            await this.checkCalculation();
            await this.swapTokens(
                this.subject.address,
                this.subject.address,
                this.weth,
                this.usdc,
                BigNumber.from(10).pow(17)
            );
            await this.swapTokens(
                this.subject.address,
                this.subject.address,
                this.usdc,
                this.weth,
                BigNumber.from(10).pow(6).mul(100)
            );
            await this.checkCalculation();
            const nft = await this.subject.uniV3Nft();
            const position = await this.positionManager.positions(nft);
            let tickLower = position.tickLower;
            let tickUpper = position.tickUpper;
            await mintUniV3Position_USDC_WETH({
                fee: 3000,
                tickLower: tickLower,
                tickUpper: tickUpper,
                usdcAmount: BigNumber.from(10).pow(6).mul(3000),
                wethAmount: BigNumber.from(10).pow(18),
            });
            await this.checkCalculation();
            await this.swapTokens(
                this.subject.address,
                this.subject.address,
                this.usdc,
                this.weth,
                BigNumber.from(10).pow(6).mul(9000)
            );
            await this.checkCalculation();
        });
    });
});
