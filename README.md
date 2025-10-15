# stake-reward

A simple Clarity smart contract for STX staking and reward distribution. Users stake STX, earn a reward based on a configurable rate, and can unstake (with possible penalty for early withdrawal). Admin functions allow updating rates and toggling staking.

## Repository
Location: c:\Users\USER\Desktop\STACKS\OCTOMBER\stake-reward  
Active contract: stake-reward.clar

## Features
- Stake STX into the contract
- Unstake with reward calculation and potential penalty
- Admin controls: set reward rate, set penalty rate, toggle staking
- Read-only getters for stakes, rates, active state, and contract balance
- Event-like last-operation data-vars for simple auditing

## Contract summary (public API)
- (stake (amount uint)) : public — stake `amount` STX into the contract
- (unstake) : public — withdraw staked amount plus reward (minus penalty if applicable)
- (set-reward-rate (new-rate uint)) : public — admin only, set percentage reward rate (e.g. 10 for 10%)
- (set-penalty-rate (new-rate uint)) : public — admin only, set penalty percentage
- (toggle-staking) : public — admin only, flip staking-active flag
- (get-stake (user principal)) : read-only — returns stake record for `user`
- (get-reward-rate) : read-only
- (get-penalty-rate) : read-only
- (is-staking-active) : read-only
- (contract-balance) : read-only — returns contract STX balance

## Storage layout / important vars
- admin — contract-level principal set at deploy-time in the active file
- reward-rate (data-var uint) — reward % (default 10)
- penalty-rate (data-var uint) — penalty % (default 5)
- staking-active (data-var bool) — whether staking is allowed
- stakes (map { user: principal } -> { amount, start-block, withdrawn })
- last-staked-event, last-unstaked-event, last-reward-event — last-operation summaries

## Errors / codes
- (err u100) ERR_NOT_ADMIN — caller is not admin
- (err u101) ERR_INSUFFICIENT_FUNDS — insufficient funds (not used in all paths)
- (err u102) ERR_NOT_STAKED — user has no stake or already withdrawn
- (err u103) ERR_INVALID_AMOUNT — amount <= 0
- (err u104) ERR_ALREADY_STAKED — user already has an active stake
- (err u200) used in contract to signal staking inactive (value used inline in current file)

Note: check the contract source for the exact error constants and uses.

## Local development / test
Recommended tool: Clarinet (local Clarity development & testing)

Install (PowerShell):
````bash
npm install -g @hirosystems/clarinet
````
Build and run tests / local network:
````bash
clarinet test
clarinet console
````
Inside Clarinet console you can call the contract using clarity REPL commands such as:
````text
(contract-call? .stake-reward.stake u1000000)
(contract-call? .stake-reward.unstake)
(contract-call? .stake-reward.set-reward-rate u15)
(contract-call? .stake-reward.toggle-staking)
(contract-call? .stake-reward.get-stake {principal "ST123..."})
````
Adjust contract name and principals as deployed in your Clarinet project.

## Example: call contract from Node (stacks.js)
Example read-only and contract-call usage (sketch; adapt keys/network):

````javascript
// Example: call-read-only
// filepath: examples/stacksjs-examples.js
import { callReadOnlyFunction, cvToValue, uintCV, principalCV } from "@stacks/transactions";
import { StacksTestnet } from "@stacks/network";

const network = new StacksTestnet();
const result = await callReadOnlyFunction({
  contractAddress: "ST2...", // contract deployer
  contractName: "stake-reward",
  functionName: "get-reward-rate",
  functionArgs: [],
  senderAddress: "ST2...",
  network,
});
console.log(cvToValue(result));
````

````javascript
// Example: make contract call (stake)
// filepath: examples/stacksjs-call.js
import { makeContractCall, standardPrincipalCV, uintCV } from "@stacks/transactions";
import { StacksTestnet } from "@stacks/network";
// build and broadcast transaction with your signer (use @stacks/connect or keychain)
const tx = await makeContractCall({
  contractAddress: "ST2...",
  contractName: "stake-reward",
  functionName: "stake",
  functionArgs: [uintCV(1000000)], // stake micro-STX amount
  network: new StacksTestnet(),
  // additional signer info require
Adapt to your signing flow (Hiro Wallet, Connect, or direct key signing).

## Deployment
- Local: use Clarinet or local node
- Testnet/Mainnet: deploy via Hiro Wallet / Stacks Explorer UI or automate with stacks.js and a funded deployer account
- Ensure the deployer tx-sender is the intended admin (contract currently stores admin as a constant at deploy-time in the active file)

---

For specific help running Clarinet commands, writing tests, or producing stacks.js examples adapted to your keys/network, provide which environment (local Clarinet vs testnet) to target.
