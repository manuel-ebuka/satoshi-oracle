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