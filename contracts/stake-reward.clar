;; =============================================================
;; stake-reward-system.clar
;; A decentralized staking and reward distribution contract
;; Users stake STX, earn rewards, and can withdraw anytime
;; =============================================================

(define-constant ERR_NOT_ADMIN (err u100))
(define-constant ERR_INSUFFICIENT_FUNDS (err u101))
(define-constant ERR_NOT_STAKED (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_ALREADY_STAKED (err u104))

;; ------------------------------
;; CONSTANTS AND VARIABLES
;; ------------------------------
(define-constant admin tx-sender)
(define-data-var reward-rate uint u10) ;; reward = 10% of staked amount
(define-data-var penalty-rate uint u5) ;; penalty = 5% for early unstake
(define-data-var staking-active bool true)

(define-map stakes
  { user: principal }
  {
    amount: uint,
    start-block: uint,
    withdrawn: bool
  }
)

(define-data-var last-staked-event {user: principal, amount: uint} {user: tx-sender, amount: u0})
(define-data-var last-unstaked-event {user: principal, amount: uint, reward: uint} {user: tx-sender, amount: u0, reward: u0})
(define-data-var last-reward-event {user: principal, reward: uint} {user: tx-sender, reward: u0})

;; ------------------------------
;; PRIVATE ADMIN CHECK
;; ------------------------------
(define-private (only-admin)
  (if (is-eq tx-sender admin)
      (ok true)
      ERR_NOT_ADMIN)
)

;; ------------------------------
;; CORE STAKING FUNCTIONS
;; ------------------------------

;; Stake STX
(define-public (stake (amount uint))
  (begin
    (if (not (var-get staking-active))
        (err u200)
        (if (<= amount u0)
            ERR_INVALID_AMOUNT
            (let ((existing (map-get? stakes { user: tx-sender })))
              (if (is-some existing)
                  ERR_ALREADY_STAKED
                  (begin
                    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
                    (map-set stakes { user: tx-sender }
                      { amount: amount, start-block: stacks-block-height, withdrawn: false })
                    (var-set last-staked-event {user: tx-sender, amount: amount})
                    (ok amount)
                  )
              )
            )
        )
    )
  )
)

;; Unstake STX (with possible penalty)
(define-public (unstake)
  (let ((stake-data (map-get? stakes { user: tx-sender })))
    (if (is-none stake-data)
        ERR_NOT_STAKED
        (let ((data (unwrap-panic stake-data)))
          (if (get withdrawn data)
              ERR_NOT_STAKED
              (let (
                    (amount (get amount data))
                    (duration (- stacks-block-height (get start-block data)))
                   )
                ;; Calculate reward proportional to duration
                (let (
                      (base-reward (/ (* amount (var-get reward-rate)) u100))
                      (reward (if (> duration u50) base-reward (/ base-reward u2))) ;; half reward if staked < 50 blocks
                      (penalty (if (< duration u20) (/ (* amount (var-get penalty-rate)) u100) u0))
                      (final-amount (- (+ amount reward) penalty))
                     )
                  (try! (stx-transfer? final-amount (as-contract tx-sender) tx-sender))
                  (map-set stakes { user: tx-sender } { amount: amount, start-block: (get start-block data), withdrawn: true })
                  (var-set last-unstaked-event {user: tx-sender, amount: amount, reward: reward})
                  (var-set last-reward-event {user: tx-sender, reward: reward})
                  (ok { staked: amount, reward: reward, penalty: penalty, received: final-amount })
                )
              )
          )
        )
    )
  )
)

;;Admin updates reward rate
(define-public (set-reward-rate (new-rate uint))
  (begin
    (try! (only-admin))
    (var-set reward-rate new-rate)
    (ok (var-get reward-rate))
  )
)

;;Admin updates penalty rate
(define-public (set-penalty-rate (new-rate uint))
  (begin
    (try! (only-admin))
    (var-set penalty-rate new-rate)
    (ok (var-get penalty-rate))
  )
)

;;Admin toggle staking
(define-public (toggle-staking)
  (begin
    (try! (only-admin))
    (var-set staking-active (not (var-get staking-active)))
    (ok (var-get staking-active))
  )
)

;; ------------------------------
;; READ-ONLY FUNCTIONS
;; ------------------------------

(define-read-only (get-stake (user principal))
  (map-get? stakes { user: user })
)

(define-read-only (get-reward-rate)
  (ok (var-get reward-rate))
)

(define-read-only (get-penalty-rate)
  (ok (var-get penalty-rate))
)

(define-read-only (is-staking-active)
  (ok (var-get staking-active))
)

(define-read-only (contract-balance)
  (ok (stx-get-balance (as-contract tx-sender)))
)
