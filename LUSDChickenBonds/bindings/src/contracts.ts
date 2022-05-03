import { JsonFragment } from "@ethersproject/abi";
import { Provider } from "@ethersproject/abstract-provider";
import { Signer } from "@ethersproject/abstract-signer";

import bondNFT from "../artifacts/BondNFT.json";
import chickenBondManager from "../artifacts/ChickenBondManager.json";
import lusdTokenTester from "../artifacts/LUSDTokenTester.json";
import mockCurvePool from "../artifacts/MockCurvePool.json";
import mockYearnRegistry from "../artifacts/MockYearnRegistry.json";
import mockYearnVault from "../artifacts/MockYearnVault.json";
import sLUSDToken from "../artifacts/SLUSDToken.json";

import {
  BondNFTFactory,
  ChickenBondManagerFactory,
  LUSDTokenTesterFactory,
  MockCurvePoolFactory,
  MockYearnRegistryFactory,
  MockYearnVaultFactory,
  SLUSDTokenFactory
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
    contractName: "LUSDTokenTester";
    factory: LUSDTokenTesterFactory;
  };

  sLUSDToken: {
    contractName: "SLUSDToken";
    factory: SLUSDTokenFactory;
  };

  yearnRegistry: {
    contractName: "MockYearnRegistry";
    factory: MockYearnRegistryFactory;
  };

  yearnLUSDVault: {
    contractName: "MockYearnVault";
    factory: MockYearnVaultFactory;
  };

  yearnCurveVault: {
    contractName: "MockYearnVault";
    factory: MockYearnVaultFactory;
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
  lusdToken: checkArtifact("LUSDTokenTester", lusdTokenTester),
  sLUSDToken: checkArtifact("SLUSDToken", sLUSDToken),
  yearnCurveVault: checkArtifact("MockYearnVault", mockYearnVault),
  yearnLUSDVault: checkArtifact("MockYearnVault", mockYearnVault),
  yearnRegistry: checkArtifact("MockYearnRegistry", mockYearnRegistry)
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
