import assert from "assert";

import { TransactionReceipt, Log } from "@ethersproject/abstract-provider";
import { Signer } from "@ethersproject/abstract-signer";
import { AddressZero } from "@ethersproject/constants";
import { ContractTransaction, Overrides } from "@ethersproject/contracts";

import { TypedContract, TypedContractFactory } from "./typing";
import { fillConfig, LUSDChickenBondConfig } from "./config";

import {
  getContractFactories,
  LUSDChickenBondContractAddresses,
  LUSDChickenBondContracts,
  LUSDChickenBondArtworkContracts,
  mapContracts
} from "./contracts";

export interface LogFunction {
  (...args: unknown[]): void;
}

export interface LUSDChickenBondDeploymentParams {
  config: Partial<LUSDChickenBondConfig>;
  overrides: Overrides;
  log: boolean | LogFunction;
}

export interface LUSDChickenBondDeploymentManifest {
  chainId: number;
  addresses: LUSDChickenBondContractAddresses;
  // version: string; // TODO
  deploymentTimestamp: number;
  startBlock: number;
}

export interface DeployedContract<T extends TypedContract = TypedContract> {
  contractName: string;
  contract: T;
  receipt: TransactionReceipt;
}

export type LUSDChickenBondDeployedContracts = {
  [P in keyof LUSDChickenBondContracts]: DeployedContract<LUSDChickenBondContracts[P]>;
};

export type LUSDChickenBondArtworkDeployedContracts = {
  [P in keyof LUSDChickenBondArtworkContracts]: DeployedContract<LUSDChickenBondArtworkContracts[P]>;
};

export interface LUSDChickenBondDeploymentResult {
  deployed: LUSDChickenBondDeployedContracts;
  manifest: LUSDChickenBondDeploymentManifest;
  config: LUSDChickenBondConfig;
}

interface NamedFactory<T extends TypedContract, A extends unknown[]> {
  contractName: string;
  factory: TypedContractFactory<T, A>;
}

const getLogFunction = (x: boolean | LogFunction | undefined): LogFunction =>
  typeof x === "function" ? x : x ? console.log : () => {};

class LUSDChickenBondDeployment {
  private readonly deployer;
  private readonly factories;
  private readonly overrides;
  private readonly config;
  private readonly log;

  constructor(deployer: Signer, params?: Readonly<Partial<LUSDChickenBondDeploymentParams>>) {
    this.deployer = deployer;
    this.factories = getContractFactories(deployer);
    this.overrides = { ...params?.overrides };
    this.config = fillConfig(params?.config);
    this.log = getLogFunction(params?.log);
  }

  private async deployContract<T extends TypedContract, A extends unknown[]>(
    { contractName, factory }: NamedFactory<T, A>,
    ...args: A
  ): Promise<DeployedContract<T>> {
    const { log } = this;

    log(`Deploying ${contractName} ...`);
    const contract = await factory.deploy(...args);

    log(`Waiting for transaction ${contract.deployTransaction.hash} ...`);
    const receipt = await contract.deployTransaction.wait();

    log({
      contractAddress: contract.address,
      blockNumber: receipt.blockNumber,
      gasUsed: receipt.gasUsed.toNumber()
    });

    log();

    return { contractName, contract, receipt };
  }

  private async deployContractViaFactoryContract<T extends TypedContract>(
    { contractName, factory }: NamedFactory<T, unknown[]>,
    deployTransactionPromise: Promise<ContractTransaction>,
    extractDeployedContractAddress: (logs: Log[]) => string
  ): Promise<DeployedContract<T>> {
    const { log } = this;

    log(`Deploying ${contractName} via factory ...`);
    const deployTransaction = await deployTransactionPromise;

    log(`Waiting for transaction ${deployTransaction.hash} ...`);
    const receipt = await deployTransaction.wait();
    const contract = factory
      .connect(this.deployer)
      .attach(extractDeployedContractAddress(receipt.logs));

    log({
      contractAddress: contract.address,
      blockNumber: receipt.blockNumber,
      gasUsed: receipt.gasUsed.toNumber()
    });

    log();

    return { contractName, contract, receipt };
  }

  private async deployContracts(): Promise<LUSDChickenBondDeployedContracts> {
    const {
      factories,
      overrides,
      config: { yearnGovernanceAddress, ...params }
    } = this;

    const curveCryptoPoolImplementation = await this.deployContract(
      factories.curveCryptoPoolImplementation,
      AddressZero, // _weth
      overrides
    );

    const curveLiquidityGaugeImplementation = await this.deployContract(
      factories.curveLiquidityGaugeImplementation,
      overrides
    );

    const curveTokenImplementation = await this.deployContract(
      factories.curveTokenImplementation,
      overrides
    );

    const curveFactory = await this.deployContract(
      factories.curveFactory,
      AddressZero, // _fee_receiver
      curveCryptoPoolImplementation.contract.address,
      curveTokenImplementation.contract.address,
      curveLiquidityGaugeImplementation.contract.address,
      AddressZero, // _weth
      overrides
    );

    const lusdToken = await this.deployContract(
      factories.lusdToken,
      "LUSD Stablecoin",
      "LUSD",
      params.lusdFaucetTapAmount,
      params.lusdFaucetTapPeriod,
      overrides
    );

    const curvePool = await this.deployContract(
      factories.curvePool,
      "LUSD-3CRV Pool",
      "LUSD3CRV-f",
      lusdToken.contract.address,
      overrides
    );

    const curveBasePool = await this.deployContract(factories.curveBasePool, overrides);

    const bammSPVault = await this.deployContract(
      factories.bammSPVault,
      lusdToken.contract.address,
      overrides
    );

    const yearnCurveVault = await this.deployContract(
      factories.yearnCurveVault,
      "Curve LUSD Pool yVault",
      "yvCurve-LUSD",
      curvePool.contract.address,
      overrides
    );

    const yearnRegistry = await this.deployContract(
      factories.yearnRegistry,
      yearnCurveVault.contract.address,
      curvePool.contract.address,
      overrides
    );

    const bLUSDToken = await this.deployContract(
      factories.bLUSDToken,
      "bLUSDToken",
      "BLUSD",
      overrides
    );

    const eggArtwork = await this.deployContract(factories.eggArtwork, overrides);

    const bondNFTArtworkCommon = await this.deployContract(
      factories.bondNFTArtworkCommon,
      overrides
    );

    const chickenOutGenerated1 = await this.deployContract(
      factories.chickenOutGenerated1,
      overrides
    );

    const chickenOutArtwork = await this.deployContract(
      factories.chickenOutArtwork,
      bondNFTArtworkCommon.contract.address,
      chickenOutGenerated1.contract.address,
      overrides
    );

    const chickenInGenerated1 = await this.deployContract(factories.chickenInGenerated1, overrides);
    const chickenInGenerated2 = await this.deployContract(factories.chickenInGenerated2, overrides);
    const chickenInGenerated3 = await this.deployContract(factories.chickenInGenerated3, overrides);

    const chickenInArtwork = await this.deployContract(
      factories.chickenInArtwork,
      bondNFTArtworkCommon.contract.address,
      chickenInGenerated1.contract.address,
      chickenInGenerated2.contract.address,
      chickenInGenerated3.contract.address,
      overrides
    );

    const troveManager = await this.deployContract(factories.troveManager, overrides);

    const lqtyToken = await this.deployContract(
      factories.lqtyToken,
      "LQTY token",
      "LQTY",
      overrides
    );

    const lqtyStaking = await this.deployContract(factories.lqtyStaking, overrides);

    const pickleLQTYJar = await this.deployContract(
      factories.pickleLQTYJar,
      "pickling LQTY",
      "pLQTY",
      overrides
    );

    const pickleLQTYFarm = await this.deployContract(
      factories.pickleLQTYFarm,
      "Pickle Farm LTQY",
      "pfLQTY",
      overrides
    );

    const curveGaugeController = await this.deployContract(
      factories.curveGaugeController,
      overrides
    );

    const bondNFT = await this.deployContract(
      factories.bondNFT,
      "LUSDBondNFT",
      "LUSDBOND",
      eggArtwork.contract.address,
      params.bondNFTTransferLockoutPeriodSeconds,
      {
        troveManagerAddress: troveManager.contract.address,
        lqtyToken: lqtyToken.contract.address,
        lqtyStaking: lqtyStaking.contract.address,
        pickleLQTYJar: pickleLQTYJar.contract.address,
        pickleLQTYFarm: pickleLQTYFarm.contract.address,
        curveGaugeController: curveGaugeController.contract.address,
        curveLUSD3CRVGauge: "0x1337133713371337133713371337133713371337",
        curveLUSDFRAXGauge: "0x1337133713371337133713371337133713371337"
      },
      overrides
    );

    const bLUSDCurvePoolCoins: [string, string] = [
      bLUSDToken.contract.address,
      lusdToken.contract.address
    ];

    const bLUSDCurveToken = await this.deployContractViaFactoryContract(
      factories.bLUSDCurveToken,
      curveFactory.contract.deploy_pool(
        "bLUSD_LUSD", // _name
        "bLUSDLUSDC", // _symbol
        bLUSDCurvePoolCoins, // _coins
        params.bLUSDPoolA,
        params.bLUSDPoolGamma,
        params.bLUSDPoolMidFee,
        params.bLUSDPoolOutFee,
        params.bLUSDPoolAllowedExtraProfit,
        params.bLUSDPoolFeeGamma,
        params.bLUSDPoolAdjustmentStep,
        params.bLUSDPoolAdminFee,
        params.bLUSDPoolMAHalfTime,
        params.bLUSDPoolInitialPrice,
        overrides
      ),
      logs => curveFactory.contract.extractEvents(logs, "CryptoPoolDeployed")[0].args.token
    );

    const bLUSDCurvePoolAddress = await curveFactory.contract[
      "find_pool_for_coins(address,address)"
    ](...bLUSDCurvePoolCoins, overrides);

    const bLUSDCurvePool = {
      contractName: "bLUSDCurvePool",
      contract: factories.bLUSDCurvePool.factory
        .connect(this.deployer)
        .attach(bLUSDCurvePoolAddress),
      receipt: bLUSDCurveToken.receipt
    };

    assert((await bLUSDCurvePool.contract.token()) === bLUSDCurveToken.contract.address);

    const curveLiquidityGauge = await this.deployContractViaFactoryContract(
      factories.curveLiquidityGauge,
      curveFactory.contract.deploy_gauge(bLUSDCurvePoolAddress, overrides),
      logs => curveFactory.contract.extractEvents(logs, "LiquidityGaugeDeployed")[0].args.gauge
    );

    const chickenBondManager = await this.deployContract(
      factories.chickenBondManager,
      {
        bondNFTAddress: bondNFT.contract.address,
        curvePoolAddress: curvePool.contract.address,
        curveBasePoolAddress: curveBasePool.contract.address,
        lusdTokenAddress: lusdToken.contract.address,
        curveLiquidityGaugeAddress: curveLiquidityGauge.contract.address,
        bLUSDTokenAddress: bLUSDToken.contract.address,
        yearnCurveVaultAddress: yearnCurveVault.contract.address,
        yearnGovernanceAddress,
        bammSPVaultAddress: bammSPVault.contract.address,
        yearnRegistryAddress: yearnRegistry.contract.address
      },
      params,
      overrides
    );

    const bondNFTArtwork = await this.deployContract(
      factories.bondNFTArtwork,
      chickenBondManager.contract.address,
      eggArtwork.contract.address,
      chickenOutArtwork.contract.address,
      chickenInArtwork.contract.address,
      overrides
    );

    const bondNFTArtworkSwitcherTester = await this.deployContract(
      factories.bondNFTArtworkSwitcherTester,
      bondNFT.contract.address,
      eggArtwork.contract.address,
      chickenOutArtwork.contract.address,
      chickenInArtwork.contract.address,
      overrides
    );

    const underlingPrototype = await this.deployContract(
      factories.underlingPrototype,
      chickenBondManager.contract.address,
      lusdToken.contract.address,
      bLUSDToken.contract.address,
      bLUSDCurvePoolAddress,
      overrides
    );

    const prankster = await this.deployContract(
      factories.prankster,
      {
        yieldTargets: [
          {
            apr: params.harvesterBAMMAPR,
            receiver: bammSPVault.contract.address
          },
          {
            apr: params.harvesterCurveAPR,
            receiver: curvePool.contract.address
          }
        ],
        underlingPrototype: underlingPrototype.contract.address,
        curvePoolAddress: curvePool.contract.address,
        lusdTokenAddress: lusdToken.contract.address,
        bLUSDTokenAddress: bLUSDToken.contract.address,
        chickenBondManagerAddress: chickenBondManager.contract.address,
        bondNFTAddress: bondNFT.contract.address,
        bLUSDCurvePoolAddress: bLUSDCurvePoolAddress
      },
      overrides
    );

    return {
      lusdToken,
      curvePool,
      curveBasePool,
      bondNFT,
      bondNFTArtwork,
      eggArtwork,
      bondNFTArtworkCommon,
      chickenOutGenerated1,
      chickenOutArtwork,
      chickenInGenerated1,
      chickenInGenerated2,
      chickenInGenerated3,
      chickenInArtwork,
      bondNFTArtworkSwitcherTester,
      chickenBondManager,
      bLUSDToken,
      bLUSDCurveToken,
      bLUSDCurvePool,
      curveLiquidityGauge,
      yearnCurveVault,
      bammSPVault,
      yearnRegistry,
      prankster,
      underlingPrototype,
      troveManager,
      lqtyToken,
      lqtyStaking,
      pickleLQTYJar,
      pickleLQTYFarm,
      curveGaugeController,
      curveCryptoPoolImplementation,
      curveLiquidityGaugeImplementation,
      curveTokenImplementation,
      curveFactory
    };
  }

  private async connectDeployedContracts(deployed: LUSDChickenBondDeployedContracts) {
    const { overrides, log } = this;

    const connections: (() => Promise<ContractTransaction>)[] = [
      () =>
        deployed.bondNFT.contract.setAddresses(
          deployed.chickenBondManager.contract.address,
          overrides
        ),

      () =>
        deployed.bLUSDToken.contract.setAddresses(
          deployed.chickenBondManager.contract.address,
          overrides
        ),

      () =>
        deployed.bondNFT.contract.setArtworkAddress(
          deployed.bondNFTArtwork.contract.address,
          overrides
        ),

      () =>
        deployed.bammSPVault.contract.setChicken(
          deployed.chickenBondManager.contract.address,
          overrides
        ),

      () =>
        deployed.lusdToken.contract.transferOwnership(
          deployed.prankster.contract.address,
          overrides
        ),

      () =>
        deployed.bammSPVault.contract.transferOwnership(
          deployed.prankster.contract.address,
          overrides
        ),

      () =>
        deployed.curvePool.contract.transferOwnership(deployed.prankster.contract.address, overrides)
    ];

    for (const [i, connect] of connections.entries()) {
      const tx = await connect();
      await tx.wait();
      log(`Connected ${i + 1}`);
    }
  }

  async deployAndSetupContracts(): Promise<LUSDChickenBondDeploymentResult> {
    const { deployer, log } = this;

    const deployed = await this.deployContracts();

    log("Connecting contracts...");
    await this.connectDeployedContracts(deployed);

    const { receipt: firstReceipt } = Object.values(deployed).reduce((a, b) =>
      a.receipt.blockNumber < b.receipt.blockNumber ? a : b
    );

    const deploymentTimestamp = await deployed.chickenBondManager.contract.deploymentTimestamp();

    return {
      deployed,
      manifest: {
        addresses: mapContracts<DeployedContract, string>(deployed, x => x.contract.address),
        chainId: await deployer.getChainId(),
        deploymentTimestamp: deploymentTimestamp.toNumber(),
        startBlock: firstReceipt.blockNumber
      },
      config: this.config
    };
  }

  async getBondNFT(chickenBondManagerAddress: string) {
    const { deployer, factories } = this;
    const chickenBondManager = factories.chickenBondManager.factory
      .connect(deployer)
      .attach(chickenBondManagerAddress);

    const bondNFT = factories.bondNFT.factory
      .connect(deployer)
      .attach(await chickenBondManager.bondNFT());

    return bondNFT;
  }

  async deployNFTArtworkUpgrade(chickenBondManagerAddress: string): Promise<LUSDChickenBondArtworkDeployedContracts> {
    const { factories, overrides } = this;

    const bondNFT = await this.getBondNFT(chickenBondManagerAddress);
    const existingArtworkAddress = await bondNFT.artwork();

    const bondNFTArtworkCommon = await this.deployContract(
      factories.bondNFTArtworkCommon,
      overrides
    );

    const chickenOutGenerated1 = await this.deployContract(
      factories.chickenOutGenerated1,
      overrides
    );

    const chickenOutArtwork = await this.deployContract(
      factories.chickenOutArtwork,
      bondNFTArtworkCommon.contract.address,
      chickenOutGenerated1.contract.address,
      overrides
    );

    const chickenInGenerated1 = await this.deployContract(factories.chickenInGenerated1, overrides);
    const chickenInGenerated2 = await this.deployContract(factories.chickenInGenerated2, overrides);
    const chickenInGenerated3 = await this.deployContract(factories.chickenInGenerated3, overrides);

    const chickenInArtwork = await this.deployContract(
      factories.chickenInArtwork,
      bondNFTArtworkCommon.contract.address,
      chickenInGenerated1.contract.address,
      chickenInGenerated2.contract.address,
      chickenInGenerated3.contract.address,
      overrides
    );

    const bondNFTArtworkSwitcher = await this.deployContract(
      factories.bondNFTArtwork,
      chickenBondManagerAddress,
      existingArtworkAddress,
      chickenOutArtwork.contract.address,
      chickenInArtwork.contract.address,
      overrides
    );

    const bondNFTArtworkSwitcherTester = await this.deployContract(
      factories.bondNFTArtworkSwitcherTester,
      bondNFT.address,
      existingArtworkAddress,
      chickenOutArtwork.contract.address,
      chickenInArtwork.contract.address,
      overrides
    );

    return {
      bondNFTArtworkSwitcher,
      bondNFTArtworkCommon,
      chickenOutGenerated1,
      chickenOutArtwork,
      chickenInGenerated1,
      chickenInGenerated2,
      chickenInGenerated3,
      chickenInArtwork,
      bondNFTArtworkSwitcherTester
    };
  }
}

export const deployAndSetupContracts = async (
  deployer: Signer,
  params?: Readonly<Partial<LUSDChickenBondDeploymentParams>>
): Promise<LUSDChickenBondDeploymentResult> =>
  new LUSDChickenBondDeployment(deployer, params).deployAndSetupContracts();

export const deployNFTArtworkUpgrade = async (
  deployer: Signer,
  chickenBondManagerAddress: string,
  params?: Readonly<Partial<Omit<LUSDChickenBondDeploymentParams, "config">>>
) =>
  new LUSDChickenBondDeployment(deployer, params).deployNFTArtworkUpgrade(chickenBondManagerAddress);

export const getBondNFT = async (
  deployer: Signer,
  chickenBondManagerAddress: string,
  params?: Readonly<Partial<Omit<LUSDChickenBondDeploymentParams, "config">>>
) =>
  new LUSDChickenBondDeployment(deployer, params).getBondNFT(chickenBondManagerAddress);
