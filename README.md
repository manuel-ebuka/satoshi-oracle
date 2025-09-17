# SatoshiOracle: Bitcoin Price Prediction Protocol

SatoshiOracle is a **decentralized prediction market protocol** built on the Stacks blockchain, enabling trustless Bitcoin price forecasting through **community-driven consensus**.
Users stake STX tokens on **directional BTC price movements** and earn proportional rewards from a shared prize pool when their predictions prove accurate.

The protocol demonstrates how **Bitcoin Layer 2 infrastructure** can support sophisticated DeFi primitives while maintaining Bitcoin’s security and decentralization principles.

---

## ✨ Key Features

* **Decentralized Oracle Settlement**: Market outcomes are finalized using a registered oracle principal.
* **Transparent Reward Distribution**: Winners share the total pool based on their stake, minus protocol fees.
* **Time-Bounded Prediction Windows**: Markets define start and end block heights for participation.
* **Built-in Protocol Fee Model**: Configurable fee (in basis points) sustains protocol operations.
* **Permissionless Participation**: Any user may create positions within active markets.

---

## ⚙️ System Overview

The protocol consists of three primary lifecycle stages:

1. **Market Initialization**

   * Admin (contract owner) creates a new market with opening BTC price, start block, and end block.

2. **Prediction Submission**

   * Users submit predictions (`bullish` or `bearish`) by staking STX.
   * Stakes are pooled into separate bullish and bearish pools.

3. **Settlement & Reward Distribution**

   * Oracle sets the closing BTC price once the market ends.
   * Rewards are claimable by winning participants, proportionally distributed.
   * A protocol fee is deducted and transferable to the owner.

---

## 🏗️ Contract Architecture

The protocol is implemented as a **single Clarity smart contract**, structured around the following components:

### Constants & Configurations

* `CONTRACT_OWNER`: Protocol administrator.
* `oracle-principal`: Authorized oracle for market settlement.
* `min-stake-amount`: Minimum stake required per position.
* `protocol-fee-bps`: Protocol fee in basis points (e.g., 200 = 2%).

### Core Data Structures

* **`prediction-markets`**: Tracks each market’s lifecycle (opening price, pools, settlement status).
* **`participant-positions`**: Records user predictions, stake amount, and claim status.

### Core Public Functions

* **Market Administration**

  * `initialize-market`: Creates a new prediction market.
  * `settle-market`: Resolves a market with oracle-provided closing price.
* **User Operations**

  * `submit-prediction`: Stake STX on bullish or bearish outcome.
  * `claim-rewards`: Claim net rewards after market settlement.
* **Administrative Controls**

  * `update-oracle`, `update-min-stake`, `update-protocol-fee`, `withdraw-protocol-fees`.

### Read-Only Queries

* `get-market-info`: Fetch market details by ID.
* `get-user-position`: Retrieve a user’s market position.
* `get-protocol-config`: Inspect protocol parameters.
* `get-contract-balance`: View accumulated funds in contract.

---

## 🔄 Data Flow

1. **Market Creation**

   * Owner calls `initialize-market` → market ID allocated and stored.

2. **Prediction Submission**

   * User calls `submit-prediction` → STX transferred to contract → user position recorded → pools updated.

3. **Settlement**

   * Oracle calls `settle-market` → closing price stored → market marked as settled.

4. **Reward Claim**

   * User calls `claim-rewards` → net reward transferred to user, protocol fee routed to owner.

---

## 🧩 Example Workflow

1. Owner creates market:

   ```clarity
   (contract-call? .satoshi-oracle initialize-market u2600000000000 u1000 u1100)
   ```

2. User places bullish bet with 10 STX:

   ```clarity
   (contract-call? .satoshi-oracle submit-prediction u0 "bullish" u10000000)
   ```

3. Oracle settles market with closing price:

   ```clarity
   (contract-call? .satoshi-oracle settle-market u0 u2650000000000)
   ```

4. Winning user claims rewards:

   ```clarity
   (contract-call? .satoshi-oracle claim-rewards u0)
   ```

---

## 🔐 Security Considerations

* Only the **authorized oracle** can settle markets.
* Minimum stake prevents spam positions.
* Rewards cannot be double-claimed (enforced by `rewards-claimed` flag).
* Protocol fee capped at **10% max** for fairness.

---

## 📜 License

This project is released under the **MIT License**.
