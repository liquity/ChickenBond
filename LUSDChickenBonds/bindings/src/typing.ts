import { LogDescription } from "@ethersproject/abi";
import { Log } from "@ethersproject/abstract-provider";
import { Signer } from "@ethersproject/abstract-signer";
import { BigNumber } from "@ethersproject/bignumber";

import {
  BaseContract,
  CallOverrides,
  ContractFactory,
  ContractInterface,
  ContractTransaction,
  PopulatedTransaction
} from "@ethersproject/contracts";

export interface TypedLogDescription<T = unknown> {
  blockNumber: number;
  blockHash: string;
  transactionIndex: number;
  transactionHash: string;
  logIndex: number;
  contractAddress: string;
  args: T;
}

// Remove type-unsafe "buckets of functions"
export type TypeSafeContract<T extends BaseContract> = Omit<
  T,
  "functions" | "callStatic" | "estimateGas" | "populateTransaction" | "filters"
>;

export type CallOverridesArg = [overrides?: CallOverrides];

export type TypeSafeContractWithMethods<T extends BaseContract, U, V> = TypeSafeContract<T> &
  U & {
    [P in keyof V]: V[P] extends (...args: infer A) => unknown
      ? (...args: A) => Promise<ContractTransaction>
      : never;
  } & {
    readonly callStatic: {
      [P in keyof V]: V[P] extends (...args: [...infer A, never]) => infer R
        ? (...args: [...A, ...CallOverridesArg]) => R
        : never;
    };

    readonly estimateGas: {
      [P in keyof V]: V[P] extends (...args: infer A) => unknown
        ? (...args: A) => Promise<BigNumber>
        : never;
    };

    readonly populateTransaction: {
      [P in keyof V]: V[P] extends (...args: infer A) => unknown
        ? (...args: A) => Promise<PopulatedTransaction>
        : never;
    };
  };

export class ContractWithEventParsing extends BaseContract {
  extractEvents(logs: Log[], name: string): TypedLogDescription[] {
    return logs
      .filter(log => log.address === this.address)
      .map(log => ({ log, parsedLog: this.interface.parseLog(log) }))
      .filter(({ parsedLog }) => parsedLog.name === name)
      .map(({ log, parsedLog }) => ({
        blockNumber: log.blockNumber,
        blockHash: log.blockHash,
        transactionIndex: log.transactionIndex,
        transactionHash: log.transactionHash,
        logIndex: log.logIndex,
        contractAddress: this.address,
        args: parsedLog.args
      }));
  }
}

export class ContractWithEventParsingFactory extends ContractFactory {
  static getContract(
    address: string,
    contractInterface: ContractInterface,
    signer?: Signer
  ): ContractWithEventParsing {
    return new ContractWithEventParsing(address, contractInterface, signer);
  }

  static fromSolidity(compilerOutput: any, signer?: Signer): ContractWithEventParsingFactory {
    // `fromSolidity()` internally uses `new this(...)`, which means it creates a
    // `ContractWithEventParsingFactory` for us.
    // It does mean we should be careful when overriding the constructor though.
    return super.fromSolidity(compilerOutput, signer) as ContractWithEventParsingFactory;
  }
}

export interface ContractWithEventParsingFactory {
  deploy(...args: any[]): Promise<ContractWithEventParsing>;
  attach(address: string): ContractWithEventParsing;
  connect(signer: Signer): ContractWithEventParsingFactory;
}

export type TypedContract<T = unknown, U = unknown> = TypeSafeContractWithMethods<
  ContractWithEventParsing,
  T,
  U
>;

export interface TypedContractFactory<
  T extends TypedContract = TypedContract,
  A extends unknown[] = unknown[]
> {
  deploy(...args: A): Promise<T>;
  attach(address: string): T;
  connect(signer: Signer): TypedContractFactory<T, A>;
}
