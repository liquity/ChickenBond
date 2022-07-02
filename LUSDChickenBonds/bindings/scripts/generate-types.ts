import fs from "fs-extra";
import path from "path";

import { Interface, ParamType } from "@ethersproject/abi";

import BondNFT from "../../out/BondNFT.sol/BondNFT.json";
import ChickenBondManager from "../../out/ChickenBondManager.sol/ChickenBondManager.json";
import ERC20 from "../../out/ERC20.sol/ERC20.json";
import LUSDTokenTester from "../../out/LUSDTokenTester.sol/LUSDTokenTester.json";
import MockBAMMSPVault from "../../out/MockBAMMSPVault.sol/MockBAMMSPVault.json";
import MockCurvePool from "../../out/MockCurvePool.sol/MockCurvePool.json";
import MockYearnRegistry from "../../out/MockYearnRegistry.sol/MockYearnRegistry.json";
import MockYearnVault from "../../out/MockYearnVault.sol/MockYearnVault.json";
import BLUSDToken from "../../out/BLUSDToken.sol/BLUSDToken.json";
import MockCurveLiquidityGaugeV4 from "../../out/MockCurveLiquidityGaugeV4.sol/MockCurveLiquidityGaugeV4.json";

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
  const constructorParams = [
    ...declareParams(deploy.inputs),
    `_overrides?: ${deploy.payable ? "PayableOverrides" : "Overrides"}`
  ];

  return [
    `interface ${contractName}Calls {`,
    ...Object.values(functions)
      .filter(({ constant }) => constant)
      .map(({ name, inputs, outputs }) => {
        const params = [...declareParams(inputs), `_overrides?: CallOverrides`];

        let returnType: string;
        if (!outputs || outputs.length == 0) {
          returnType = "void";
        } else if (outputs.length === 1) {
          returnType = getType(outputs[0], false);
        } else {
          returnType = getTupleType(outputs, false);
        }

        return `  ${name}(${params.join(", ")}): Promise<${returnType}>;`;
      }),
    "}\n",

    `interface ${contractName}Transactions {`,
    ...Object.values(functions)
      .filter(({ constant }) => !constant)
      .map(({ name, payable, inputs, outputs }) => {
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

        return `  ${name}(${params.join(", ")}): Promise<${returnType}>;`;
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
  ChickenBondManager,
  ERC20,
  LUSDTokenTester,
  MockBAMMSPVault,
  MockCurvePool,
  MockYearnRegistry,
  MockYearnVault,
  BLUSDToken,
  MockCurveLiquidityGaugeV4
});

const contracts = contractArtifacts.map(([contractName, { abi }]) => ({
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
