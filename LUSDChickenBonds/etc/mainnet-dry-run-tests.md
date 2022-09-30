# Deployment addresses

```
{
    "BLUSD_LUSD_AMM_ADDRESS": "0xec5ffef96c3EdEdE587DB2efA3ab4Deec414cE8F",
    "BLUSD_LUSD_LP_TOKEN": "0xE9Af51E6591992de6976cCcbB902D096776E9be4",
    "BLUSD_LUSD_AMM_STAKING_ADDRESS": "0x79DbB869e4f00821927785D21315219Edb016082",
    "BLUSD_3POOL_AMM_ADDRESS": "0x52F05C70d86662204C7222C35000747b177C393a",
    "BLUSD_3POOL_LP_TOKEN": "0xB85E0C55e86803B9D15e67BEaDbB66510D4d3317",
    "BLUSD_3POOL_AMM_STAKING_ADDRESS": "0x2620Ea805fb2C0adfc505967A8860eE30Fd01754",
    "BLUSD_TOKEN_ADDRESS": "0x76F7774139bf0097d2882C41AF5A37717e3641A7",
    "BOND_NFT_ADDRESS": "0xf80678718187a9e29E63A1f5Af61369ecc8a8a0C",
    "BOND_NFT_INITIAL_ARTWORK_ADDRESS": "0xfDF1468A6b04307927D83dEf4106dd64839b353b",
    "CHICKEN_BOND_MANAGER_ADDRESS": "0x89058630b53228aDCC77690586cFb3C74F08803C"
}
```
# Deployment transactions

[bLUSD token](https://etherscan.io/tx/0xd91dbd25e042cfc0e696c97ef5804daca210a84f5efd504667a8738c7b4200f6)

[Egg NFT artwork](https://etherscan.io/tx/0x1c0e5b0c382a3e0b51da78d43c2eba6ef19e6335ecc98f74936a1347e9a3d3b2)

[BondNFT](https://etherscan.io/tx/0xbf96fbf9e1cc7b6c51c9312c230ab1c8f04c8f51a41df98f4c25ba403005f944)

[bLUSD/LUSD Curve pool](https://etherscan.io/tx/0x122fdfa62f3e097e106995ec430671f1a064e645959de3a8d71c01f241a4574b)

[bLUSD/LUSD Gauge](https://etherscan.io/tx/0xaf07a32220f00356d1618a8c6360d5a7a6d25bdc29ba1cd0f8d8a21bea18b713)

[bLUSD/3pool Curve pool](https://etherscan.io/tx/0xc7a627a9c86a9490a9f79e381f423a240f3505beabbf47d9af58e93173c15ac0)

[bLUSD/3pool Gauge](https://etherscan.io/tx/0x8b6327c89b8abdd381b70bd1ca32584e666588311ef7a71e24d58e8be4009573)

(Note: bLUSD/3pool is not connected, as LUSD one is, to ChickenBondManager, so it’s not getting rewards)

[ChickenBondManager](https://etherscan.io/tx/0x56f088f6737acbb158d9609563144090c51c8781cc1f9c807a1c06265e2767cd)

[Connect BondNFT to ChickenBondManager](https://etherscan.io/tx/0xc4251d2694b70f54d6655a3fdfb2c6efe2bd6f0fcff87d409b13e3f6b951dcf8)

[Connect bLUSD to ChickenBondManager](https://etherscan.io/tx/0x878af4938b53de72d5c9083664abad2c002164bf58051ebc63661cc50581b6d2)

[Add reward to LUSD Gauge](https://etherscan.io/tx/0xd01058df8f293d989a9718265dca699ef7f2070f4ec836029a2e3ae5b721d07d)

[Add reward to 3pool Gauge](https://etherscan.io/tx/0x445bf355cbe342723e876bd3fdac7c8546dc5820e5ce5fc87a395f95aacd09b1)

[Connect B.AMM to ChickenBondManager](https://etherscan.io/tx/0xe5375bafd8dce35541228ae14e0f209164eeb9eed9160984b799d3055e822b13)

# Tests

[Create bond 1](https://etherscan.io/tx/0xecdbeba69e4bfc278b41bccaa7759e38e613dcd31a17e2b8b50af0e420cc5ec2)

[Failed chicken In during bootstrap period](https://etherscan.io/tx/0x73876384ee74ab706db31df4fe65608836a2f5554e94ff02923f21298e4d103c)

[Create bond (with permit) 2](https://etherscan.io/tx/0x39a3b741f9b33d0d1b5b48c026db0cf5888d2a834b21b97a2aedb88faa6bcb5e)

[Chicken out bond id 2 (still bootstrap period)](https://etherscan.io/tx/0x3363bcea561c580199d6a3733c7b52a72ba04c702e12b2cc18cc76758be0e762)

[Failed chicken In during bootstrap period, 1h after launch, but not after bond creation](https://etherscan.io/tx/0x6a09034133f9438028082289f902eeb0a58c4a3fd899e8a7e75dc65853ad5df9)

[Chicken In bond id 1](https://etherscan.io/tx/0x3cc1a155b0ad78a5af5951417827f6ca13fdbe9dab6633876dd964756bafd871)

[Cannot redeem below min supply](https://etherscan.io/tx/0x866924c65d80a7055f810519984e6a62c86b32fd7f08f45ad0bbd77ade68b034)

[Failed redemption during bootstrap period](https://etherscan.io/tx/0x65be3b5aac624613a5d0651118fae7d2bc0d02bf7d357c429ba04e82ada83ab8)

[Redemption](https://etherscan.io/tx/0x078895c1863a458f381243daae10f4709a874f5862a5eb99a23698907a3769dd)

[Failed shift from SP to Curve](https://etherscan.io/tx/0xcd44eb5ed6d553aea57ece6b4c0479c5fb95800f743b96a74ae9fc1acda012f5)

[Start shift window](https://etherscan.io/tx/0x823e11b8e30091673c485b700fd38773eb8c1de6a1af1021e514761a3514f0c2)

[Shift from SP to Curve](https://etherscan.io/tx/0x9d62302b754643e95fab083d85d361da6997abf40d33ae7f41b56369787efec0)

[Shift from Curve to SP](https://etherscan.io/tx/0x975810f9ff86c2cc28765e26470583b1e8b85505f2f7973d110d88ab3831e7ee)

[Add liquidity to bLUSD/LUSD pool](https://etherscan.io/tx/0xc0ee0a518fd024f527c59223883dcb1a7abf0544e2a0429974161715ccaadebd)

[Deposit LP tokens to Gauge](https://etherscan.io/tx/0x58b4c63f70b076ae44fdbaaa4b1d01dbf5c6258355972de0997e27528ee84bd2)

TODO:
migration