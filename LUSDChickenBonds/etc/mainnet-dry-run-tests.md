# First deployment, with bLUSD/LUSD AMM (2022-09-28)

## Deployment addresses

```
{
    "BLUSD_LUSD_AMM_ADDRESS": "0xec5ffef96c3EdEdE587DB2efA3ab4Deec414cE8F",
    "BLUSD_LUSD_LP_TOKEN": "0xE9Af51E6591992de6976cCcbB902D096776E9be4",
    "BLUSD_LUSD_AMM_STAKING_ADDRESS": "0x79DbB869e4f00821927785D21315219Edb016082",
    "BLUSD_3CRV_AMM_ADDRESS": "0x52F05C70d86662204C7222C35000747b177C393a",
    "BLUSD_3CRV_LP_TOKEN": "0xB85E0C55e86803B9D15e67BEaDbB66510D4d3317",
    "BLUSD_3CRV_AMM_STAKING_ADDRESS": "0x2620Ea805fb2C0adfc505967A8860eE30Fd01754",
    "BLUSD_TOKEN_ADDRESS": "0x76F7774139bf0097d2882C41AF5A37717e3641A7",
    "BOND_NFT_ADDRESS": "0xf80678718187a9e29E63A1f5Af61369ecc8a8a0C",
    "BOND_NFT_INITIAL_ARTWORK_ADDRESS": "0xfDF1468A6b04307927D83dEf4106dd64839b353b",
    "CHICKEN_BOND_MANAGER_ADDRESS": "0x89058630b53228aDCC77690586cFb3C74F08803C"
}
```

## Deployment transactions

[bLUSD token](https://etherscan.io/tx/0xd91dbd25e042cfc0e696c97ef5804daca210a84f5efd504667a8738c7b4200f6)

[Egg NFT artwork](https://etherscan.io/tx/0x1c0e5b0c382a3e0b51da78d43c2eba6ef19e6335ecc98f74936a1347e9a3d3b2)

[BondNFT](https://etherscan.io/tx/0xbf96fbf9e1cc7b6c51c9312c230ab1c8f04c8f51a41df98f4c25ba403005f944)

[bLUSD/LUSD Curve pool](https://etherscan.io/tx/0x122fdfa62f3e097e106995ec430671f1a064e645959de3a8d71c01f241a4574b)

[bLUSD/LUSD pool in Curve](https://curve.fi/factory-crypto/120)

[bLUSD/LUSD Gauge](https://etherscan.io/tx/0xaf07a32220f00356d1618a8c6360d5a7a6d25bdc29ba1cd0f8d8a21bea18b713)

[bLUSD/3CRV Curve pool](https://etherscan.io/tx/0xc7a627a9c86a9490a9f79e381f423a240f3505beabbf47d9af58e93173c15ac0)

[bLUSD/3CRV pool in Curve](https://curve.fi/factory-crypto/121)

[bLUSD/3CRV Gauge](https://etherscan.io/tx/0x8b6327c89b8abdd381b70bd1ca32584e666588311ef7a71e24d58e8be4009573)

(Note: bLUSD/3CRV is not connected, as LUSD one is, to ChickenBondManager, so it’s not getting rewards)

[ChickenBondManager](https://etherscan.io/tx/0x56f088f6737acbb158d9609563144090c51c8781cc1f9c807a1c06265e2767cd)

[Connect BondNFT to ChickenBondManager](https://etherscan.io/tx/0xc4251d2694b70f54d6655a3fdfb2c6efe2bd6f0fcff87d409b13e3f6b951dcf8)

[Connect bLUSD to ChickenBondManager](https://etherscan.io/tx/0x878af4938b53de72d5c9083664abad2c002164bf58051ebc63661cc50581b6d2)

[Add reward to LUSD Gauge](https://etherscan.io/tx/0xd01058df8f293d989a9718265dca699ef7f2070f4ec836029a2e3ae5b721d07d)

[Add reward to 3CRV Gauge](https://etherscan.io/tx/0x445bf355cbe342723e876bd3fdac7c8546dc5820e5ce5fc87a395f95aacd09b1)

[Connect B.AMM to ChickenBondManager](https://etherscan.io/tx/0xe5375bafd8dce35541228ae14e0f209164eeb9eed9160984b799d3055e822b13)

## Tests

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

[Deposit LP tokens to bLUSD/LUSD Gauge](https://etherscan.io/tx/0x58b4c63f70b076ae44fdbaaa4b1d01dbf5c6258355972de0997e27528ee84bd2)

Earning rewards from Gauge:

![Screenshot_20220930_183354](https://user-images.githubusercontent.com/701095/193317481-00cda2a9-9cf8-4a8b-a9e6-213ac0e0d26a.png)

[Withdraw LP tokens from bLUSD/LUSD Gauge](https://etherscan.io/tx/0x0e16b7f71904872ad61aa540da8e12895d5f1b9158b92e0b27e3dfea4460971b)

[Remove liquidity from bLUSD/LUSD pool](https://etherscan.io/tx/0x47064cdbc7d8a952c788773e1558e4164a926df852b23e9beca43232c43d6383)

[Add liquidity to bLUSD/3CRV pool](https://etherscan.io/tx/0x8a8bc52cbfc2c85d27b70de65fee37f93ea12c3a86d0350824acda07ed8953de)

[Deposit LP tokens to bLUSD/3CRV Gauge](https://etherscan.io/tx/0x0d5a8bfad2b4a8666c16dea55c3cd7f7dc3438074407181727ccb4ae195597c4)

[Activate migration](https://etherscan.io/tx/0x5e4f02def161ac4414bfe4884e766fa970f9261785ee34d2f795df59513197c7)

[Cannot activate migration twice](https://etherscan.io/tx/0x5bf3f4a40ba21ba19a815ff34f6d68ecb57f28a219e88d871972c93fda761634)

[Redemption after migration](https://etherscan.io/tx/0x052cd3b89d48ac0d00aa0b07b5e6010628344d4335509aa60b39f05037524bc9)

[Swap LUSD to bLUSD through 3CRV](https://etherscan.io/tx/0x9688d2212586ccfcc00991096cd7fdf03f870abbdc7211c1bfc136594a9b5247)

[Swap bLUSD to LUSD through 3CRV](https://etherscan.io/tx/0xbbfad68f42a881c860b64becafead7e6fa77d087492e0831a9ca7c66a68758fb)

[Withdraw LP tokens from bLUSD/3CRV Gauge](https://etherscan.io/tx/0x5dc0b08796d268306bd68c081a631c4d32125e62fab409e8f19d219075aacecc)

[Remove liquidity from bLUSD/3CRV pool](https://etherscan.io/tx/0x78d8b1437a5e0b1b7b061424f82f9a77ca3da77d8b8960447beec2e79d5b27f1)

[Withdraw from Yearn Curve vault after migration](https://etherscan.io/tx/0x99a62ffb15734b3efa7bb364bf7933c91b50997cfae0670b37ca7765807fc142)

[Withdraw form Curve pool after migration](https://etherscan.io/tx/0x26982cd473a121d571db4f2e63047fa09499fa4f7f9c531c01693a80305effb8)

# Second deployment, with bLUSD/LUSD-3CRV AMM (2022-10-03)

## Deployment addresses

```
{
    "BAMM_ADDRESS": "0xe420cF281E567cb144838435Bb5D6b482c102e63",
    "BLUSD_AMM_ADDRESS": "0xF4A3cca34470b5Ba21E2bb1eD365ACf68B4d4598",
    "BLUSD_AMM_STAKING_ADDRESS": "0x8bCf6C7A49045E9f78648F9969c4bd2f12F8C504",
    "BLUSD_TOKEN_ADDRESS": "0x1E2391a261217c93D09Ff3Ae9aB1903EA237BdA8",
    "BOND_NFT_ADDRESS": "0x5d49599F6Ce3FE92C358055486Ab21FDCd8f52f3",
    "BOND_NFT_INITIAL_ARTWORK_ADDRESS": "0x0cB5727A6A8Cb8a01C1b693d7A18119A3542dC42",
    "CHICKEN_BOND_MANAGER_ADDRESS": "0x6EA66D267234dC5ABfcC9885765a1e2E50073A2A"
}
```

## Deployment transactions

[B.AMM](https://etherscan.io/tx/0xf38599c29942f91f790b15b92b39fbfe3db529016632ef1986ed9430dacbb92a)

[bLUSD token](https://etherscan.io/tx/0xb946724a48bf399fd90e8dfaaad7db665f4f994ef75fd085716e03fd11f83106)

[Egg NFT artwork](https://etherscan.io/tx/0xb1e277515dc591b744b463acae274bdbefc55ea1a565e9a98b036ceca50d7e1b)

[BondNFT](https://etherscan.io/tx/0xb7eeb1096e1f78ae4de5484019a662e9a210378a64170c9f9e2adc28d44aceda)

[bLUSD/LUSD-3CRV Curve pool](https://etherscan.io/tx/0x1099f9a61351dd698f66e2f01b4b78a4dff6da1305527eb5e43421addececb76)

[bLUSD/LUSD-3CRV pool in Curve](https://curve.fi/factory-crypto/131)

[bLUSD/LUSD-3CRV Gauge](https://etherscan.io/tx/0x0ae96abe5a0d36bab9b8c6e21ebfd015c2d00f13ec2207d3e2a7df40f77096da)

[ChickenBondManager](https://etherscan.io/tx/0x19cb5ec3a9f56fe40c20be7ced423a48d7a9d251446f7c88bc267989b805ca15)

[Connect BondNFT to ChickenBondManager](https://etherscan.io/tx/0x4b166881abaab72d5bce48db64c656b011c146a43639887920b256c6bdb8e0a0)

[Connect bLUSD to ChickenBondManager](https://etherscan.io/tx/0xacb7ccea73f2af3e0c8292e2a514510fddb416555a789bfa07f1223de3e7f481)

[Add reward to LUSD-3CRV Gauge](https://etherscan.io/tx/0x3ce286b3b49c6a74d9278ea64112896d6d1f1faada14538b87da953e6ab27cad)

[Connect B.AMM to ChickenBondManager](https://etherscan.io/tx/0xe66acd86e0a36353a96951c511fc26e243223ab37964ecf9a0c584abce09a308)

### Final Artwork

[BondNFTArtworkSwitcher](https://etherscan.io/tx/0x5b88cc81bf4130d3afbeee913b68e61e9a453a2b19a49c2ed1b9799fb760175b)

[BondNFTArtworkCommon](https://etherscan.io/tx/0xa5986a29252bff5652245d44e6b616ff40afcdffa1d6d35bbec2551fbe16ba8e)

[ChickenOutGenerated1](https://etherscan.io/tx/0x074845224915e8a19ba12d38d405ac08017bec670c7ec075b05a430509c41a20)

[ChickenOutArtwork](https://etherscan.io/tx/0x839932a0646b5323de8d48b6ff536f7ce3852dd655a8f77dbf034d2b12a1c24d)

[ChickenInGenerated1](https://etherscan.io/tx/0x9a4111645ff43f22c86d5cfab0b4695af4b1a28beca181a6364096f51b830557)

[ChickenInGenerated2](https://etherscan.io/tx/0x607385bf119bb3bced0cbd0e1766e6538a00b4fc984b85fd7de88fa96c3db6aa)

[ChickenInGenerated3](https://etherscan.io/tx/0x41eb7e9895f2bd03f1ca64534d4f57b3c138a3aa1498d799c0f1e69e92fafa50)

[ChickenInArtwork](https://etherscan.io/tx/0x9b7b0cd2343e461846789b91db68ee340fca0e30da8c412c30d65cba09196c70)

[BondNFTArtworkSwitcherTester](https://etherscan.io/tx/0x0e6500e529b4afa987bd3501a088adb5619ac23d7d680c7a29ba21beedee53e3)

[Set final Artwork address](https://etherscan.io/tx/0x8958edbbeb6fc50731b70cffb9a3e5a8a19a7f8f13df58cfb2f7050709392db6)

## Tests

[Create bond 3](https://etherscan.io/tx/0x338a5522bbad1b05b073659febced58b4e1f6ed9c2c57191258aed880c4f66e1)

[Failed chicken In, not owner](https://etherscan.io/tx/0xca980c338f6da8e487ae87833bf1c652c3d37ed65b55e16d96b7ab16c7c69c39)

[Failed chicken In during bootstrap period](https://etherscan.io/tx/0x2c46eb758e73817572599f6621cb5608d26a7214311536cbeff9dcea864c4137)

[Create bond (with permit) 4](https://etherscan.io/tx/0x72f383f3c1cf339417540d83f0dfa8f611be82cb15df2cfef41ae5ef5e96ba9e)

[Chicken out bond id 4 (still bootstrap period)](https://etherscan.io/tx/0xf7e7f2a9320d8dfbe1a5284ca3f1f3fff26189a0ef14bd13fba3f54adc56e918)

[Add liquidity to bLUSD/LUSD-3CRV pool](https://etherscan.io/tx/0xd5a526aff91ef6266d6db9856963e162347285862bd5791335a283de5cd3917c)

[Deposit LP tokens to bLUSD/LUSD-3CRV Gauge](https://etherscan.io/tx/0x93e725e1509023b7bd019166dba182563f75bcdd7a1dce822d0b00bf400d8016)

Earning rewards from Gauge:

<img width="394" alt="image" src="https://user-images.githubusercontent.com/701095/193554028-c39ac357-498b-4bcf-ab5d-5860b74bbadf.png">

[Swap LUSD to bLUSD using the frontend](https://etherscan.io/tx/0x1559b1dc1af77b12460f57c0282aaae1d9c113c34e5e221c63170c29c359d79c)

[Swap bLUSD to LUSD using the frontend](https://etherscan.io/tx/0xfa32eed1f37ec78e04e77cf98b1b767d958bb8aa314916685208b7b76ab6df28)



