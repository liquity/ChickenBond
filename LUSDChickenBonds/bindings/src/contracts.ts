import { JsonFragment } from "@ethersproject/abi";
import { Provider } from "@ethersproject/abstract-provider";
import { Signer } from "@ethersproject/abstract-signer";

import bondNFT from "../artifacts/BondNFT.json";
import generativeEggArtwork from "../artifacts/GenerativeEggArtwork.json";
import chickenBondManager from "../artifacts/ChickenBondManager.json";
import erc20Faucet from "../artifacts/ERC20Faucet.json";
import testnetBAMM from "../artifacts/TestnetBAMM.json";
import testnetCurvePool from "../artifacts/TestnetCurvePool.json";
import testnetCurveBasePool from "../artifacts/TestnetCurveBasePool.json";
import mockYearnRegistry from "../artifacts/MockYearnRegistry.json";
import testnetYearnVault from "../artifacts/TestnetYearnVault.json";
import bLUSDToken from "../artifacts/BLUSDToken.json";
import testnetCurveLiquidityGauge from "../artifacts/TestnetCurveLiquidityGauge.json";
import prankster from "../artifacts/Prankster.json";
import curveCryptoSwap2ETH from "../artifacts/CurveCryptoSwap2ETH.json";
import curveFactory from "../artifacts/CurveFactory.json";
// import curveLiquidityGauge from "../artifacts/CurveLiquidityGauge.json";
import curveToken from "../artifacts/CurveToken.json";

import {
  BondNFTFactory,
  GenerativeEggArtworkFactory,
  ChickenBondManagerFactory,
  ERC20FaucetFactory,
  TestnetBAMMFactory,
  TestnetCurvePoolFactory,
  TestnetCurveBasePoolFactory,
  MockYearnRegistryFactory,
  TestnetYearnVaultFactory,
  BLUSDTokenFactory,
  TestnetCurveLiquidityGaugeFactory,
  PranksterFactory,
  CurveCryptoSwap2ETHFactory,
  CurveFactoryFactory,
  // CurveLiquidityGaugeFactory,
  CurveTokenFactory
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

  bondNFTArtwork: {
    contractName: "GenerativeEggArtwork";
    factory: GenerativeEggArtworkFactory;
  };

  chickenBondManager: {
    contractName: "ChickenBondManager";
    factory: ChickenBondManagerFactory;
  };

  curvePool: {
    contractName: "TestnetCurvePool";
    factory: TestnetCurvePoolFactory;
  };

  curveBasePool: {
    contractName: "TestnetCurveBasePool";
    factory: TestnetCurveBasePoolFactory;
  };

  lusdToken: {
    contractName: "ERC20Faucet";
    factory: ERC20FaucetFactory;
  };

  bLUSDCurveToken: {
    contractName: "CurveToken";
    factory: CurveTokenFactory;
  };

  bLUSDCurvePool: {
    contractName: "CurveCryptoSwap2ETH";
    factory: CurveCryptoSwap2ETHFactory;
  };

  curveLiquidityGauge: {
    contractName: "TestnetCurveLiquidityGauge";
    factory: TestnetCurveLiquidityGaugeFactory;
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
    contractName: "TestnetYearnVault";
    factory: TestnetYearnVaultFactory;
  };

  prankster: {
    contractName: "Prankster";
    factory: PranksterFactory;
  };

  curveCryptoPoolImplementation: {
    contractName: "CurveCryptoSwap2ETH";
    factory: CurveCryptoSwap2ETHFactory;
  };

  curveLiquidityGaugeImplementation: {
    contractName: "TestnetCurveLiquidityGauge";
    factory: TestnetCurveLiquidityGaugeFactory;
  };

  curveTokenImplementation: {
    contractName: "CurveToken";
    factory: CurveTokenFactory;
  };

  curveFactory: {
    contractName: "CurveFactory";
    factory: CurveFactoryFactory;
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
  bondNFTArtwork: checkArtifact("GenerativeEggArtwork", generativeEggArtwork),
  chickenBondManager: checkArtifact("ChickenBondManager", chickenBondManager),
  curvePool: checkArtifact("TestnetCurvePool", testnetCurvePool),
  curveBasePool: checkArtifact("TestnetCurveBasePool", testnetCurveBasePool),
  lusdToken: checkArtifact("ERC20Faucet", erc20Faucet),
  bLUSDCurveToken: checkArtifact("CurveToken", curveToken),
  bLUSDCurvePool: checkArtifact("CurveCryptoSwap2ETH", curveCryptoSwap2ETH),
  curveLiquidityGauge: checkArtifact("TestnetCurveLiquidityGauge", testnetCurveLiquidityGauge),
  bLUSDToken: checkArtifact("BLUSDToken", bLUSDToken),
  yearnCurveVault: checkArtifact("TestnetYearnVault", testnetYearnVault),
  bammSPVault: checkArtifact("TestnetBAMM", testnetBAMM),
  yearnRegistry: checkArtifact("MockYearnRegistry", mockYearnRegistry),
  prankster: checkArtifact("Prankster", prankster),
  curveCryptoPoolImplementation: checkArtifact("CurveCryptoSwap2ETH", curveCryptoSwap2ETH),
  curveLiquidityGaugeImplementation: checkArtifact(
    "TestnetCurveLiquidityGauge",
    testnetCurveLiquidityGauge
  ),
  curveTokenImplementation: checkArtifact("CurveToken", curveToken),
  curveFactory: checkArtifact("CurveFactory", curveFactory)
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
