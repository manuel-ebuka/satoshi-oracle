;; SatoshiOracle: Bitcoin Price Prediction Protocol
;;
;; A sophisticated prediction market protocol built on Stacks blockchain that
;; enables trustless Bitcoin price forecasting through community consensus.
;; Users stake STX tokens on directional BTC price movements and earn proportional
;; rewards from a shared prize pool when their predictions prove accurate.
;;
;; Key Features:
;; - Decentralized oracle-based price settlement
;; - Transparent reward distribution mechanics
;; - Time-bounded prediction windows
;; - Built-in protocol fee structure
;; - Permissionless market participation
;;
;; This protocol demonstrates the power of Bitcoin Layer 2 infrastructure
;; for creating sophisticated DeFi primitives while maintaining the security
;; and decentralization principles of the Bitcoin ecosystem.

;; CONSTANTS & ERROR CODES

;; Administrative Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))

;; Operational Error Codes
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_DIRECTION (err u102))
(define-constant ERR_MARKET_INACTIVE (err u103))
(define-constant ERR_REWARDS_CLAIMED (err u104))
(define-constant ERR_INSUFFICIENT_FUNDS (err u105))
(define-constant ERR_INVALID_INPUT (err u106))
(define-constant ERR_MARKET_PENDING (err u107))
(define-constant ERR_MARKET_EXPIRED (err u108))
(define-constant ERR_ALREADY_SETTLED (err u109))

;; PROTOCOL CONFIGURATION

;; Oracle Configuration
(define-data-var oracle-principal principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Economic Parameters
(define-data-var min-stake-amount uint u1000000) ;; 1 STX minimum stake
(define-data-var protocol-fee-bps uint u200) ;; 2% protocol fee (200 basis points)

;; Market Management
(define-data-var next-market-id uint u0)

;; DATA STRUCTURES

;; Market Definition
(define-map prediction-markets
  uint ;; market-id
  {
    opening-price: uint, ;; BTC price at market start (satoshis)
    closing-price: uint, ;; BTC price at market end (satoshis)
    bullish-pool: uint, ;; Total STX staked on price increase
    bearish-pool: uint, ;; Total STX staked on price decrease
    start-height: uint, ;; Block height when betting opens
    end-height: uint, ;; Block height when betting closes
    is-settled: bool, ;; Market resolution status
  }
)

;; User Position Tracking
(define-map participant-positions
  {
    market-id: uint,
    participant: principal,
  }
  {
    direction: (string-ascii 8), ;; "bullish" or "bearish"
    amount: uint, ;; STX amount staked
    rewards-claimed: bool, ;; Claim status flag
  }
)

;; MARKET ADMINISTRATION

;; Create New Prediction Market
(define-public (initialize-market
    (opening-price uint)
    (start-height uint)
    (end-height uint)
  )
  (let ((market-id (var-get next-market-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> end-height start-height) ERR_INVALID_INPUT)
    (asserts! (> opening-price u0) ERR_INVALID_INPUT)

    (map-set prediction-markets market-id {
      opening-price: opening-price,
      closing-price: u0,
      bullish-pool: u0,
      bearish-pool: u0,
      start-height: start-height,
      end-height: end-height,
      is-settled: false,
    })

    (var-set next-market-id (+ market-id u1))
    (ok market-id)
  )
)

;; Settle Market with Oracle Price Feed
(define-public (settle-market
    (market-id uint)
    (closing-price uint)
  )
  (let ((market-data (unwrap! (map-get? prediction-markets market-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get oracle-principal)) ERR_UNAUTHORIZED)
    (asserts! (>= stacks-block-height (get end-height market-data))
      ERR_MARKET_PENDING
    )
    (asserts! (not (get is-settled market-data)) ERR_ALREADY_SETTLED)
    (asserts! (> closing-price u0) ERR_INVALID_INPUT)

    (map-set prediction-markets market-id
      (merge market-data {
        closing-price: closing-price,
        is-settled: true,
      })
    )
    (ok true)
  )
)

;; USER OPERATIONS

;; Submit Price Prediction
(define-public (submit-prediction
    (market-id uint)
    (direction (string-ascii 8))
    (stake-amount uint)
  )
  (let (
      (market-data (unwrap! (map-get? prediction-markets market-id) ERR_NOT_FOUND))
      (current-height stacks-block-height)
    )
    ;; Validate Market Timing
    (asserts!
      (and
        (>= current-height (get start-height market-data))
        (< current-height (get end-height market-data))
      )
      ERR_MARKET_EXPIRED
    )

    ;; Validate Prediction Parameters
    (asserts! (or (is-eq direction "bullish") (is-eq direction "bearish"))
      ERR_INVALID_DIRECTION
    )
    (asserts! (>= stake-amount (var-get min-stake-amount)) ERR_INVALID_INPUT)
    (asserts! (<= stake-amount (stx-get-balance tx-sender))
      ERR_INSUFFICIENT_FUNDS
    )

    ;; Transfer Stake to Contract
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))

    ;; Record User Position
    (map-set participant-positions {
      market-id: market-id,
      participant: tx-sender,
    } {
      direction: direction,
      amount: stake-amount,
      rewards-claimed: false,
    })

    ;; Update Market Pools
    (map-set prediction-markets market-id
      (merge market-data {
        bullish-pool: (if (is-eq direction "bullish")
          (+ (get bullish-pool market-data) stake-amount)
          (get bullish-pool market-data)
        ),
        bearish-pool: (if (is-eq direction "bearish")
          (+ (get bearish-pool market-data) stake-amount)
          (get bearish-pool market-data)
        ),
      })
    )
    (ok true)
  )
)

;; Claim Prediction Rewards
(define-public (claim-rewards (market-id uint))
  (let (
      (market-data (unwrap! (map-get? prediction-markets market-id) ERR_NOT_FOUND))
      (user-position (unwrap!
        (map-get? participant-positions {
          market-id: market-id,
          participant: tx-sender,
        })
        ERR_NOT_FOUND
      ))
    )
    ;; Validate Claim Conditions
    (asserts! (get is-settled market-data) ERR_MARKET_INACTIVE)
    (asserts! (not (get rewards-claimed user-position)) ERR_REWARDS_CLAIMED)

    (let (
        (winning-direction (if (> (get closing-price market-data) (get opening-price market-data))
          "bullish"
          "bearish"
        ))
        (total-pool (+ (get bullish-pool market-data) (get bearish-pool market-data)))
        (winning-pool (if (is-eq winning-direction "bullish")
          (get bullish-pool market-data)
          (get bearish-pool market-data)
        ))
      )
      ;; Verify Winning Position
      (asserts! (is-eq (get direction user-position) winning-direction)
        ERR_INVALID_DIRECTION
      )

      ;; Calculate Reward Distribution
      (let (
          (gross-reward (/ (* (get amount user-position) total-pool) winning-pool))
          (protocol-fee (/ (* gross-reward (var-get protocol-fee-bps)) u10000))
          (net-reward (- gross-reward protocol-fee))
        )
        ;; Execute Transfers
        (try! (as-contract (stx-transfer? net-reward (as-contract tx-sender) tx-sender)))
        (try! (as-contract (stx-transfer? protocol-fee (as-contract tx-sender) CONTRACT_OWNER)))

        ;; Update Claim Status
        (map-set participant-positions {
          market-id: market-id,
          participant: tx-sender,
        }
          (merge user-position { rewards-claimed: true })
        )
        (ok net-reward)
      )
    )
  )
)

;; ADMINISTRATIVE FUNCTIONS

;; Update Oracle Principal
(define-public (update-oracle (new-oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq new-oracle (var-get oracle-principal)))
      ERR_INVALID_INPUT
    )
    (ok (var-set oracle-principal new-oracle))
  )
)

;; Adjust Minimum Stake Requirement
(define-public (update-min-stake (new-minimum uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> new-minimum u0) ERR_INVALID_INPUT)
    (ok (var-set min-stake-amount new-minimum))
  )
)

;; Modify Protocol Fee Structure
(define-public (update-protocol-fee (new-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-fee-bps u1000) ERR_INVALID_INPUT) ;; Max 10%
    (ok (var-set protocol-fee-bps new-fee-bps))
  )
)

;; Withdraw Accumulated Fees
(define-public (withdraw-protocol-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= amount (stx-get-balance (as-contract tx-sender)))
      ERR_INSUFFICIENT_FUNDS
    )
    (try! (as-contract (stx-transfer? amount (as-contract tx-sender) CONTRACT_OWNER)))
    (ok amount)
  )
)

;; READ-ONLY QUERIES

;; Retrieve Market Information
(define-read-only (get-market-info (market-id uint))
  (map-get? prediction-markets market-id)
)

;; Query User Position
(define-read-only (get-user-position
    (market-id uint)
    (user principal)
  )
  (map-get? participant-positions {
    market-id: market-id,
    participant: user,
  })
)

;; Check Protocol Configuration
(define-read-only (get-protocol-config)
  {
    oracle: (var-get oracle-principal),
    min-stake: (var-get min-stake-amount),
    fee-bps: (var-get protocol-fee-bps),
    next-market: (var-get next-market-id),
  }
)

;; Get Contract Balance
(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)
