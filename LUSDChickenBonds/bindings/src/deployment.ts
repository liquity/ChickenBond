import { TransactionReceipt } from "@ethersproject/abstract-provider";
import { Signer } from "@ethersproject/abstract-signer";
import { AddressZero } from "@ethersproject/constants";
import { ContractTransaction, Overrides } from "@ethersproject/contracts";

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

  private async deployContracts(): Promise<LUSDChickenBondDeployedContracts> {
    const { factories, overrides, config } = this;

    const lusdSilo = await this.deployContract(factories.lusdSilo, overrides);

    const lusdToken = await this.deployContract(
      factories.lusdToken,
      AddressZero,
      AddressZero,
      AddressZero,
      overrides
    );

    const curvePool = await this.deployContract(
      factories.curvePool,
      "LUSD-3CRV Pool",
      "LUSD3CRV-f",
      overrides
    );

    const yearnSPVault = await this.deployContract(
      factories.yearnSPVault,
      "LUSD yVault",
      "yvLUSD",
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
      yearnSPVault.contract.address,
      yearnCurveVault.contract.address,
      lusdToken.contract.address,
      curvePool.contract.address,
      overrides
    );

    const sLUSDToken = await this.deployContract(
      factories.sLUSDToken,
      "sLUSDToken",
      "SLUSD",
      overrides
    );

    const bondNFT = await this.deployContract(
      factories.bondNFT,
      "LUSDBondNFT",
      "LUSDBOND",
      overrides
    );

    const uniToken = await this.deployContract(
      factories.uniToken,
      "Uniswap LP Token",
      "UNI",
      overrides
    );

    const curveLiquidityGauge = await this.deployContract(factories.curveLiquidityGauge, overrides);

    const chickenBondManager = await this.deployContract(
      factories.chickenBondManager,
      {
        bondNFTAddress: bondNFT.contract.address,
        curvePoolAddress: curvePool.contract.address,
        lusdSiloAddress: lusdSilo.contract.address,
        lusdTokenAddress: lusdToken.contract.address,
        curveLiquidityGaugeAddress: curveLiquidityGauge.contract.address,
        sLUSDTokenAddress: sLUSDToken.contract.address,
        yearnCurveVaultAddress: yearnCurveVault.contract.address,
        yearnGovernanceAddress: config.yearnGovernanceAddress,
        yearnSPVaultAddress: yearnSPVault.contract.address,
        yearnRegistryAddress: yearnRegistry.contract.address
      },
      config.targetAverageAgeSeconds,
      config.initialAccrualParameter,
      config.minimumAccrualParameter,
      config.accrualAdjustmentRate,
      config.accrualAdjustmentPeriodSeconds,
      config.chickenInAMMTax,
      overrides
    );

    return {
      bondNFT,
      chickenBondManager,
      curvePool,
      lusdSilo,
      lusdToken,
      curveLiquidityGauge,
      sLUSDToken,
      uniToken,
      yearnCurveVault,
      yearnSPVault,
      yearnRegistry
    };
  }

  private async connectDeployedContracts(deployed: LUSDChickenBondDeployedContracts) {
    const { overrides, log } = this;

    const connections: (() => Promise<ContractTransaction>)[] = [
      () => deployed.curvePool.contract.setAddresses(deployed.lusdToken.contract.address, overrides),

      () =>
        deployed.yearnSPVault.contract.setAddresses(deployed.lusdToken.contract.address, overrides),

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
        deployed.sLUSDToken.contract.setAddresses(
          deployed.chickenBondManager.contract.address,
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

    if (!deployer.provider) {
      throw new Error("deployer must have provider");
    }

    const deployed = await this.deployContracts();

    log("Connecting contracts...");
    await this.connectDeployedContracts(deployed);

    const { receipt: firstReceipt } = Object.values(deployed).reduce((a, b) =>
      a.receipt.blockNumber < b.receipt.blockNumber ? a : b
    );

    const firstDeploymentBlock = await deployer.provider.getBlock(firstReceipt.blockNumber);

    return {
      deployed,
      manifest: {
        addresses: mapContracts<DeployedContract, string>(deployed, x => x.contract.address),
        chainId: await deployer.getChainId(),
        deploymentTimestamp: firstDeploymentBlock.timestamp,
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
