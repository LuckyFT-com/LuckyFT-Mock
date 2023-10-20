# 🏗 LuckyFT


🧪 An Lucky base Friend.Tech.

## Tech

* Scroll
* Chainlink VRF
* Scaffold ETH 2

## Res

* [online demo](https://luckyft.vercel.app/)
* [video demo](https://www.bilibili.com/video/BV1zN41147N8/)
* [code](https://github.com/HelloRWA/luckyFT/)
* [scrollSepolia deploy and verified](https://sepolia-blockscout.scroll.io/address/0x6d3664a28573e26FDD4C41ab21b2703c81eB189c#code)
* [sepolia](https://sepolia.etherscan.io/address/0x3660c514B88e7a5CC059D35769979758cDbBD483)
* [ChainLink VRF ID](https://vrf.chain.link/sepolia/6032) sepolia/6032

![LuckyFT](https://luckyft.vercel.app/lucky-ft.jpg)

## Intro

The project is build base on the "Scaffold ETH 2" opensource project.

Friend.Tech has been quite popular recently, but it is a pure Ponzi. 

It relies on attracting people to earn handling fees or key price increases. 

Those who sell early make money, and those who run away in the end lose money.

LuckyFT is considering introducing “luck” to change this Ponzi logic. Everything is luck!


## Team

Solo Hacker： Stark: <https://twitter.com/StarkEVM99>

## What we do

LuckyFT use the  ChainLink  VRF feature to generate randome number, and deploy to sepolia 和 scrollSepolia

1. Users must first create FT. After holding a FT, they can buy other people’s keys.
2. When buying a key, you pay the price, which is the `buy` method, which triggers the requestRandomWords method of the chainlink and sends the key to the user at the same time.
3. When chainlink's VRF calls back fulfillRandomWords, the luck distribution will be determined based on the random number obtained.
4. Someone in the same room is lucky enough to get 10% of the share
5. The owner of one of the other Lucky Houses gets a 10% share
6. A key holder of the above Lucky Room has good luck and gets 10% of the share.

## What's next

We will consider to build a fancy UI for this idea later then to push the idea launch on mainnet then.

Also we need chainlink to support scroll mainnet so we can fully run on that.