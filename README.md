# HDAO-Staking-Contracts

A repository to store staking contracts for the HDAO token

* Ethereum: [token contract](https://etherscan.io/address/0xdac657ffd44a3b9d8aba8749830bf14beb66ff2d)
* Polygon: [token contract](https://polygonscan.com/address/0x72928d5436ff65e57f72d5566dcd3baedc649a88)

## Setup
* Run `yarn` or `yarn install` to install all dependencies

## Required environment variables
* `INFURA_KEY`: A project secret for a [infura](https://infura.io/) project
* `PRIVATE_KEY`: An ethereum wallet private key to use for deployment

## Useful commands
* `yarn hardhat`: Starts a local hardhat blockchain at `http://localhost:8545/`
* `npx hardhat deploy`: Deploys a test version of the timelock contract to the local blockchain
