# StkAAVE Retrieval for Balancer

Payload, retrieval contract,and tests

## Speciication

This proposal payload sets the claimer of the Balancer DAO contract's stkAAVE rewards to be the retrieval contract.

The retrieval contract does the following:

1. It is called by the Balancer Multisig
2. It claims the stkAAVE rewards on behalf of the Balancer DAO contract from aDAI, aUSDC, and aUSDT
3. It transfers the stkAAVE rewards to the Balancer Multisig

## Installation

It requires [Foundry](https://github.com/gakonst/foundry) installed to run. You can find instructions here [Foundry installation](https://github.com/gakonst/foundry#installation).

To install, run the following commands:

```sh
$ git clone https://github.com/llama-community/aave-stkaave-retrieval.git
$ cd aave-stkaave-retrieval/
$ npm install
$ forge install
```

## Setup

Duplicate `.env.example` and rename to `.env`:

- Add a valid mainnet URL for an Ethereum JSON-RPC client for the `RPC_MAINNET_URL` variable.
- Add a valid Private Key for the `PRIVATE_KEY` variable.
- Add a valid Etherscan API Key for the `ETHERSCAN_API_KEY` variable.

### Commands

- `make build` - build the project
- `make test [optional](V={1,2,3,4,5})` - run tests (with different debug levels if provided)
- `make match MATCH=<TEST_FUNCTION_NAME> [optional](V=<{1,2,3,4,5}>)` - run matched tests (with different debug levels if provided)

### Deploy and Verify

- `make deploy-payload` - deploy and verify payload on mainnet
- `make deploy-proposal`- deploy proposal on mainnet

To confirm the deploy was successful, re-run your test suite but use the newly created contract address.
