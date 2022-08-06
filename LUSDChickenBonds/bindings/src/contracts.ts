import { JsonFragment } from "@ethersproject/abi";
import { Provider } from "@ethersproject/abstract-provider";
import { Signer } from "@ethersproject/abstract-signer";

import bondNFT from "../artifacts/BondNFT.json";
import chickenBondManager from "../artifacts/ChickenBondManager.json";
import erc20Faucet from "../artifacts/ERC20Faucet.json";
import testnetBAMM from "../artifacts/TestnetBAMM.json";
import mockCurvePool from "../artifacts/MockCurvePool.json";
import mockYearnRegistry from "../artifacts/MockYearnRegistry.json";
import mockYearnVault from "../artifacts/MockYearnVault.json";
import bLUSDToken from "../artifacts/BLUSDToken.json";
import mockCurveLiquidityGaugeV4 from "../artifacts/MockCurveLiquidityGaugeV4.json";
import harvester from "../artifacts/Harvester.json";

import {
  BondNFTFactory,
  ChickenBondManagerFactory,
  ERC20FaucetFactory,
  TestnetBAMMFactory,
  MockCurvePoolFactory,
  MockYearnRegistryFactory,
  MockYearnVaultFactory,
  BLUSDTokenFactory,
  MockCurveLiquidityGaugeV4Factory,
  HarvesterFactory
} from "./generated/types";

import {
  ContractWithEventParsing,
  ContractWithEventParsingFactory,
  TypedContract,
  TypedContractFactory
} from "./typing";

export interface LUSDChickenBondContractFactories {
  bondNFT: {
    contractName: "BondNFT";
    factory: BondNFTFactory;
  };

  chickenBondManager: {
    contractName: "ChickenBondManager";
    factory: ChickenBondManagerFactory;
  };

  curvePool: {
    contractName: "MockCurvePool";
    factory: MockCurvePoolFactory;
  };

  lusdToken: {
    contractName: "ERC20Faucet";
    factory: ERC20FaucetFactory;
  };

  curveLiquidityGauge: {
    contractName: "MockCurveLiquidityGaugeV4";
    factory: MockCurveLiquidityGaugeV4Factory;
  };

  bLUSDToken: {
    contractName: "BLUSDToken";
    factory: BLUSDTokenFactory;
  };

  yearnRegistry: {
    contractName: "MockYearnRegistry";
    factory: MockYearnRegistryFactory;
  };

  bammSPVault: {
    contractName: "TestnetBAMM";
    factory: TestnetBAMMFactory;
  };

  yearnCurveVault: {
    contractName: "MockYearnVault";
    factory: MockYearnVaultFactory;
  };

  harvester: {
    contractName: "Harvester";
    factory: HarvesterFactory;
  };
}

export type LUSDChickenBondContractArtifacts = {
  [P in keyof LUSDChickenBondContractFactories]: ContractArtifact<
    LUSDChickenBondContractFactories[P]["contractName"]
  >;
};

export type LUSDChickenBondContracts = {
  [P in keyof LUSDChickenBondContractFactories]: LUSDChickenBondContractFactories[P] extends {
    factory: TypedContractFactory<infer T>;
  }
    ? T
    : never;
};

export type LUSDChickenBondContractName =
  LUSDChickenBondContractFactories[keyof LUSDChickenBondContractFactories]["contractName"];

export type LUSDChickenBondContractsKey = keyof LUSDChickenBondContractFactories;
export type LUSDChickenBondContractAddresses = Record<LUSDChickenBondContractsKey, string>;

export interface ContractArtifact<T extends string = string> {
  contractName: T;
  abi: JsonFragment[];
  bytecode: string;
}

const panic = <T>(errorMessage: string): T => {
  throw new Error(errorMessage);
};

const checkArtifact = <T extends LUSDChickenBondContractName>(
  expectedContractName: T,
  artifact: ContractArtifact<string>
): ContractArtifact<T> =>
  artifact.contractName === expectedContractName
    ? (artifact as ContractArtifact<T>)
    : panic(
        `Wrong contract artifact (expected ${expectedContractName}, got ${artifact.contractName})`
      );

const getContractArtifacts = (): LUSDChickenBondContractArtifacts => ({
  bondNFT: checkArtifact("BondNFT", bondNFT),
  chickenBondManager: checkArtifact("ChickenBondManager", chickenBondManager),
  curvePool: checkArtifact("MockCurvePool", mockCurvePool),
  lusdToken: checkArtifact("ERC20Faucet", erc20Faucet),
  curveLiquidityGauge: checkArtifact("MockCurveLiquidityGaugeV4", mockCurveLiquidityGaugeV4),
  bLUSDToken: checkArtifact("BLUSDToken", bLUSDToken),
  yearnCurveVault: checkArtifact("MockYearnVault", mockYearnVault),
  bammSPVault: checkArtifact("TestnetBAMM", testnetBAMM),
  yearnRegistry: checkArtifact("MockYearnRegistry", mockYearnRegistry),
  harvester: checkArtifact("Harvester", harvester)
});

export const mapContracts = <T, U>(
  contracts: Record<LUSDChickenBondContractsKey, T>,
  f: (t: T, key: LUSDChickenBondContractsKey) => U
) =>
  Object.fromEntries(
    Object.entries(contracts).map(([key, t]) => [key, f(t, key as LUSDChickenBondContractsKey)])
  ) as Record<LUSDChickenBondContractsKey, U>;

export const connectToContracts = (
  signerOrProvider: Signer | Provider,
  addresses: LUSDChickenBondContractAddresses
): LUSDChickenBondContracts => {
  const artifacts = getContractArtifacts();

  return mapContracts(
    addresses,
    (address, key) =>
      new ContractWithEventParsing(address, artifacts[key].abi, signerOrProvider) as TypedContract
  ) as LUSDChickenBondContracts;
};

export const getContractFactories = (deployer: Signer): LUSDChickenBondContractFactories => {
  const artifacts: Record<LUSDChickenBondContractsKey, ContractArtifact> = getContractArtifacts();

  return mapContracts(artifacts, ({ contractName, abi, bytecode }) => ({
    contractName,
    factory: new ContractWithEventParsingFactory(abi, bytecode, deployer) as TypedContractFactory
  })) as LUSDChickenBondContractFactories;
};
