import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "solidity-coverage";
import "hardhat-contract-sizer";
import "hardhat-deploy";
import "./plugins/contracts";
import { config as dotenv } from "dotenv";
import "./tasks/verify";

dotenv();

const config: HardhatUserConfig = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            forking: process.env["MAINNET_RPC"]
                ? {
                      url: process.env["MAINNET_RPC"],
                      blockNumber: 15000000,
                  }
                : undefined,

            accounts:
                process.env["MAINNET_DEPLOYER_PK"] &&
                process.env["MAINNET_APPROVER_PK"]
                    ? [
                          {
                              privateKey: process.env["MAINNET_DEPLOYER_PK"],
                              balance: (10 ** 20).toString(),
                          },
                          {
                              privateKey: process.env["MAINNET_APPROVER_PK"],
                              balance: (10 ** 20).toString(),
                          },
                      ]
                    : undefined,
        },
        localhost: {
            url: "http://localhost:8545",
        },
        kovan: {
            url:
                process.env["KOVAN_RPC"] ||
                "https://kovan.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
            accounts:
                process.env["KOVAN_DEPLOYER_PK"] &&
                process.env["KOVAN_APPROVER_PK"]
                    ? [
                          process.env["KOVAN_DEPLOYER_PK"],
                          process.env["KOVAN_APPROVER_PK"],
                      ]
                    : undefined,
        },
        rinkeby: {
            url:
                process.env["RINKEBY_RPC"] ||
                "https://rinkeby-light.eth.linkpool.io",
            accounts:
                process.env["RINKEBY_DEPLOYER_PK"] &&
                process.env["RINKEBY_APPROVER_PK"]
                    ? [
                          process.env["RINKEBY_DEPLOYER_PK"],
                          process.env["RINKEBY_APPROVER_PK"],
                      ]
                    : undefined,
        },
        mainnet: {
            url: process.env["MAINNET_RPC"],
            accounts:
                process.env["MAINNET_DEPLOYER_PK"] &&
                process.env["MAINNET_APPROVER_PK"]
                    ? [
                          process.env["MAINNET_DEPLOYER_PK"],
                          process.env["MAINNET_APPROVER_PK"],
                      ]
                    : undefined,
        },
        avalanche: {
            url:
                process.env["AVALANCHE_RPC"] ||
                "https://api.avax.network/ext/bc/C/rpc",
            accounts:
                process.env["AVALANCHE_DEPLOYER_PK"] &&
                process.env["AVALANCHE_APPROVER_PK"]
                    ? [
                          process.env["AVALANCHE_DEPLOYER_PK"],
                          process.env["AVALANCHE_APPROVER_PK"],
                      ]
                    : undefined,
            chainId: 43114,
        },
        polygon: {
            url: process.env["POLYGON_RPC"] || "https://polygon-rpc.com",
            accounts:
                process.env["POLYGON_DEPLOYER_PK"] &&
                process.env["POLYGON_APPROVER_PK"]
                    ? [
                          process.env["POLYGON_DEPLOYER_PK"],
                          process.env["POLYGON_APPROVER_PK"],
                      ]
                    : undefined,
            chainId: 137,
        },

        bsc: {
            url: process.env["BSC_RPC"] || "https://bsc-dataseed.binance.org",
            accounts:
                process.env["BSC_DEPLOYER_PK"] && process.env["BSC_APPROVER_PK"]
                    ? [
                          process.env["BSC_DEPLOYER_PK"],
                          process.env["BSC_APPROVER_PK"],
                      ]
                    : undefined,
            chainId: 56,
        },
        fantom: {
            url: process.env["FANTOM_RPC"] || "https://rpc.ftm.tools",
            accounts:
                process.env["FANTOM_DEPLOYER_PK"] &&
                process.env["FANTOM_APPROVER_PK"]
                    ? [
                          process.env["FANTOM_DEPLOYER_PK"],
                          process.env["FANTOM_APPROVER_PK"],
                      ]
                    : undefined,
            chainId: 250,
        },

        arbitrum: {
            url: process.env["ARBITRUM_RPC"] || "https://arb1.arbitrum.io/rpc",
            accounts:
                process.env["ARBITRUM_DEPLOYER_PK"] &&
                process.env["ARBITRUM_APPROVER_PK"]
                    ? [
                          process.env["ARBITRUM_DEPLOYER_PK"],
                          process.env["ARBITRUM_APPROVER_PK"],
                      ]
                    : undefined,
            chainId: 42161,
        },
        optimism: {
            url: process.env["OPTIMISM_RPC"] || "https://mainnet.optimism.io",
            accounts:
                process.env["OPTIMISM_DEPLOYER_PK"] &&
                process.env["OPTIMISM_APPROVER_PK"]
                    ? [
                          process.env["OPTIMISM_DEPLOYER_PK"],
                          process.env["OPTIMISM_APPROVER_PK"],
                      ]
                    : undefined,
            chainId: 10,
        },
        xdai: {
            url: process.env["XDAI_RPC"] || "https://rpc.xdaichain.com",
            accounts:
                process.env["XDAI_DEPLOYER_PK"] &&
                process.env["XDAI_APPROVER_PK"]
                    ? [
                          process.env["XDAI_DEPLOYER_PK"],
                          process.env["XDAI_APPROVER_PK"],
                      ]
                    : undefined,
            chainId: 100,
        },
    },
    namedAccounts: {
        deployer: {
            default: 0,
        },
        approver: {
            default: 1,
        },
        admin: {
            hardhat: "0x9a3CB5A473e1055a014B9aE4bc63C21BBb8b82B3",
            mainnet: process.env["MAINNET_PROTOCOL_ADMIN_ADDRESS"] || "0x0",
            kovan: process.env["KOVAN_PROTOCOL_ADMIN_ADDRESS"] || "0x0",
            avalanche: process.env["AVALANCHE_PROTOCOL_ADMIN_ADDRESS"] || "0x0",
            polygon: process.env["POLYGON_PROTOCOL_ADMIN_ADDRESS"] || "0x0",
            rinkeby: process.env["RINKEBY_PROTOCOL_ADMIN_ADDRESS"] || "0x0",
            arbitrum: process.env["ARBITRUM_PROTOCOL_ADMIN_ADDRESS"] || "0x0",
            optimism: process.env["OPTIMISM_PROTOCOL_ADMIN_ADDRESS"] || "0x0",
        },
        mStrategyAdmin: {
            hardhat: "0x1aD91ee08f21bE3dE0BA2ba6918E714dA6B45836",
            mainnet: process.env["MAINNET_STRATEGY_ADMIN_ADDRESS"] || "0x0",
            kovan: process.env["KOVAN_STRATEGY_ADMIN_ADDRESS"] || "0x0",
            avalanche: process.env["AVALANCHE_STRATEGY_ADMIN_ADDRESS"] || "0x0",
            polygon: process.env["POLYGON_STRATEGY_ADMIN_ADDRESS"] || "0x0",
            rinkeby: process.env["RINKEBY_STRATEGY_ADMIN_ADDRESS"] || "0x0",
            arbitrum: process.env["ARBITRUM_STRATEGY_ADMIN_ADDRESS"] || "0x0",
            optimism: process.env["OPTIMISM_STRATEGY_ADMIN_ADDRESS"] || "0x0",
        },
        mStrategyTreasury: {
            hardhat: "0x52bc44d5378309EE2abF1539BF71dE1b7d7bE3b5",
            mainnet: process.env["MAINNET_STRATEGY_TREASURY_ADDRESS"] || "0x0",
            kovan: process.env["KOVAN_STRATEGY_TREASURY_ADDRESS"] || "0x0",
            avalanche:
                process.env["AVALANCHE_STRATEGY_TREASURY_ADDRESS"] || "0x0",
            polygon: process.env["POLYGON_STRATEGY_TREASURY_ADDRESS"] || "0x0",
            rinkeby: process.env["RINKEBY_STRATEGY_TREASURY_ADDRESS"] || "0x0",
            arbitrum:
                process.env["ARBITRUM_STRATEGY_TREASURY_ADDRESS"] || "0x0",
            optimism:
                process.env["OPTIMISM_STRATEGY_TREASURY_ADDRESS"] || "0x0",
        },
        protocolTreasury: {
            hardhat: "0x00192Fb10dF37c9FB26829eb2CC623cd1BF599E8",
            mainnet: process.env["MAINNET_PROTOCOL_TREASURY_ADDRESS"] || "0x0",
            kovan: process.env["KOVAN_PROTOCOL_TREASURY_ADDRESS"] || "0x0",
            avalanche:
                process.env["AVALANCHE_PROTOCOL_TREASURY_ADDRESS"] || "0x0",
            polygon: process.env["POLYGON_PROTOCOL_TREASURY_ADDRESS"] || "0x0",
            rinkeby: process.env["RINKEBY_PROTOCOL_TREASURY_ADDRESS"] || "0x0",
            arbitrum:
                process.env["ARBITRUM_PROTOCOL_TREASURY_ADDRESS"] || "0x0",
            optimism:
                process.env["OPTIMISM_PROTOCOL_TREASURY_ADDRESS"] || "0x0",
        },
        test: {
            default: "0x9a3CB5A473e1055a014B9aE4bc63C21BBb8b82B3",
        },
        yearnVaultRegistry: {
            default: "0x50c1a2eA0a861A967D9d0FFE2AE4012c2E053804",
            fantom: "0x41679043846d1B16b44FBf6E7FE531390e5bf092",
            arbitrum: "0x3199437193625DCcD6F9C9e98BDf93582200Eb1f",
        },
        // only for tests
        yearnWethPool: {
            default: "0xa258C4606Ca8206D8aA700cE2143D7db854D168c",
        },
        wbtc: {
            default: "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599",
            kovan: "0xd1b98b6607330172f1d991521145a22bce793277",
            avalanche: "0x50b7545627a5162f82a992c33b87adc75187b218",
            polygon: "0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6",
            fantom: "0x321162Cd933E2Be498Cd2267a90534A804051b11",
            bsc: "0xd47Ba9A00EB87B9E753c6651e402DAD7D9f1C4Ca",
            xdai: "0x8e5bBbb09Ed1ebdE8674Cda39A0c169401db4252",
            arbitrum: "0x2f2a2543b76a4166549f7aab2e75bef0aefc5b0f",
            optimism: "0x68f180fcce6836688e9084f035309e29bf0a2095",
            rinkeby: "0x577d296678535e4903d59a4c929b718e1d575e0a",
        },
        usdt: {
            default: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
        },
        usdc: {
            default: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
            kovan: "0xe22da380ee6b445bb8273c81944adeb6e8450422",
            avalanche: "0xa7d7079b0fead91f3e65f86e8915cb59c1a4c664",
            polygon: "0x2791bca1f2de4661ed88a30c99a7a9449aa84174",
            fantom: "0x04068da6c83afcfa0e13ba15a6696662335d5b75",
            bsc: "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d",
            xdai: "0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83",
            arbitrum: "0xff970a61a04b1ca14834a43f5de4533ebddb5cc8",
            optimism: "0x7f5c764cbc14f9669b88837ca1490cca17c31607",
            rinkeby: "0xeb8f08a975ab53e34d8a0330e0d34de942c95926",
        },
        weth: {
            default: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
            kovan: "0xd0a1e359811322d97991e03f863a0c30c2cf029c",
            avalanche: "0x49d5c2bdffac6ce2bfdb6640f4f80f226bc10bab",
            polygon: "0x7ceb23fd6bc0add59e62ac25578270cff1b9f619",
            fantom: "0x74b23882a30290451A17c44f4F05243b6b58C76d",
            xdai: "0x6A023CCd1ff6F2045C3309768eAd9E68F978f6e1",
            arbitrum: "0x82af49447d8a07e3bd95bd0d56f35241523fbab1",
            optimism: "0x4200000000000000000000000000000000000006",
            rinkeby: "0xc778417e063141139fce010982780140aa0cd5ab",
        },
        op: {
            optimism: "0x4200000000000000000000000000000000000042",
        },
        bob: {
            polygon: "0xB0B195aEFA3650A6908f15CdaC7D92F8a5791B0B",
            optimism: "0xB0B195aEFA3650A6908f15CdaC7D92F8a5791B0B",
        },
        stMatic: {
            polygon: "0x3a58a54c066fdc0f2d55fc9c89f0415c92ebf3c4",
        },
        wsteth: {
            default: "0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0",
            rinkeby: "0x2ca788280fb10384946d3ecc838d94deca505cf4",
        },
        aggregationRouterV5: {
            default: "0x1111111254eeb25477b68fb85ed929f73a960582",
        },
        dai: {
            default: "0x6b175474e89094c44da98b954eedeac495271d0f",
            kovan: "0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa",
            avalanche: "0xd586e7f844cea2f87f50152665bcbc2c279d8d70",
            polygon: "0x8f3cf7ad23cd3cadbd9735aff958023239c6a063",
            fantom: "0x8d11ec38a3eb5e956b052f67da8bdc9bef8abf3e",
            bsc: "0x334b3ecb4dca3593bccc3c7ebd1a1c1d1780fbf1",
            xdai: "0xFc8B2690F66B46fEC8B3ceeb95fF4Ac35a0054BC",
            arbitrum: "0xda10009cbd5d07dd0cecc66161fc93d7c9000da1",
            optimism: "0xda10009cbd5d07dd0cecc66161fc93d7c9000da1",
            rinkeby: "0x95b58a6bff3d14b7db2f5cb5f0ad413dc2940658",
        },
        aaveLendingPool: {
            default: "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9",
            kovan: "0xE0fBa4Fc209b4948668006B2bE61711b7f465bAe",
            polygon: "0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf",
            avalanche: "0x4F01AeD16D97E3aB5ab2B501154DC9bb0F1A5A2C",
        },
        algebraPositionManager: {
            polygon: "0x8eF88E4c7CfbbaC1C163f7eddd4B578792201de6",
        },
        kyberPositionManager: {
            polygon: "0x2B1c7b41f6A8F2b2bc45C3233a5d5FB3cD6dC9A8",
        },
        uniswapV3Factory: {
            default: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        },
        uniswapV3PositionManager: {
            default: "0xC36442b4a4522E871399CD717aBDD847Ab11FE88",
        },
        pancakeSwapRouter: {
            default: "0x13f4EA83D0bd40E75C8222255bc855a974568Dd4",
        },
        pancakePositionManager: {
            default: "0x46A15B0b27311cedF172AB29E4f4766fbE7F4364",
        },
        uniswapV3Router: {
            default: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
        },
        uniswapV2Factory: {
            default: "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f",
            kovan: "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f",
            avalanche: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
            polygon: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
            bsc: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
            fantom: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
            xdai: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
            arbitrum: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        },
        uniswapV2Router02: {
            default: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
            kovan: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
            avalanche: "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
            polygon: "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
            bsc: "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
            fantom: "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
            xdai: "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
            arbitrum: "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
        },
        chainlinkEth: {
            default: "0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419",
            kovan: "0x9326BFA02ADD2366b30bacB125260Af641031331",
            avalanche: "0x976B3D034E162d8bD72D6b9C989d545b839003b0",
            polygon: "0xF9680D99D6C9589e2a93a78A04A279e509205945",
            fantom: "0x11DdD3d147E5b83D01cee7070027092397d63658",
            bsc: "0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e",
            xdai: "0xa767f745331D267c7751297D982b050c93985627",
            arbitrum: "0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612",
            optimism: "0xA969bEB73d918f6100163Cd0fba3C586C269bee1",
            rinkeby: "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e",
        },
        chainlinkBtc: {
            default: "0xf4030086522a5beea4988f8ca5b36dbc97bee88c",
            kovan: "0x6135b13325bfC4B00278B4abC5e20bbce2D6580e",
            avalanche: "0x2779D32d5166BAaa2B2b658333bA7e6Ec0C65743",
            polygon: "0xc907E116054Ad103354f2D350FD2514433D57F6f",
            fantom: "0x8e94C22142F4A64b99022ccDd994f4e9EC86E4B4",
            bsc: "0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf",
            xdai: "0x6C1d7e76EF7304a40e8456ce883BC56d3dEA3F7d",
            arbitrum: "0x6ce185860a4963106506C203335A2910413708e9",
            optimism: "0xc326371d4D866C6Ff522E69298e36Fe75797D358",
            rinkeby: "0xECe365B379E1dD183B20fc5f022230C044d51404",
        },
        chainlinkUsdc: {
            default: "0x8fffffd4afb6115b954bd326cbe7b4ba576818f6",
            kovan: "0x9211c6b3BF41A10F78539810Cf5c64e1BB78Ec60",
            avalanche: "0xF096872672F44d6EBA71458D74fe67F9a77a23B9",
            polygon: "0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7",
            fantom: "0x2553f4eeb82d5A26427b8d1106C51499CBa5D99c",
            bsc: "0x51597f405303C4377E36123cBc172b13269EA163",
            xdai: "0x26C31ac71010aF62E6B486D1132E266D6298857D",
            arbitrum: "0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3",
            optimism: "0x",
            rinkeby: "0xa24de01df22b63d23Ebc1882a5E3d4ec0d907bFB",
        },
        cowswap: {
            default: "0x9008D19f58AAbD9eD0D60971565AA8510560ab41",
        },
        cowswapRelayer: {
            default: "0xC92E8bdf79f0507f65a392b0ab4667716BFE0110",
        },
        curveRouter: {
            default: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
        },
    },

    solidity: {
        compilers: [
            {
                version: "0.8.9",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                    evmVersion: "istanbul",
                },
            },
            {
                version: "0.7.6",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                    evmVersion: "istanbul",
                },
            },
        ],
    },
    etherscan: {
        apiKey: process.env["ETHERSCAN_API_KEY"],
    },
};

export default config;
