// Based on https://github.com/0xdef1/swap-comparison
// Run with:
// npx ts-node scripts/curve-repeg.ts
// and then:
// python3 ./scritps/plot_blusd.py
import Web3 from 'web3'
import _, { toInteger } from 'lodash'
import { sleep } from '../src/sleep'
import fs from 'fs'
const {parse} = require('csv-parse/sync');
import pThrottle from '../src/p-throttle'
const DATA_FILENAME='curve_repegs.csv'
const CRYPTOSWAP_ADDRESS = '0x74ED5d42203806c8CDCf2F04Ca5F60DC777b901c'
const CRYPTOSWAP_ABI = require('../abi/cryptoswap-abi.json')
const ERC20_ABI = require('../abi/erc20-abi.json')
const CRYPTOSWAP_LP_ADDRESS = '0x5ca0313D44551e32e0d7a298EC024321c4BC59B4'
const LUSD_3CRV_ADDRESS = '0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA';
const LUSD_3CRV_ABI = require('../abi/lusd3crv-abi.json')
const START_BLOCK = 15674054 // bLUSD AMM creation
const envRpcUrl = process.env.ETH_RPC_URL ?? "";
const web3 = new Web3(envRpcUrl)

main()

async function main() {
  let startBlock = START_BLOCK
  const fileHeaders = ['block', 'timestamp', 'date', 'price_scale', 'price_oracle', 'price_effective', 'price_lusd3crv', 'balances_blusd', 'balances_lusd_3crv', 'lp_supply', 'xcp_profit', 'virtual_price', 'fee', 'volume', 'sold_id', 'tokens_sold', 'bought_id', 'tokens_bought']

  const dataDir = `${__dirname}/../data/`;
  const dataFile = `${dataDir}${DATA_FILENAME}`;
  fs.mkdirSync(dataDir, { recursive: true });
  if (!fs.existsSync(dataFile)) {
    fs.writeFileSync(
      dataFile,
      `${fileHeaders.join(",")}\n`
    )
  } else {
    const fileContent = fs.readFileSync(dataFile, "utf8");
    const fileData = parse(fileContent, {
      delimiter: ',',
      columns: fileHeaders,
    });
    startBlock = Number(fileData[fileData.length - 1]['block']) + 1;
    //console.log('startBlock: ', startBlock)
  }

  let endBlock = await web3.eth.getBlockNumber()
  //console.log('startBlock: ', startBlock)
  //console.log('endBlock:   ', endBlock)
  //let endBlock = startBlock + 1000
  let batchSize = 100
  let numBatches = Math.ceil((endBlock - startBlock) / batchSize)
  for (var batch = 0; batch < numBatches; batch++) {
    let fromBlock = startBlock + (batch * batchSize)
    let toBlock = startBlock + (batch * batchSize) + batchSize - 1
    console.log(`Fetching ${fromBlock} - ${toBlock}`)
    await runBatch(fromBlock, toBlock)
    await sleep(1000)
  }
}

async function runBatch(fromBlock: number, toBlock: number) {
  const contract = new web3.eth.Contract(CRYPTOSWAP_ABI, CRYPTOSWAP_ADDRESS)
  const lp = new web3.eth.Contract(ERC20_ABI, CRYPTOSWAP_LP_ADDRESS)
  const lusd3crv = new web3.eth.Contract(LUSD_3CRV_ABI, LUSD_3CRV_ADDRESS)

  let trades = await contract.getPastEvents('TokenExchange', {
    fromBlock: fromBlock,
    toBlock: toBlock
  })

  const throttle = pThrottle({
    limit: 1,
    interval: 1000
  })

  async function fetchPrices(t: any) {
    let block = t.blockNumber
    let timestamp = (await web3.eth.getBlock(t.blockNumber)).timestamp
    let scale = (await contract.methods.price_scale().call({}, block)) / 1e18
    let oracle = (await contract.methods.price_oracle().call({}, block)) / 1e18
    let xcp_profit = (await contract.methods.xcp_profit().call({}, block)) / 1e18
    let virtual_price = (await contract.methods.virtual_price().call({}, block)) / 1e18
    let fee = (await contract.methods.fee().call({}, block)) / 1e10
    let balance_0 = (await contract.methods.balances(0).call({}, block)) / 1e18
    let balance_1 = (await contract.methods.balances(1).call({}, block)) / 1e18
    let lp_supply = (await lp.methods.totalSupply().call({}, block)) / 1e18

    const price_lusd3crv = (await lusd3crv.methods.calc_withdraw_one_coin('1000000000000000000', 0).call({}, block)) / 1e18;

    let volume = t.returnValues.sold_id == 0 ? t.returnValues.tokens_sold / 1e18 / scale
      : t.returnValues.sold_id == 1 ? t.returnValues.tokens_sold / 1e18 : 0

    let price_effective = t.returnValues.sold_id == 0 ? t.returnValues.tokens_sold / t.returnValues.tokens_bought
      : t.returnValues.sold_id == 1 ? t.returnValues.tokens_bought / t.returnValues.tokens_sold : 0
    return {
      block: block,
      timestamp: timestamp,
      date: new Date(toInteger(timestamp) * 1000).toISOString(),
      price_scale: scale,
      price_oracle: oracle,
      price_effective: price_effective,
      price_lusd3crv: price_lusd3crv,
      xcp_profit: xcp_profit,
      virtual_price: virtual_price,
      fee: fee,
      volume: volume,
      balances: [balance_0, balance_1],
      lp_supply: lp_supply,
      sold_id: t.returnValues.sold_id,
      tokens_sold: t.returnValues.tokens_sold / 1e18,
      bought_id: t.returnValues.bought_id,
      tokens_bought: t.returnValues.tokens_bought / 1e18}
  }

  let results: any[] = await Promise.all(
    trades.map(t =>
      throttle(() => fetchPrices(t))()
              )
  )

  results.forEach(r => writeData(DATA_FILENAME, r))
}

function writeData(filename: string, result: any) {
  fs.writeFileSync(
    `${__dirname}/../data/${filename}`,
    `${result.block},${result.timestamp},${result.date},${result.price_scale},${result.price_oracle},${result.price_effective},${result.price_lusd3crv},${result.balances[0]},${result.balances[1]},${result.lp_supply},${result.xcp_profit},${result.virtual_price},${result.fee},${result.volume},${result.sold_id},${result.tokens_sold},${result.bought_id},${result.tokens_bought}\n`,
    { flag: 'a+' }
  )
}
