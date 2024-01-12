import { expect } from "chai";
import { ethers, deployments } from "hardhat";
import {
    encodeToBytes,
    generateSingleParams,
    randomAddress,
    sleep,
    withSigner,
} from "./library/Helpers";
import { contract } from "./library/setup";
import { UniV3Validator } from "./types";
import { PermissionIdsLibrary } from "../deploy/0000_utils";
import { ValidatorBehaviour } from "./behaviors/validator";
import Exceptions from "./library/Exceptions";
import { randomBytes } from "crypto";
import { uint256, uint8 } from "./library/property";
import { ContractMetaBehaviour } from "./behaviors/contractMeta";

type CustomContext = {};

type DeployOptions = {};

contract<UniV3Validator, DeployOptions, CustomContext>(
    "UniV3Validator",
    function () {
        const EXACT_INPUT_SINGLE_SELECTOR = "0x414bf389";
        const EXACT_INPUT_SELECTOR = "0xc04b8d59";
        const EXACT_OUTPUT_SINGLE_SELECTOR = "0xdb3e2198";
        const EXACT_OUTPUT_SELECTOR = "0xf28c0498";

        before(async () => {
            this.deploymentFixture = deployments.createFixture(
                async (_, __?: DeployOptions) => {
                    await deployments.fixture();
                    const { address } = await deployments.get("UniV3Validator");
                    this.subject = await ethers.getContractAt(
                        "UniV3Validator",
                        address
                    );
                    this.swapRouterAddress = await this.subject.swapRouter();

                    const vaultTokens = [this.dai.address, this.usdc.address];
                    let vaultOwner = randomAddress();
                    const { vault } = await this.erc20VaultGovernance
                        .connect(this.admin)
                        .callStatic.createVault(vaultTokens, vaultOwner);
                    await this.erc20VaultGovernance
                        .connect(this.admin)
                        .createVault(vaultTokens, vaultOwner);
                    this.vault = await ethers.getContractAt(
                        "ERC20Vault",
                        vault
                    );
                    this.uniswapV3Factory = await ethers.getContractAt(
                        "IUniswapV3Factory",
                        await this.subject.factory()
                    );
                    this.fee = 3000;
                    return this.subject;
                }
            );
        });

        beforeEach(async () => {
            await this.deploymentFixture();
        });

        describe("#validate", () => {
            describe("edge cases:", async () => {
                describe("if addr is not swap", () => {
                    it(`reverts with ${Exceptions.INVALID_TARGET}`, async () => {
                        await withSigner(randomAddress(), async (signer) => {
                            await expect(
                                this.subject
                                    .connect(signer)
                                    .validate(
                                        randomAddress(),
                                        randomAddress(),
                                        generateSingleParams(uint256),
                                        randomBytes(4),
                                        randomBytes(32)
                                    )
                            ).to.be.revertedWith(Exceptions.INVALID_TARGET);
                        });
                    });
                });

                describe("if value is not zero", () => {
                    it(`reverts with ${Exceptions.INVALID_VALUE}`, async () => {
                        await withSigner(randomAddress(), async (signer) => {
                            await expect(
                                this.subject
                                    .connect(signer)
                                    .validate(
                                        randomAddress(),
                                        this.swapRouterAddress,
                                        generateSingleParams(uint256).add(1),
                                        randomBytes(4),
                                        randomBytes(32)
                                    )
                            ).to.be.revertedWith(Exceptions.INVALID_VALUE);
                        });
                    });
                });

                describe("if selector is wrong", () => {
                    it(`reverts with ${Exceptions.INVALID_SELECTOR}`, async () => {
                        await withSigner(randomAddress(), async (signer) => {
                            await expect(
                                this.subject
                                    .connect(signer)
                                    .validate(
                                        randomAddress(),
                                        this.swapRouterAddress,
                                        0,
                                        randomBytes(4),
                                        randomBytes(32)
                                    )
                            ).to.be.revertedWith(Exceptions.INVALID_SELECTOR);
                        });
                    });
                });
            });

            describe(`selector is ${EXACT_INPUT_SINGLE_SELECTOR}`, async () => {
                it("successful validate", async () => {
                    let pool = await this.uniswapV3Factory
                        .connect(this.admin)
                        .callStatic.getPool(
                            this.dai.address,
                            this.usdc.address,
                            this.fee
                        );
                    this.protocolGovernance
                        .connect(this.admin)
                        .stagePermissionGrants(pool, [
                            PermissionIdsLibrary.ERC20_APPROVE,
                        ]);
                    await sleep(
                        await this.protocolGovernance.governanceDelay()
                    );
                    this.protocolGovernance
                        .connect(this.admin)
                        .commitAllPermissionGrantsSurpassedDelay();
                    await withSigner(this.vault.address, async (signer) => {
                        await expect(
                            this.subject
                                .connect(signer)
                                .validate(
                                    randomAddress(),
                                    this.swapRouterAddress,
                                    0,
                                    EXACT_INPUT_SINGLE_SELECTOR,
                                    encodeToBytes(
                                        [
                                            "address",
                                            "address",
                                            "uint24",
                                            "address",
                                            "uint256",
                                            "uint256",
                                            "uint256",
                                            "uint160",
                                        ],
                                        [
                                            this.dai.address,
                                            this.usdc.address,
                                            this.fee,
                                            signer.address,
                                            generateSingleParams(uint256),
                                            generateSingleParams(uint256),
                                            generateSingleParams(uint256),
                                            generateSingleParams(uint8),
                                        ]
                                    )
                                )
                        ).to.not.be.reverted;
                    });
                });
                describe("edge cases:", async () => {
                    describe("if recipient is not sender", () => {
                        it(`reverts with ${Exceptions.INVALID_TARGET}`, async () => {
                            await withSigner(
                                randomAddress(),
                                async (signer) => {
                                    await expect(
                                        this.subject
                                            .connect(signer)
                                            .validate(
                                                randomAddress(),
                                                this.swapRouterAddress,
                                                0,
                                                EXACT_INPUT_SINGLE_SELECTOR,
                                                encodeToBytes(
                                                    [
                                                        "address",
                                                        "address",
                                                        "uint24",
                                                        "address",
                                                        "uint256",
                                                        "uint256",
                                                        "uint256",
                                                        "uint160",
                                                    ],
                                                    [
                                                        randomAddress(),
                                                        randomAddress(),
                                                        generateSingleParams(
                                                            uint8
                                                        ),
                                                        randomAddress(),
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint8
                                                        ),
                                                    ]
                                                )
                                            )
                                    ).to.be.revertedWith(
                                        Exceptions.INVALID_TARGET
                                    );
                                }
                            );
                        });
                    });

                    describe("if not a vault token", () => {
                        it(`reverts with ${Exceptions.INVALID_TOKEN}`, async () => {
                            await withSigner(
                                this.erc20RootVaultSingleton.address,
                                async (signer) => {
                                    await expect(
                                        this.subject
                                            .connect(signer)
                                            .validate(
                                                randomAddress(),
                                                this.swapRouterAddress,
                                                0,
                                                EXACT_INPUT_SINGLE_SELECTOR,
                                                encodeToBytes(
                                                    [
                                                        "address",
                                                        "address",
                                                        "uint24",
                                                        "address",
                                                        "uint256",
                                                        "uint256",
                                                        "uint256",
                                                        "uint160",
                                                    ],
                                                    [
                                                        randomAddress(),
                                                        randomAddress(),
                                                        generateSingleParams(
                                                            uint8
                                                        ),
                                                        signer.address,
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint8
                                                        ),
                                                    ]
                                                )
                                            )
                                    ).to.be.revertedWith(
                                        Exceptions.INVALID_TOKEN
                                    );
                                }
                            );
                        });
                    });

                    describe("if tokens are the same", () => {
                        it(`reverts with ${Exceptions.INVALID_TOKEN}`, async () => {
                            await withSigner(
                                this.vault.address,
                                async (signer) => {
                                    await expect(
                                        this.subject
                                            .connect(signer)
                                            .validate(
                                                randomAddress(),
                                                this.swapRouterAddress,
                                                0,
                                                EXACT_INPUT_SINGLE_SELECTOR,
                                                encodeToBytes(
                                                    [
                                                        "address",
                                                        "address",
                                                        "uint24",
                                                        "address",
                                                        "uint256",
                                                        "uint256",
                                                        "uint256",
                                                        "uint160",
                                                    ],
                                                    [
                                                        this.usdc.address,
                                                        this.usdc.address,
                                                        generateSingleParams(
                                                            uint8
                                                        ),
                                                        signer.address,
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint8
                                                        ),
                                                    ]
                                                )
                                            )
                                    ).to.be.revertedWith(
                                        Exceptions.INVALID_TOKEN
                                    );
                                }
                            );
                        });
                    });

                    describe("if pool has no permisson", () => {
                        it(`reverts with ${Exceptions.FORBIDDEN}`, async () => {
                            await withSigner(
                                this.vault.address,
                                async (signer) => {
                                    await expect(
                                        this.subject
                                            .connect(signer)
                                            .validate(
                                                randomAddress(),
                                                this.swapRouterAddress,
                                                0,
                                                EXACT_INPUT_SINGLE_SELECTOR,
                                                encodeToBytes(
                                                    [
                                                        "address",
                                                        "address",
                                                        "uint24",
                                                        "address",
                                                        "uint256",
                                                        "uint256",
                                                        "uint256",
                                                        "uint160",
                                                    ],
                                                    [
                                                        this.dai.address,
                                                        this.usdc.address,
                                                        generateSingleParams(
                                                            uint8
                                                        ),
                                                        signer.address,
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint8
                                                        ),
                                                    ]
                                                )
                                            )
                                    ).to.be.revertedWith(Exceptions.FORBIDDEN);
                                }
                            );
                        });
                    });
                });
            });

            describe(`selector is ${EXACT_OUTPUT_SINGLE_SELECTOR}`, async () => {
                it("successfull validate", async () => {
                    let pool = await this.uniswapV3Factory
                        .connect(this.admin)
                        .callStatic.getPool(
                            this.dai.address,
                            this.usdc.address,
                            this.fee
                        );
                    this.protocolGovernance
                        .connect(this.admin)
                        .stagePermissionGrants(pool, [
                            PermissionIdsLibrary.ERC20_APPROVE,
                        ]);
                    await sleep(
                        await this.protocolGovernance.governanceDelay()
                    );
                    this.protocolGovernance
                        .connect(this.admin)
                        .commitAllPermissionGrantsSurpassedDelay();
                    await withSigner(this.vault.address, async (signer) => {
                        await expect(
                            this.subject
                                .connect(signer)
                                .validate(
                                    randomAddress(),
                                    this.swapRouterAddress,
                                    0,
                                    EXACT_OUTPUT_SINGLE_SELECTOR,
                                    encodeToBytes(
                                        [
                                            "address",
                                            "address",
                                            "uint24",
                                            "address",
                                            "uint256",
                                            "uint256",
                                            "uint256",
                                            "uint160",
                                        ],
                                        [
                                            this.dai.address,
                                            this.usdc.address,
                                            this.fee,
                                            signer.address,
                                            generateSingleParams(uint256),
                                            generateSingleParams(uint256),
                                            generateSingleParams(uint256),
                                            generateSingleParams(uint8),
                                        ]
                                    )
                                )
                        ).to.not.be.reverted;
                    });
                });

                describe("edge cases:", async () => {
                    describe("if recipient is not sender", () => {
                        it(`reverts with ${Exceptions.INVALID_TARGET}`, async () => {
                            await withSigner(
                                randomAddress(),
                                async (signer) => {
                                    await expect(
                                        this.subject
                                            .connect(signer)
                                            .validate(
                                                randomAddress(),
                                                this.swapRouterAddress,
                                                0,
                                                EXACT_OUTPUT_SINGLE_SELECTOR,
                                                encodeToBytes(
                                                    [
                                                        "address",
                                                        "address",
                                                        "uint24",
                                                        "address",
                                                        "uint256",
                                                        "uint256",
                                                        "uint256",
                                                        "uint160",
                                                    ],
                                                    [
                                                        randomAddress(),
                                                        randomAddress(),
                                                        generateSingleParams(
                                                            uint8
                                                        ),
                                                        randomAddress(),
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint8
                                                        ),
                                                    ]
                                                )
                                            )
                                    ).to.be.revertedWith(
                                        Exceptions.INVALID_TARGET
                                    );
                                }
                            );
                        });
                    });

                    describe("if not a vault token", () => {
                        it(`reverts with ${Exceptions.INVALID_TOKEN}`, async () => {
                            await withSigner(
                                this.erc20RootVaultSingleton.address,
                                async (signer) => {
                                    await expect(
                                        this.subject
                                            .connect(signer)
                                            .validate(
                                                randomAddress(),
                                                this.swapRouterAddress,
                                                0,
                                                EXACT_OUTPUT_SINGLE_SELECTOR,
                                                encodeToBytes(
                                                    [
                                                        "address",
                                                        "address",
                                                        "uint24",
                                                        "address",
                                                        "uint256",
                                                        "uint256",
                                                        "uint256",
                                                        "uint160",
                                                    ],
                                                    [
                                                        randomAddress(),
                                                        randomAddress(),
                                                        generateSingleParams(
                                                            uint8
                                                        ),
                                                        signer.address,
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint8
                                                        ),
                                                    ]
                                                )
                                            )
                                    ).to.be.revertedWith(
                                        Exceptions.INVALID_TOKEN
                                    );
                                }
                            );
                        });
                    });

                    describe("if tokens are the same", () => {
                        it(`reverts with ${Exceptions.INVALID_TOKEN}`, async () => {
                            await withSigner(
                                this.vault.address,
                                async (signer) => {
                                    await expect(
                                        this.subject
                                            .connect(signer)
                                            .validate(
                                                randomAddress(),
                                                this.swapRouterAddress,
                                                0,
                                                EXACT_OUTPUT_SINGLE_SELECTOR,
                                                encodeToBytes(
                                                    [
                                                        "address",
                                                        "address",
                                                        "uint24",
                                                        "address",
                                                        "uint256",
                                                        "uint256",
                                                        "uint256",
                                                        "uint160",
                                                    ],
                                                    [
                                                        this.usdc.address,
                                                        this.usdc.address,
                                                        generateSingleParams(
                                                            uint8
                                                        ),
                                                        signer.address,
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint8
                                                        ),
                                                    ]
                                                )
                                            )
                                    ).to.be.revertedWith(
                                        Exceptions.INVALID_TOKEN
                                    );
                                }
                            );
                        });
                    });

                    describe("if pool has no permisson", () => {
                        it(`reverts with ${Exceptions.FORBIDDEN}`, async () => {
                            await withSigner(
                                this.vault.address,
                                async (signer) => {
                                    await expect(
                                        this.subject
                                            .connect(signer)
                                            .validate(
                                                randomAddress(),
                                                this.swapRouterAddress,
                                                0,
                                                EXACT_OUTPUT_SINGLE_SELECTOR,
                                                encodeToBytes(
                                                    [
                                                        "address",
                                                        "address",
                                                        "uint24",
                                                        "address",
                                                        "uint256",
                                                        "uint256",
                                                        "uint256",
                                                        "uint160",
                                                    ],
                                                    [
                                                        this.dai.address,
                                                        this.usdc.address,
                                                        generateSingleParams(
                                                            uint8
                                                        ),
                                                        signer.address,
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint256
                                                        ),
                                                        generateSingleParams(
                                                            uint8
                                                        ),
                                                    ]
                                                )
                                            )
                                    ).to.be.revertedWith(Exceptions.FORBIDDEN);
                                }
                            );
                        });
                    });
                });
            });

            describe(`selector is ${EXACT_INPUT_SELECTOR}`, async () => {
                it("successfull validate", async () => {
                    let pool = await this.uniswapV3Factory
                        .connect(this.admin)
                        .callStatic.getPool(
                            this.dai.address,
                            this.usdc.address,
                            this.fee
                        );
                    this.protocolGovernance
                        .connect(this.admin)
                        .stagePermissionGrants(pool, [
                            PermissionIdsLibrary.ERC20_APPROVE,
                        ]);
                    await sleep(
                        await this.protocolGovernance.governanceDelay()
                    );
                    this.protocolGovernance
                        .connect(this.admin)
                        .commitAllPermissionGrantsSurpassedDelay();
                    let path = Buffer.concat([
                        Buffer.from(this.dai.address.slice(2), "hex"),
                        Buffer.from("000bb8", "hex"),
                        Buffer.from(this.usdc.address.slice(2), "hex"),
                    ]);
                    await withSigner(this.vault.address, async (signer) => {
                        let inputParams = {
                            path: path,
                            recipient: signer.address,
                            deadline: generateSingleParams(uint256),
                            amountIn: generateSingleParams(uint256),
                            amountOutMinimum: generateSingleParams(uint256),
                        };
                        await expect(
                            this.subject
                                .connect(signer)
                                .validate(
                                    randomAddress(),
                                    this.swapRouterAddress,
                                    0,
                                    EXACT_INPUT_SELECTOR,
                                    encodeToBytes(
                                        [
                                            "tuple(" +
                                                "bytes path, " +
                                                "address recipient, " +
                                                "uint256 deadline, " +
                                                "uint256 amountIn, " +
                                                "uint256 amountOutMinimum)",
                                        ],
                                        [inputParams]
                                    )
                                )
                        ).to.not.be.reverted;
                    });
                });
                describe("edge cases:", async () => {
                    describe("if recipient is not sender", () => {
                        it(`reverts with ${Exceptions.INVALID_TARGET}`, async () => {
                            let inputParams = {
                                path: randomBytes(40),
                                recipient: randomAddress(),
                                deadline: generateSingleParams(uint256),
                                amountIn: generateSingleParams(uint256),
                                amountOutMinimum: generateSingleParams(uint256),
                            };
                            await withSigner(
                                randomAddress(),
                                async (signer) => {
                                    await expect(
                                        this.subject
                                            .connect(signer)
                                            .validate(
                                                randomAddress(),
                                                this.swapRouterAddress,
                                                0,
                                                EXACT_INPUT_SELECTOR,
                                                encodeToBytes(
                                                    [
                                                        "tuple(" +
                                                            "bytes path, " +
                                                            "address recipient, " +
                                                            "uint256 deadline, " +
                                                            "uint256 amountIn, " +
                                                            "uint256 amountOutMinimum)",
                                                    ],
                                                    [inputParams]
                                                )
                                            )
                                    ).to.be.revertedWith(
                                        Exceptions.INVALID_TARGET
                                    );
                                }
                            );
                        });
                    });

                    describe("if tokens are the same", () => {
                        it(`reverts with ${Exceptions.INVALID_TOKEN}`, async () => {
                            let token = randomBytes(20);
                            await withSigner(
                                randomAddress(),
                                async (signer) => {
                                    let inputParams = {
                                        path: Buffer.concat([
                                            token,
                                            randomBytes(3),
                                            token,
                                        ]),
                                        recipient: signer.address,
                                        deadline: generateSingleParams(uint256),
                                        amountIn: generateSingleParams(uint256),
                                        amountOutMinimum:
                                            generateSingleParams(uint256),
                                    };
                                    await expect(
                                        this.subject
                                            .connect(signer)
                                            .validate(
                                                randomAddress(),
                                                this.swapRouterAddress,
                                                0,
                                                EXACT_INPUT_SELECTOR,
                                                encodeToBytes(
                                                    [
                                                        "tuple(" +
                                                            "bytes path, " +
                                                            "address recipient, " +
                                                            "uint256 deadline, " +
                                                            "uint256 amountIn, " +
                                                            "uint256 amountOutMinimum)",
                                                    ],
                                                    [inputParams]
                                                )
                                            )
                                    ).to.be.revertedWith(
                                        Exceptions.INVALID_TOKEN
                                    );
                                }
                            );
                        });
                    });

                    describe("if pool has no approve permission", () => {
                        it(`reverts with ${Exceptions.FORBIDDEN}`, async () => {
                            await withSigner(
                                randomAddress(),
                                async (signer) => {
                                    let inputParams = {
                                        path: randomBytes(43),
                                        recipient: signer.address,
                                        deadline: generateSingleParams(uint256),
                                        amountIn: generateSingleParams(uint256),
                                        amountOutMinimum:
                                            generateSingleParams(uint256),
                                    };
                                    await expect(
                                        this.subject
                                            .connect(signer)
                                            .validate(
                                                randomAddress(),
                                                this.swapRouterAddress,
                                                0,
                                                EXACT_INPUT_SELECTOR,
                                                encodeToBytes(
                                                    [
                                                        "tuple(" +
                                                            "bytes path, " +
                                                            "address recipient, " +
                                                            "uint256 deadline, " +
                                                            "uint256 amountIn, " +
                                                            "uint256 amountOutMinimum)",
                                                    ],
                                                    [inputParams]
                                                )
                                            )
                                    ).to.be.revertedWith(Exceptions.FORBIDDEN);
                                }
                            );
                        });
                    });

                    describe("if not a vault token", () => {
                        it(`reverts with ${Exceptions.INVALID_TOKEN}`, async () => {
                            let pool = await this.uniswapV3Factory
                                .connect(this.admin)
                                .callStatic.getPool(
                                    this.dai.address,
                                    this.weth.address,
                                    this.fee
                                );
                            this.protocolGovernance
                                .connect(this.admin)
                                .stagePermissionGrants(pool, [
                                    PermissionIdsLibrary.ERC20_APPROVE,
                                ]);
                            await sleep(
                                await this.protocolGovernance.governanceDelay()
                            );
                            this.protocolGovernance
                                .connect(this.admin)
                                .commitAllPermissionGrantsSurpassedDelay();
                            let path = Buffer.concat([
                                Buffer.from(this.dai.address.slice(2), "hex"),
                                Buffer.from("000bb8", "hex"),
                                Buffer.from(this.weth.address.slice(2), "hex"),
                            ]);
                            await withSigner(
                                this.vault.address,
                                async (signer) => {
                                    let inputParams = {
                                        path: path,
                                        recipient: signer.address,
                                        deadline: generateSingleParams(uint256),
                                        amountIn: generateSingleParams(uint256),
                                        amountOutMinimum:
                                            generateSingleParams(uint256),
                                    };
                                    await expect(
                                        this.subject
                                            .connect(signer)
                                            .validate(
                                                randomAddress(),
                                                this.swapRouterAddress,
                                                0,
                                                EXACT_INPUT_SELECTOR,
                                                encodeToBytes(
                                                    [
                                                        "tuple(" +
                                                            "bytes path, " +
                                                            "address recipient, " +
                                                            "uint256 deadline, " +
                                                            "uint256 amountIn, " +
                                                            "uint256 amountOutMinimum)",
                                                    ],
                                                    [inputParams]
                                                )
                                            )
                                    ).to.be.revertedWith(
                                        Exceptions.INVALID_TOKEN
                                    );
                                }
                            );
                        });
                    });
                });
            });

            describe(`selector is ${EXACT_OUTPUT_SELECTOR}`, async () => {
                it("successfull validate", async () => {
                    let pool = await this.uniswapV3Factory
                        .connect(this.admin)
                        .callStatic.getPool(
                            this.dai.address,
                            this.usdc.address,
                            this.fee
                        );
                    this.protocolGovernance
                        .connect(this.admin)
                        .stagePermissionGrants(pool, [
                            PermissionIdsLibrary.ERC20_APPROVE,
                        ]);
                    await sleep(
                        await this.protocolGovernance.governanceDelay()
                    );
                    this.protocolGovernance
                        .connect(this.admin)
                        .commitAllPermissionGrantsSurpassedDelay();
                    let path = Buffer.concat([
                        Buffer.from(this.dai.address.slice(2), "hex"),
                        Buffer.from("000bb8", "hex"),
                        Buffer.from(this.usdc.address.slice(2), "hex"),
                    ]);
                    await withSigner(this.vault.address, async (signer) => {
                        let inputParams = {
                            path: path,
                            recipient: signer.address,
                            deadline: generateSingleParams(uint256),
                            amountIn: generateSingleParams(uint256),
                            amountOutMinimum: generateSingleParams(uint256),
                        };
                        await expect(
                            this.subject
                                .connect(signer)
                                .validate(
                                    randomAddress(),
                                    this.swapRouterAddress,
                                    0,
                                    EXACT_OUTPUT_SELECTOR,
                                    encodeToBytes(
                                        [
                                            "tuple(" +
                                                "bytes path, " +
                                                "address recipient, " +
                                                "uint256 deadline, " +
                                                "uint256 amountIn, " +
                                                "uint256 amountOutMinimum)",
                                        ],
                                        [inputParams]
                                    )
                                )
                        ).to.not.be.reverted;
                    });
                });
                describe("edge cases:", async () => {
                    describe("if recipient is not sender", () => {
                        it(`reverts with ${Exceptions.INVALID_TARGET}`, async () => {
                            let inputParams = {
                                path: randomBytes(40),
                                recipient: randomAddress(),
                                deadline: generateSingleParams(uint256),
                                amountIn: generateSingleParams(uint256),
                                amountOutMinimum: generateSingleParams(uint256),
                            };
                            await withSigner(
                                randomAddress(),
                                async (signer) => {
                                    await expect(
                                        this.subject
                                            .connect(signer)
                                            .validate(
                                                randomAddress(),
                                                this.swapRouterAddress,
                                                0,
                                                EXACT_OUTPUT_SELECTOR,
                                                encodeToBytes(
                                                    [
                                                        "tuple(" +
                                                            "bytes path, " +
                                                            "address recipient, " +
                                                            "uint256 deadline, " +
                                                            "uint256 amountIn, " +
                                                            "uint256 amountOutMinimum)",
                                                    ],
                                                    [inputParams]
                                                )
                                            )
                                    ).to.be.revertedWith(
                                        Exceptions.INVALID_TARGET
                                    );
                                }
                            );
                        });
                    });

                    describe("if tokens are the same", () => {
                        it(`reverts with ${Exceptions.INVALID_TOKEN}`, async () => {
                            await withSigner(
                                randomAddress(),
                                async (signer) => {
                                    let token = randomBytes(20);
                                    let inputParams = {
                                        path: Buffer.concat([
                                            token,
                                            randomBytes(3),
                                            token,
                                        ]),
                                        recipient: signer.address,
                                        deadline: generateSingleParams(uint256),
                                        amountIn: generateSingleParams(uint256),
                                        amountOutMinimum:
                                            generateSingleParams(uint256),
                                    };
                                    await expect(
                                        this.subject
                                            .connect(signer)
                                            .validate(
                                                randomAddress(),
                                                this.swapRouterAddress,
                                                0,
                                                EXACT_OUTPUT_SELECTOR,
                                                encodeToBytes(
                                                    [
                                                        "tuple(" +
                                                            "bytes path, " +
                                                            "address recipient, " +
                                                            "uint256 deadline, " +
                                                            "uint256 amountIn, " +
                                                            "uint256 amountOutMinimum)",
                                                    ],
                                                    [inputParams]
                                                )
                                            )
                                    ).to.be.revertedWith(
                                        Exceptions.INVALID_TOKEN
                                    );
                                }
                            );
                        });
                    });

                    describe("if pool has no approve permission", () => {
                        it(`reverts with ${Exceptions.FORBIDDEN}`, async () => {
                            await withSigner(
                                randomAddress(),
                                async (signer) => {
                                    let inputParams = {
                                        path: randomBytes(43),
                                        recipient: signer.address,
                                        deadline: generateSingleParams(uint256),
                                        amountIn: generateSingleParams(uint256),
                                        amountOutMinimum:
                                            generateSingleParams(uint256),
                                    };
                                    await expect(
                                        this.subject
                                            .connect(signer)
                                            .validate(
                                                randomAddress(),
                                                this.swapRouterAddress,
                                                0,
                                                EXACT_OUTPUT_SELECTOR,
                                                encodeToBytes(
                                                    [
                                                        "tuple(" +
                                                            "bytes path, " +
                                                            "address recipient, " +
                                                            "uint256 deadline, " +
                                                            "uint256 amountIn, " +
                                                            "uint256 amountOutMinimum)",
                                                    ],
                                                    [inputParams]
                                                )
                                            )
                                    ).to.be.revertedWith(Exceptions.FORBIDDEN);
                                }
                            );
                        });
                    });

                    describe("if not a vault token", () => {
                        it(`reverts with ${Exceptions.INVALID_TOKEN}`, async () => {
                            let pool = await this.uniswapV3Factory
                                .connect(this.admin)
                                .callStatic.getPool(
                                    this.dai.address,
                                    this.weth.address,
                                    this.fee
                                );
                            this.protocolGovernance
                                .connect(this.admin)
                                .stagePermissionGrants(pool, [
                                    PermissionIdsLibrary.ERC20_APPROVE,
                                ]);
                            await sleep(
                                await this.protocolGovernance.governanceDelay()
                            );
                            this.protocolGovernance
                                .connect(this.admin)
                                .commitAllPermissionGrantsSurpassedDelay();
                            let path = Buffer.concat([
                                Buffer.from(this.dai.address.slice(2), "hex"),
                                Buffer.from("000bb8", "hex"),
                                Buffer.from(this.weth.address.slice(2), "hex"),
                            ]);
                            await withSigner(
                                this.vault.address,
                                async (signer) => {
                                    let inputParams = {
                                        path: path,
                                        recipient: signer.address,
                                        deadline: generateSingleParams(uint256),
                                        amountIn: generateSingleParams(uint256),
                                        amountOutMinimum:
                                            generateSingleParams(uint256),
                                    };
                                    await expect(
                                        this.subject
                                            .connect(signer)
                                            .validate(
                                                randomAddress(),
                                                this.swapRouterAddress,
                                                0,
                                                EXACT_OUTPUT_SELECTOR,
                                                encodeToBytes(
                                                    [
                                                        "tuple(" +
                                                            "bytes path, " +
                                                            "address recipient, " +
                                                            "uint256 deadline, " +
                                                            "uint256 amountIn, " +
                                                            "uint256 amountOutMinimum)",
                                                    ],
                                                    [inputParams]
                                                )
                                            )
                                    ).to.be.revertedWith(
                                        Exceptions.INVALID_TOKEN
                                    );
                                }
                            );
                        });
                    });
                });
            });
        });

        ValidatorBehaviour.call(this, {});
        ContractMetaBehaviour.call(this, {
            contractName: "UniV3Validator",
            contractVersion: "1.0.0",
        });
    }
);
