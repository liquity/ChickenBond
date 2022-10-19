import fs from "fs-extra";
import path from "path";

import { Interface, JsonFragment, ParamType } from "@ethersproject/abi";

import BondNFT from "../../out/BondNFT.sol/BondNFT.json";
import BondNFTArtworkSwitcher from "../../out/BondNFTArtworkSwitcher.sol/BondNFTArtworkSwitcher.json";
import GenerativeEggArtwork from "../../out/GenerativeEggArtwork.sol/GenerativeEggArtwork.json";
import BondNFTArtworkCommon from "../../out/BondNFTArtworkBase.sol/BondNFTArtworkCommon.json";
import ChickenOutGenerated1 from "../../out/ChickenOutGenerated.sol/ChickenOutGenerated1.json";
import ChickenOutArtwork from "../../out/ChickenOutArtwork.sol/ChickenOutArtwork.json";
import ChickenInGenerated1 from "../../out/ChickenInGenerated.sol/ChickenInGenerated1.json";
import ChickenInGenerated2 from "../../out/ChickenInGenerated.sol/ChickenInGenerated2.json";
import ChickenInGenerated3 from "../../out/ChickenInGenerated.sol/ChickenInGenerated3.json";
import ChickenInArtwork from "../../out/ChickenInArtwork.sol/ChickenInArtwork.json";
import BondNFTArtworkSwitcherTester from "../../out/BondNFTArtworkSwitcherTester.sol/BondNFTArtworkSwitcherTester.json";
import ChickenBondManager from "../../out/ChickenBondManager.sol/ChickenBondManager.json";
import ERC20Faucet from "../../out/ERC20Faucet.sol/ERC20Faucet.json";
import TestnetBAMM from "../../out/TestnetBAMM.sol/TestnetBAMM.json";
import TestnetCurvePool from "../../out/TestnetCurvePool.sol/TestnetCurvePool.json";
import TestnetCurveBasePool from "../../out/TestnetCurveBasePool.sol/TestnetCurveBasePool.json";
import MockYearnRegistry from "../../out/MockYearnRegistry.sol/MockYearnRegistry.json";
import TestnetYearnVault from "../../out/TestnetYearnVault.sol/TestnetYearnVault.json";
import BLUSDToken from "../../out/BLUSDToken.sol/BLUSDToken.json";
import TestnetCurveLiquidityGauge from "../../out/TestnetCurveLiquidityGauge.sol/TestnetCurveLiquidityGauge.json";
import Prankster from "../../out/Prankster.sol/Prankster.json";
import Underling from "../../out/Underling.sol/Underling.json";
import ERC20 from "../../out/ERC20.sol/ERC20.json";
import MockTroveManager from "../../out/MockTroveManager.sol/MockTroveManager.json";
import MockLQTYStaking from "../../out/MockLQTYStaking.sol/MockLQTYStaking.json";
import MockPickleJar from "../../out/MockPickleJar.sol/MockPickleJar.json";
import MockCurveGaugeController from "../../out/MockCurveGaugeController.sol/MockCurveGaugeController.json";

// Curve v2
import CurveCryptoSwap2ETH from "../curve/CurveCryptoSwap2ETH.json";
import CurveToken from "../curve/CurveTokenV5.json";
import CurveFactory from "../curve/Factory.json";
// import CurveLiquidityGauge from "../curve/LiquidityGauge.json";
import CurveRegistrySwaps from "../curve/Swaps.json";

type Writable<T> = { -readonly [P in keyof T]: T[P] };

const getTupleType = (components: ParamType[], flexible: boolean) => {
  if (components.every(component => component.name)) {
    return (
      "{ " +
      components.map(component => `${component.name}: ${getType(component, flexible)}`).join("; ") +
      " }"
    );
  } else {
    return `[${components.map(component => getType(component, flexible)).join(", ")}]`;
  }
};

const getType = ({ baseType, components, arrayChildren }: ParamType, flexible: boolean): string => {
  switch (baseType) {
    case "address":
    case "string":
      return "string";

    case "bool":
      return "boolean";

    case "array":
      return `${getType(arrayChildren, flexible)}[]`;

    case "tuple":
      return getTupleType(components, flexible);
  }

  if (baseType.startsWith("bytes")) {
    return flexible ? "BytesLike" : "string";
  }

  const match = baseType.match(/^(u?int)([0-9]+)$/);
  if (match) {
    return flexible ? "BigNumberish" : parseInt(match[2]) >= 53 ? "BigNumber" : "number";
  }

  throw new Error(`unimplemented type ${baseType}`);
};

const declareParams = (params: ParamType[]) =>
  params.map((input, i) => `${input.name || "arg" + i}: ${getType(input, true)}`);

const declareInterface = ({
  contractName,
  interface: { events, functions, deploy }
}: {
  contractName: string;
  interface: Interface;
}) => {
  const functionEntries = Object.entries(functions);

  const constructorParams = [
    ...declareParams(deploy.inputs),
    `_overrides?: ${deploy.payable ? "PayableOverrides" : "Overrides"}`
  ];

  return [
    `interface ${contractName}Calls {`,
    ...functionEntries
      .filter(([, { constant }]) => constant)
      .map(([signature, { name, inputs, outputs }]) => {
        const overloaded = functionEntries.some(
          ([otherSignature, other]) => other.name === name && otherSignature !== signature
        );

        const params = [...declareParams(inputs), `_overrides?: CallOverrides`];

        let returnType: string;
        if (!outputs || outputs.length == 0) {
          returnType = "void";
        } else if (outputs.length === 1) {
          returnType = getType(outputs[0], false);
        } else {
          returnType = getTupleType(outputs, false);
        }

        return `  ${overloaded ? `["${signature}"]` : name}(${params.join(
          ", "
        )}): Promise<${returnType}>;`;
      }),
    "}\n",

    `interface ${contractName}Transactions {`,
    ...functionEntries
      .filter(([, { constant }]) => !constant)
      .map(([signature, { name, payable, inputs, outputs }]) => {
        const overloaded = functionEntries.some(
          ([otherSignature, other]) => other.name === name && otherSignature !== signature
        );

        const overridesType = payable ? "PayableOverrides" : "Overrides";
        const params = [...declareParams(inputs), `_overrides?: ${overridesType}`];

        let returnType: string;
        if (!outputs || outputs.length == 0) {
          returnType = "void";
        } else if (outputs.length === 1) {
          returnType = getType(outputs[0], false);
        } else {
          returnType = getTupleType(outputs, false);
        }

        return `  ${overloaded ? `["${signature}"]` : name}(${params.join(
          ", "
        )}): Promise<${returnType}>;`;
      }),
    "}\n",

    `export interface ${contractName}`,
    `  extends TypedContract<${contractName}Calls, ${contractName}Transactions> {`,

    "  readonly filters: {",
    ...Object.values(events).map(({ name, inputs }) => {
      const params = inputs.map(
        input => `${input.name}?: ${input.indexed ? `${getType(input, true)} | null` : "null"}`
      );

      return `    ${name}(${params.join(", ")}): EventFilter;`;
    }),
    "  };",

    ...Object.values(events).map(
      ({ name, inputs }) =>
        `  extractEvents(logs: Log[], name: "${name}"): TypedLogDescription<${getTupleType(
          inputs,
          false
        )}>[];`
    ),

    "}\n",

    `export type ${contractName}Factory = TypedContractFactory<${contractName}, [` +
      constructorParams.join(", ") +
      "]>;"
  ].join("\n");
};

const contractArtifacts = Object.entries({
  BondNFT,
  BondNFTArtworkSwitcher,
  GenerativeEggArtwork,
  BondNFTArtworkCommon,
  ChickenOutGenerated1,
  ChickenOutArtwork,
  ChickenInGenerated1,
  ChickenInGenerated2,
  ChickenInGenerated3,
  ChickenInArtwork,
  BondNFTArtworkSwitcherTester,
  ChickenBondManager,
  ERC20Faucet,
  TestnetBAMM,
  TestnetCurvePool,
  TestnetCurveBasePool,
  MockYearnRegistry,
  TestnetYearnVault,
  BLUSDToken,
  TestnetCurveLiquidityGauge,
  Prankster,
  Underling,
  ERC20,
  MockTroveManager,
  MockLQTYStaking,
  MockPickleJar,
  MockCurveGaugeController
});

// XXX Vyper artifacts are different
const curveV2Artifacts = Object.entries({
  CurveToken,
  CurveCryptoSwap2ETH,
  // CurveLiquidityGauge,
  CurveFactory,
  CurveRegistrySwaps
}) as [string, { abi: Writable<JsonFragment>[]; bytecode: string }][];

const contracts = [...contractArtifacts, ...curveV2Artifacts].map(([contractName, { abi }]) => ({
  contractName,
  interface: new Interface(abi)
}));

const output = `
import { Log } from "@ethersproject/abstract-provider";
import { BigNumber, BigNumberish } from "@ethersproject/bignumber";
import { BytesLike } from "@ethersproject/bytes";
import { Overrides, CallOverrides, PayableOverrides, EventFilter } from "@ethersproject/contracts";

import { TypedContract, TypedContractFactory, TypedLogDescription } from "../typing";

${contracts.map(declareInterface).join("\n\n")}
`;

fs.mkdirSync(path.join("src", "generated"), { recursive: true });
fs.writeFileSync(path.join("src", "generated", "types.ts"), output);

fs.removeSync("artifacts");
fs.mkdirSync("artifacts", { recursive: true });

for (const [
  contractName,
  {
    abi,
    bytecode: { object: bytecode }
  }
] of contractArtifacts) {
  fs.writeFileSync(
    path.join("artifacts", `${contractName}.json`),
    JSON.stringify({ contractName, abi, bytecode }, undefined, 2)
  );
}

for (const [contractName, { abi, bytecode }] of curveV2Artifacts) {
  for (const fragment of abi) {
    // Ethers typings assume that gas can only be a string, but Vyper outputs a number
    // Let's just scrub it since we don't use it anyway
    delete fragment.gas;
  }

  fs.writeFileSync(
    path.join("artifacts", `${contractName}.json`),
    JSON.stringify({ contractName, abi, bytecode }, undefined, 2)
  );
}
