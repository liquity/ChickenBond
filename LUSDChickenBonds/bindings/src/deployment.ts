import { TransactionReceipt } from "@ethersproject/abstract-provider";
import { Signer } from "@ethersproject/abstract-signer";
import { AddressZero } from "@ethersproject/constants";
import { ContractTransaction, Overrides } from "@ethersproject/contracts";

import { TypedContract, TypedContractFactory } from "./typing";

import {
  getContractFactories,
  LUSDChickenBondContractAddresses,
  LUSDChickenBondContracts,
  mapContracts
} from "./contracts";

import * as config from "./config";

export interface LUSDChickenBondDeploymentManifest {
  readonly chainId: number;
  readonly addresses: LUSDChickenBondContractAddresses;
  // readonly version: string; // TODO
  readonly deploymentTimestamp: number;
  readonly startBlock: number;
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

let silent = true;

export const log = (...args: unknown[]): void => {
  if (!silent) {
    console.log(...args);
  }
};

export const setSilent = (s: boolean): void => {
  silent = s;
};

interface NamedFactory<T extends TypedContract, A extends unknown[]> {
  contractName: string;
  factory: TypedContractFactory<T, A>;
}

const deployContract = async <T extends TypedContract, A extends unknown[]>(
  { contractName, factory }: NamedFactory<T, A>,
  ...args: A
): Promise<DeployedContract<T>> => {
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
};

const deployContracts = async (
  deployer: Signer,
  overrides?: Overrides
): Promise<LUSDChickenBondDeployedContracts> => {
  const factories = getContractFactories(deployer);

  const lusdToken = await deployContract(
    factories.lusdToken,
    AddressZero,
    AddressZero,
    AddressZero,
    overrides
  );

  const curvePool = await deployContract(
    factories.curvePool,
    "LUSD-3CRV Pool",
    "LUSD3CRV-f",
    overrides
  );

  const yearnLUSDVault = await deployContract(
    factories.yearnLUSDVault,
    "LUSD yVault",
    "yvLUSD",
    overrides
  );

  const yearnCurveVault = await deployContract(
    factories.yearnCurveVault,
    "Curve LUSD Pool yVault",
    "yvCurve-LUSD",
    overrides
  );

  const yearnRegistry = await deployContract(
    factories.yearnRegistry,
    yearnLUSDVault.contract.address,
    yearnCurveVault.contract.address,
    lusdToken.contract.address,
    curvePool.contract.address,
    overrides
  );

  const sLUSDToken = await deployContract(factories.sLUSDToken, "sLUSDToken", "SLUSD", overrides);
  const bondNFT = await deployContract(factories.bondNFT, "LUSDBondNFT", "LUSDBOND", overrides);
  const uniToken = await deployContract(factories.uniToken, "Uniswap LP Token", "UNI", overrides);

  const sLUSDLPRewardsStaking = await deployContract(
    factories.sLUSDLPRewardsStaking,
    lusdToken.contract.address,
    uniToken.contract.address,
    overrides
  );

  const chickenBondManager = await deployContract(
    factories.chickenBondManager,
    {
      bondNFTAddress: bondNFT.contract.address,
      curvePoolAddress: curvePool.contract.address,
      lusdTokenAddress: lusdToken.contract.address,
      sLUSDLPRewardsStakingAddress: sLUSDLPRewardsStaking.contract.address,
      sLUSDTokenAddress: sLUSDToken.contract.address,
      yearnCurveVaultAddress: yearnCurveVault.contract.address,
      yearnLUSDVaultAddress: yearnLUSDVault.contract.address,
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
    lusdToken,
    sLUSDLPRewardsStaking,
    sLUSDToken,
    uniToken,
    yearnCurveVault,
    yearnLUSDVault,
    yearnRegistry
  };
};

const connectContracts = async (
  deployed: LUSDChickenBondDeployedContracts,
  overrides?: Overrides
) => {
  const signer = deployed.chickenBondManager.contract.signer;
  const txCount = await signer.getTransactionCount();

  const connections: ((nonce: number) => Promise<ContractTransaction>)[] = [
    nonce =>
      deployed.bondNFT.contract.setAddresses(deployed.chickenBondManager.contract.address, {
        ...overrides,
        nonce
      }),

    nonce =>
      deployed.sLUSDToken.contract.setAddresses(deployed.chickenBondManager.contract.address, {
        ...overrides,
        nonce
      })
  ];

  const txs = await Promise.all(connections.map((connect, i) => connect(txCount + i)));

  let i = 0;
  await Promise.all(txs.map(tx => tx.wait().then(() => log(`Connected ${++i}`))));
};

export const deployAndSetupContracts = async (
  deployer: Signer,
  overrides?: Overrides
): Promise<LUSDChickenBondDeploymentResult> => {
  overrides = { ...overrides };

  if (!deployer.provider) {
    throw new Error("deployer must have provider");
  }

  log("Deploying contracts...");
  log();
  const deployed = await deployContracts(deployer, overrides);

  log("Connecting contracts...");
  await connectContracts(deployed, overrides);

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
};
