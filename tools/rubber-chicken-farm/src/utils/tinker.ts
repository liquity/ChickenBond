import { Signer } from "@ethersproject/abstract-signer";
import { BigNumber } from "@ethersproject/bignumber";
import { ContractReceipt, ContractTransaction } from "@ethersproject/contracts";
import { JsonRpcProvider, Web3Provider, ExternalProvider } from "@ethersproject/providers";
import { Wallet } from "@ethersproject/wallet";
import { Decimal, Decimalish } from "@liquity/lib-base";

import {
  connectToContracts,
  deployAndSetupContracts,
  deployNFTArtwork,
  LUSDChickenBondContracts,
  LUSDChickenBondDeploymentManifest,
  LUSDChickenBondDeploymentResult
} from "@liquity/lusd-chicken-bonds-bindings";

import goerli from "@liquity/lusd-chicken-bonds-bindings/deployments/goerli.json";
import rinkeby from "@liquity/lusd-chicken-bonds-bindings/deployments/rinkeby.json";

const manifests: { [network: string]: LUSDChickenBondDeploymentManifest } = {
  goerli,
  rinkeby
};

const localProvider = new JsonRpcProvider("http://localhost:8545");

const localDeployer = new Wallet(
  // The only initial account on OpenEthereum's dev chain
  // "0x4d5db4107d237df6a3d58ee5f70ae63d73d7658d4026f2eefd2f204c81682cb7",
  // Account #1 on Hardhat/Anvil
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
  localProvider
);

export interface LUSDChickenBondTokenPair {
  LUSD: number;
  bLUSD: number;
}

export interface LUSDChickenBondBalances extends LUSDChickenBondTokenPair {
  LP: number;
  bondNFT: number;
}

const statuses = ["nonExistent", "active", "chickenedOut", "chickenedIn"] as const;

export type LUSDChickenBondStatus = typeof statuses[number];

const lookupStatus = (status: number): LUSDChickenBondStatus => statuses[status];

export interface LUSDChickenBondData extends LUSDChickenBondTokenPair {
  bondID: number;
  startTime: number;
  endTime: number;
  initialHalfDna: string;
  finalHalfDna: string;
  status: LUSDChickenBondStatus;
}

export interface LUSDChickenBondBuckets {
  pendingSP: number;
  acquiredSP: number;
  acquiredCurve: number;
  permanent: number;
}

export interface LUSDChickenBondGlobalFunctions {
  deploy(): Promise<LUSDChickenBondDeploymentResult>;
  connect(user: Signer): LUSDChickenBondContracts;
  local(): void;
  testnet(network?: string): void;

  tap(): Promise<void>;
  balance(address?: string): Promise<LUSDChickenBondBalances>;
  allowance(spender?: string, owner?: string): Promise<number>;
  send(to: string, amount: Decimalish): Promise<void>;

  bond(bondID?: number): Promise<LUSDChickenBondData>;
  bonds(address?: string): Promise<number[]>;
  metadata(bondID?: number): Promise<unknown>;
  artwork(bondID?: number): Promise<void>;
  backingRatio(): Promise<number>;
  buckets(): Promise<LUSDChickenBondBuckets>;

  createBond(amount: Decimalish): Promise<number>;
  chickenIn(bondID?: number): Promise<void>;
  chickenOut(bondID?: number): Promise<void>;

  redeem(amount: Decimalish): Promise<void>;
  redeemAll(): Promise<void>;

  deployNFTArtwork(): Promise<unknown>;
  setNFTArtwork(address: string): Promise<void>;
  migrate(): Promise<void>;

  shiftCountdown(): Promise<void>;
  shiftSPToCurve(amount: number): Promise<void>;
  shiftCurveToSP(amount: number): Promise<void>;

  spot(): Promise<number>;
  deposit(bLUSDAmount?: number, lusdAmount?: number): Promise<void>;
  withdraw(LP?: number): Promise<void>;
  swapLUSD(amount?: number): Promise<void>;
  swapBLUSD(amount?: number): Promise<void>;

  harvest(): Promise<void>;

  trace(txHash: string): Promise<unknown>;
  warp(timestamp: number): Promise<unknown>;
  mine(): Promise<unknown>;
  day(k: number): Promise<unknown>;
  timestamp(): Promise<number>;
}

export interface EventListener {
  (...args: any[]): void;
}

export interface EventEmitter {
  on(event: string, listener: EventListener): this;
  removeListener(event: string, listener: EventListener): this;
}

export interface LUSDChickenBondGlobals extends LUSDChickenBondGlobalFunctions {
  deployment: LUSDChickenBondDeploymentResult;
  contracts: LUSDChickenBondContracts;
  user: Signer;
  bondID: number;

  ethereum: ExternalProvider & EventEmitter;
  _networkChangeListener?: EventListener;
}

const receipt =
  <A extends unknown[]>(txFunc: (...args: A) => Promise<ContractTransaction>) =>
  (...args: A) =>
    txFunc(...args).then(tx => tx.wait());

const sequence = (
  first: () => Promise<ContractTransaction>,
  ...rest: ((prevReceipt: ContractReceipt) => Promise<ContractTransaction>)[]
) => rest.map(receipt).reduce((p, f) => p.then(f), receipt(first)());

const numberifyBigNumber = (bn: BigNumber) => bn.toNumber();
const numberifyDecimal = (bn: BigNumber) => Number(Decimal.fromBigNumberString(bn.toHexString()));

export const getLUSDChickenBondGlobalFunctions = (
  globalObj: LUSDChickenBondGlobals,
  provider: JsonRpcProvider,
  deployer: Signer
): LUSDChickenBondGlobalFunctions => ({
  async deploy() {
    globalObj.deployment = await deployAndSetupContracts(deployer, {
      log: true,
      config: {
        yearnGovernanceAddress: await deployer.getAddress() // let us play around with migration ;-)
      }
    });

    globalObj.connect(deployer);

    return globalObj.deployment;
  },

  connect(user): LUSDChickenBondContracts {
    globalObj.user = user.connect(provider);
    globalObj.contracts = connectToContracts(
      globalObj.user,
      globalObj.deployment.manifest.addresses
    );

    return globalObj.contracts;
  },

  local() {
    installLUSDChickenBonds(globalObj);

    if (globalObj._networkChangeListener) {
      globalObj.ethereum.removeListener("chainChanged", globalObj._networkChangeListener);
      delete globalObj._networkChangeListener;
    }
  },

  testnet(network = "rinkeby") {
    if (!(network in manifests)) {
      throw new Error(`Unsupported network "${network}"`);
    }

    const manifest = manifests[network];
    const provider = new Web3Provider(globalObj.ethereum);
    const signer = provider.getSigner();
    installLUSDChickenBonds(globalObj, provider, signer);

    globalObj.user = signer;
    globalObj.contracts = connectToContracts(globalObj.user, manifest.addresses);

    provider.getNetwork().then(actualNetwork => {
      if (actualNetwork.chainId !== manifest.chainId) {
        console.warn(`Warning: wallet is set to wrong network (should be ${network})`);
      }
    });

    if (globalObj._networkChangeListener) {
      globalObj.ethereum.removeListener("chainChanged", globalObj._networkChangeListener);
    }

    globalObj._networkChangeListener = () => {
      console.info("Network changed");
      globalObj.testnet(network);
    };

    globalObj.ethereum.on("chainChanged", globalObj._networkChangeListener);
  },

  async tap() {
    await receipt(() => globalObj.contracts.lusdToken.tap())();
  },

  async balance(address) {
    const { lusdToken, bLUSDToken, bLUSDCurveToken, bondNFT } = globalObj.contracts;

    address = address ?? (await globalObj.user.getAddress());

    const [LUSD, bLUSD, LP, nftCount] = await Promise.all([
      lusdToken.balanceOf(address),
      bLUSDToken.balanceOf(address),
      bLUSDCurveToken.balanceOf(address),
      bondNFT.balanceOf(address)
    ]);

    return {
      LUSD: numberifyDecimal(LUSD),
      bLUSD: numberifyDecimal(bLUSD),
      LP: numberifyDecimal(LP),
      bondNFT: nftCount.toNumber()
    };
  },

  async allowance(spender = globalObj.contracts.chickenBondManager.address, owner) {
    owner = owner ?? (await globalObj.user.getAddress());
    return globalObj.contracts.lusdToken.allowance(owner, spender).then(numberifyDecimal);
  },

  async send(to: string, amount: Decimalish) {
    await receipt(() => globalObj.contracts.lusdToken.transfer(to, Decimal.from(amount).hex))();
  },

  async createBond(amount) {
    const amountHex = Decimal.from(amount).hex;
    const { lusdToken, chickenBondManager, bondNFT } = globalObj.contracts;

    const receipt = await sequence(
      () => lusdToken.approve(chickenBondManager.address, amountHex),
      () => chickenBondManager.createBond(amountHex)
    );

    const [mint] = bondNFT.extractEvents(receipt.logs, "Transfer");
    return (globalObj.bondID = mint.args.tokenId.toNumber());
  },

  async bond(bondID = globalObj.bondID) {
    const { chickenBondManager } = globalObj.contracts;

    const [bondData, accruedBLUSD] = await Promise.all([
      chickenBondManager.getBondData(bondID),
      chickenBondManager.calcAccruedBLUSD(bondID)
    ]);

    return {
      bondID,
      LUSD: numberifyDecimal(bondData.lusdAmount),
      bLUSD: numberifyDecimal(accruedBLUSD),
      startTime: bondData.startTime.toNumber(),
      endTime: bondData.endTime.toNumber(),
      initialHalfDna: bondData.initialHalfDna.toHexString(),
      finalHalfDna: bondData.finalHalfDna.toHexString(),
      status: lookupStatus(bondData.status)
    };
  },

  async bonds(address) {
    const { bondNFT } = globalObj.contracts;

    const resolvedAddress = address ?? (await globalObj.user.getAddress());
    const count = await bondNFT.balanceOf(resolvedAddress).then(numberifyBigNumber);

    return Promise.all(
      [...new Array(count).keys()].map(i =>
        bondNFT.tokenOfOwnerByIndex(resolvedAddress, i).then(numberifyBigNumber)
      )
    );
  },

  async metadata(bondID = globalObj.bondID) {
    const expectedUriScheme = "data:application/json;base64,";
    const tokenURI = await globalObj.contracts.bondNFT.tokenURI(bondID);

    if (!tokenURI.startsWith(expectedUriScheme)) {
      throw new Error("Unexpected tokenURI format");
    }

    return JSON.parse(atob(tokenURI.slice(expectedUriScheme.length)));
  },

  async artwork(bondID) {
    const scale = 50;
    const expectedUriScheme = "data:image/svg+xml;base64,";
    const metadata = (await globalObj.metadata(bondID)) as any;
    const image = metadata.image as unknown;

    if (typeof image !== "string" || !image.startsWith(expectedUriScheme)) {
      throw new Error("Unexpected image format");
    }

    console.log(
      "%c ",
      ` display: block;
        width: ${5.5 * scale}px;
        height: ${7.5 * scale}px;
        background-color: #${metadata.background_color ?? "ffffff"};
        background-image: url(${image});
        background-position: center;
        background-repeat: no-repeat;
        background-size: ${5 * scale}px ${7 * scale}px`
    );
  },

  async chickenIn(bondID = globalObj.bondID) {
    await receipt(() => globalObj.contracts.chickenBondManager.chickenIn(bondID))();
  },

  async chickenOut(bondID = globalObj.bondID) {
    await receipt(() =>
      globalObj.contracts.chickenBondManager.chickenOut(bondID, Decimal.ZERO.hex)
    )();
  },

  async redeem(amount) {
    await receipt(() =>
      globalObj.contracts.chickenBondManager.redeem(Decimal.from(amount).hex, Decimal.ZERO.hex)
    )();
  },

  async redeemAll() {
    const { chickenBondManager, bLUSDToken } = globalObj.contracts;

    await receipt(async () =>
      chickenBondManager.redeem(
        await bLUSDToken.balanceOf(await globalObj.user.getAddress()),
        Decimal.ZERO.hex
      )
    )();
  },

  deployNFTArtwork: () => deployNFTArtwork(globalObj.user, { log: true }),

  async setNFTArtwork(address: string) {
    await receipt(() => globalObj.contracts.bondNFT.setArtworkAddress(address))();
  },

  async migrate() {
    await receipt(() => globalObj.contracts.chickenBondManager.activateMigration())();
  },

  async shiftCountdown() {
    await receipt(() => globalObj.contracts.chickenBondManager.startShifterCountdown())();
  },

  async shiftSPToCurve(amount) {
    await receipt(() =>
      globalObj.contracts.prankster.shiftLUSDFromSPToCurve(Decimal.from(amount).hex)
    )();
  },

  async shiftCurveToSP(amount) {
    await receipt(() =>
      globalObj.contracts.prankster.shiftLUSDFromCurveToSP(Decimal.from(amount).hex)
    )();
  },

  backingRatio: () =>
    globalObj.contracts.chickenBondManager.calcSystemBackingRatio().then(numberifyDecimal),

  async buckets() {
    const { chickenBondManager } = globalObj.contracts;

    const [pendingSP, acquiredSP, acquiredCurve, permanent] = await Promise.all([
      chickenBondManager.getPendingLUSD().then(numberifyDecimal),
      chickenBondManager.getAcquiredLUSDInSP().then(numberifyDecimal),
      chickenBondManager.getAcquiredLUSDInCurve().then(numberifyDecimal),
      chickenBondManager.getPermanentLUSD().then(numberifyDecimal)
    ]);

    return {
      pendingSP,
      acquiredSP,
      acquiredCurve,
      permanent
    };
  },

  spot: () => globalObj.contracts.bLUSDCurvePool.get_dy(0, 1, 1).then(numberifyDecimal),

  async deposit(bLUSDAmount, lusdAmount) {
    const { lusdToken, bLUSDToken, bLUSDCurvePool } = globalObj.contracts;

    const dBLUSDAmount = bLUSDAmount
      ? Decimal.from(bLUSDAmount)
      : Decimal.fromBigNumberString(
          (await bLUSDToken.balanceOf(await globalObj.user.getAddress())).toHexString()
        );

    const dLUSDAmount = lusdAmount ? Decimal.from(lusdAmount) : dBLUSDAmount.mul(1.2);

    await sequence(
      () => lusdToken.approve(bLUSDCurvePool.address, dLUSDAmount.hex),
      () => bLUSDToken.approve(bLUSDCurvePool.address, dBLUSDAmount.hex),
      () =>
        bLUSDCurvePool["add_liquidity(uint256[2],uint256)"]([dBLUSDAmount.hex, dLUSDAmount.hex], 0)
    );
  },

  async withdraw(LP) {
    const { bLUSDCurveToken, bLUSDCurvePool } = globalObj.contracts;

    const dLP = LP
      ? Decimal.from(LP)
      : Decimal.fromBigNumberString(
          (await bLUSDCurveToken.balanceOf(await globalObj.user.getAddress())).toHexString()
        );

    await bLUSDCurvePool["remove_liquidity(uint256,uint256[2])"](dLP.hex, [0, 0]);
  },

  async swapLUSD(amount) {
    const { lusdToken, bLUSDCurvePool } = globalObj.contracts;

    const dLUSDAmount = amount
      ? Decimal.from(amount)
      : Decimal.fromBigNumberString(
          (await lusdToken.balanceOf(await globalObj.user.getAddress())).toHexString()
        );

    await sequence(
      () => lusdToken.approve(bLUSDCurvePool.address, dLUSDAmount.hex),
      () => bLUSDCurvePool["exchange(uint256,uint256,uint256,uint256)"](1, 0, dLUSDAmount.hex, 0)
    );
  },

  async swapBLUSD(amount) {
    const { bLUSDToken, bLUSDCurvePool } = globalObj.contracts;

    const dBLUSDAmount = amount
      ? Decimal.from(amount)
      : Decimal.fromBigNumberString(
          (await bLUSDToken.balanceOf(await globalObj.user.getAddress())).toHexString()
        );

    await sequence(
      () => bLUSDToken.approve(bLUSDCurvePool.address, dBLUSDAmount.hex),
      () => bLUSDCurvePool["exchange(uint256,uint256,uint256,uint256)"](0, 1, dBLUSDAmount.hex, 0)
    );
  },

  async harvest() {
    await receipt(() => globalObj.contracts.prankster.harvest())();
  },

  trace: txHash => provider.send("trace_transaction", [txHash]),
  warp: timestamp => provider.send("evm_setNextBlockTimestamp", [timestamp]),
  mine: () => provider.send("evm_mine", []),

  day: k =>
    globalObj.warp(
      globalObj.deployment.manifest.deploymentTimestamp +
        k * globalObj.deployment.config.realSecondsPerFakeDay
    ),

  timestamp: () =>
    provider
      .call({
        data:
          "0x" +
          "42" + //// TIMESTAMP
          "6000" + // PUSH1 0
          "52" + //// MSTORE
          "6004" + // PUSH1 4
          "601c" + // PUSH1 28
          "F3" ////// RETURN
      })
      .then(x => parseInt(x, 16))
});

export const installLUSDChickenBonds = (
  globalObj: LUSDChickenBondGlobals,
  provider: JsonRpcProvider = localProvider,
  deployer: Signer = localDeployer
) =>
  Object.assign(globalObj, {
    // tinkering with the real Solidity implementation
    provider,
    deployer,
    ...getLUSDChickenBondGlobalFunctions(window, provider, deployer)
  });
