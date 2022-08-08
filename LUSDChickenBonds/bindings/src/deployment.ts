import assert from "assert";

import { TransactionReceipt, Log } from "@ethersproject/abstract-provider";
import { Signer } from "@ethersproject/abstract-signer";
import { AddressZero } from "@ethersproject/constants";
import { ContractTransaction, Overrides } from "@ethersproject/contracts";
import { Decimal } from "@liquity/lib-base";

import { TypedContract, TypedContractFactory } from "./typing";
import { fillConfig, LUSDChickenBondConfig } from "./config";

import {
  getContractFactories,
  LUSDChickenBondContractAddresses,
  LUSDChickenBondContracts,
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
  contract: T;
  receipt: TransactionReceipt;
}

export type LUSDChickenBondDeployedContracts = {
  [P in keyof LUSDChickenBondContracts]: DeployedContract<LUSDChickenBondContracts[P]>;
};

export interface LUSDChickenBondDeploymentResult {
  deployed: LUSDChickenBondDeployedContracts;
  manifest: LUSDChickenBondDeploymentManifest;
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

    return { contract, receipt };
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

    return { contract, receipt };
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
      overrides
    );

    const curveBasePool = await this.deployContract(
      factories.curvePool,
      "3CRV Pool",
      "3CRV",
      overrides
    );

    const bammSPVault = await this.deployContract(
      factories.bammSPVault,
      lusdToken.contract.address,
      overrides
    );

    const yearnCurveVault = await this.deployContract(
      factories.yearnCurveVault,
      "Curve LUSD Pool yVault",
      "yvCurve-LUSD",
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

    const bondNFT = await this.deployContract(
      factories.bondNFT,
      "LUSDBondNFT",
      "LUSDBOND",
      AddressZero,
      params.bondNFTTransferLockoutPeriodSeconds,
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
        4000, // A
        Decimal.from(0.000145).hex, // gamma
        Decimal.from(0.5).div(1e10).hex, // mid_fee (%)
        Decimal.from(1.0).div(1e10).hex, // out_fee (%)
        Decimal.from(0.000002).hex, // allowed_extra_profit
        Decimal.from(0.0023).hex, // fee_gamma
        Decimal.from(0.000146).hex, // adjustment_step
        Decimal.from(50).div(1e10).hex, // admin_fee (%)
        24 * 60 * 60, // ma_half_time
        Decimal.from(1.2).hex, // initial_price (token1 / token2)
        overrides
      ),
      logs => curveFactory.contract.extractEvents(logs, "CryptoPoolDeployed")[0].args.token
    );

    const bLUSDCurvePoolAddress = await curveFactory.contract[
      "find_pool_for_coins(address,address)"
    ](...bLUSDCurvePoolCoins, overrides);

    const bLUSDCurvePool = {
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

    const harvester = await this.deployContract(
      factories.harvester,
      lusdToken.contract.address,
      [
        {
          apr: params.harvesterBAMMAPR,
          receiver: bammSPVault.contract.address
        }
      ],
      overrides
    );

    return {
      lusdToken,
      curvePool,
      bondNFT,
      chickenBondManager,
      bLUSDToken,
      bLUSDCurveToken,
      bLUSDCurvePool,
      curveLiquidityGauge,
      yearnCurveVault,
      bammSPVault,
      yearnRegistry,
      harvester,
      curveCryptoPoolImplementation,
      curveLiquidityGaugeImplementation,
      curveTokenImplementation,
      curveFactory
    };
  }

  private async connectDeployedContracts(deployed: LUSDChickenBondDeployedContracts) {
    const { overrides, log } = this;

    const connections: (() => Promise<ContractTransaction>)[] = [
      () => deployed.curvePool.contract.setAddresses(deployed.lusdToken.contract.address, overrides),

      () =>
        deployed.yearnCurveVault.contract.setAddresses(
          deployed.curvePool.contract.address,
          overrides
        ),

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
        deployed.bammSPVault.contract.setChicken(
          deployed.chickenBondManager.contract.address,
          overrides
        ),

      () =>
        deployed.lusdToken.contract.transferOwnership(
          deployed.harvester.contract.address,
          overrides
        ),

      () =>
        deployed.bammSPVault.contract.transferOwnership(
          deployed.harvester.contract.address,
          overrides
        )
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
      }
    };
  }
}

export const deployAndSetupContracts = async (
  deployer: Signer,
  params?: Readonly<Partial<LUSDChickenBondDeploymentParams>>
): Promise<LUSDChickenBondDeploymentResult> =>
  new LUSDChickenBondDeployment(deployer, params).deployAndSetupContracts();
