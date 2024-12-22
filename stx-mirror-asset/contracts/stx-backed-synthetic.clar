;; Synthetic Asset Smart Contract

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INSUFFICIENT-TOKEN-BALANCE (err u101))
(define-constant ERR-INVALID-TOKEN-AMOUNT (err u102))
(define-constant ERR-ORACLE-PRICE-EXPIRED (err u103))
(define-constant ERR-INSUFFICIENT-COLLATERAL-DEPOSIT (err u104))
(define-constant ERR-BELOW-MINIMUM-COLLATERAL-THRESHOLD (err u105))
(define-constant ERR-INVALID-PRICE (err u106))
(define-constant ERR-ARITHMETIC-OVERFLOW (err u107))
(define-constant ERR-INVALID-RECIPIENT (err u108))
(define-constant ERR-ZERO-AMOUNT (err u109))
(define-constant ERR-NO-VAULT-EXISTS (err u110))

;; Constants
(define-constant CONTRACT-ADMINISTRATOR tx-sender)
(define-constant ORACLE-PRICE-EXPIRY-BLOCKS u900) ;; 15 minutes in blocks
(define-constant REQUIRED-COLLATERAL-RATIO u150) ;; 150%
(define-constant LIQUIDATION-THRESHOLD-RATIO u120) ;; 120%
(define-constant MINIMUM-SYNTHETIC-TOKEN-MINT u100000000) ;; 1.00 tokens (8 decimals)
(define-constant MAXIMUM-ORACLE_PRICE u1000000000000) ;; Set reasonable maximum price
(define-constant MAXIMUM-UINT-VALUE u340282366920938463463374607431768211455) ;; 2^128 - 1

;; Data variables
(define-data-var oracle-last-update-block uint u0)
(define-data-var oracle-asset-price uint u0)
(define-data-var total-synthetic-tokens-supply uint u0)

;; Data maps
(define-map synthetic-token-balances principal uint)
(define-map user-vault
    principal
    {
        collateral-amount: uint,
        synthetic-tokens-minted: uint,
        entry-price: uint
    }
)

;; Safe math functions
(define-private (safe-multiply-numbers (first-number uint) (second-number uint))
    (let ((multiplication-result (* first-number second-number)))
        (asserts! (or (is-eq first-number u0) (is-eq (/ multiplication-result first-number) second-number)) ERR-ARITHMETIC-OVERFLOW)
        (ok multiplication-result)))

(define-private (safe-add-numbers (first-number uint) (second-number uint))
    (let ((addition-result (+ first-number second-number)))
        (asserts! (>= addition-result first-number) ERR-ARITHMETIC-OVERFLOW)
        (ok addition-result)))

(define-private (safe-subtract-numbers (minuend uint) (subtrahend uint))
    (begin
        (asserts! (>= minuend subtrahend) ERR-ARITHMETIC-OVERFLOW)
        (ok (- minuend subtrahend))))

;; Read-only functions
(define-read-only (get-token-holder-balance (token-holder principal))
    (default-to u0 (map-get? synthetic-token-balances token-holder))
)

(define-read-only (get-total-token-supply)
    (var-get total-synthetic-tokens-supply)
)

(define-read-only (get-current-asset-price)
    (var-get oracle-asset-price)
)

(define-read-only (get-vault-information (vault-owner principal))
    (map-get? user-vault vault-owner)
)

(define-read-only (calculate-current-collateral-ratio (vault-owner principal))
    (let (
        (vault-info (unwrap! (get-vault-information vault-owner) (err u0)))
        (current-price (var-get oracle-asset-price))
    )
    (if (> (get synthetic-tokens-minted vault-info) u0)
        (match (safe-multiply-numbers (get collateral-amount vault-info) u100)
            collateral-value (match (safe-multiply-numbers collateral-value u100)
                total-collateral-value (match (safe-multiply-numbers (get synthetic-tokens-minted vault-info) current-price)
                    total-synthetic-value (ok (/ total-collateral-value total-synthetic-value))
                    error ERR-ARITHMETIC-OVERFLOW)
                error ERR-ARITHMETIC-OVERFLOW)
            error ERR-ARITHMETIC-OVERFLOW)
        (err u0)))
)

;; Private functions
(define-private (execute-token-transfer (sender principal) (recipient principal) (amount uint))
    (let (
        (sender-balance (get-token-holder-balance sender))
    )
    ;; Secondary validations in case this function is called directly
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (not (is-eq sender recipient)) ERR-INVALID-RECIPIENT)
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-TOKEN-BALANCE)
    (asserts! (is-some (map-get? synthetic-token-balances sender)) ERR-UNAUTHORIZED-ACCESS)
    
    (match (safe-add-numbers (get-token-holder-balance recipient) amount)
        recipient-balance
            (match (safe-subtract-numbers sender-balance amount)
                updated-sender-balance
                    (begin
                        (map-set synthetic-token-balances sender updated-sender-balance)
                        (map-set synthetic-token-balances recipient recipient-balance)
                        (ok true))
                error ERR-ARITHMETIC-OVERFLOW)
        error ERR-ARITHMETIC-OVERFLOW))
)

;; Public functions
(define-public (update-oracle-price (updated-price uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-ADMINISTRATOR) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (> updated-price u0) ERR-INVALID-PRICE)
        (asserts! (< updated-price MAXIMUM-ORACLE_PRICE) ERR-INVALID-PRICE)
        (var-set oracle-asset-price updated-price)
        (var-set oracle-last-update-block block-height)
        (ok true))
)

(define-public (mint-synthetic-tokens (mint-amount uint))
    (let (
        (current-asset-price (var-get oracle-asset-price))
    )
    (asserts! (> mint-amount u0) ERR-ZERO-AMOUNT)
    (asserts! (>= mint-amount MINIMUM-SYNTHETIC-TOKEN-MINT) ERR-INVALID-TOKEN-AMOUNT)
    (asserts! (<= (- block-height (var-get oracle-last-update-block)) 
                 ORACLE-PRICE-EXPIRY-BLOCKS) 
              ERR-ORACLE-PRICE-EXPIRED)
    
    (match (safe-multiply-numbers mint-amount (/ current-asset-price u100))
        base-collateral-required 
        (match (safe-multiply-numbers base-collateral-required (/ REQUIRED-COLLATERAL-RATIO u100))
            total-collateral-required
            (match (stx-transfer? total-collateral-required tx-sender (as-contract tx-sender))
                transfer-success
                (begin
                    (map-set user-vault tx-sender
                        {
                            collateral-amount: total-collateral-required,
                            synthetic-tokens-minted: mint-amount,
                            entry-price: current-asset-price
                        })
                    (match (safe-add-numbers (get-token-holder-balance tx-sender) mint-amount)
                        updated-holder-balance
                        (begin
                            (map-set synthetic-token-balances tx-sender updated-holder-balance)
                            (match (safe-add-numbers (var-get total-synthetic-tokens-supply) mint-amount)
                                updated-total-supply
                                (begin
                                    (var-set total-synthetic-tokens-supply updated-total-supply)
                                    (ok true))
                                error ERR-ARITHMETIC-OVERFLOW))
                        error ERR-ARITHMETIC-OVERFLOW))
                error ERR-INSUFFICIENT-COLLATERAL-DEPOSIT)
            error ERR-ARITHMETIC-OVERFLOW)
        error ERR-ARITHMETIC-OVERFLOW))
)

(define-public (burn-synthetic-tokens (burn-amount uint))
    (let (
        (vault-info (unwrap! (get-vault-information tx-sender) 
                            ERR-NO-VAULT-EXISTS))
        (holder-balance (get-token-holder-balance tx-sender))
    )
    (asserts! (> burn-amount u0) ERR-ZERO-AMOUNT)
    (asserts! (>= holder-balance burn-amount) ERR-INSUFFICIENT-TOKEN-BALANCE)
    (asserts! (>= (get synthetic-tokens-minted vault-info) burn-amount) 
              ERR-UNAUTHORIZED-ACCESS)
    
    (match (safe-multiply-numbers (get collateral-amount vault-info) burn-amount)
        collateral-calculation
        (let (
            (collateral-to-return (/ collateral-calculation 
                                   (get synthetic-tokens-minted vault-info)))
        )
        
        (try! (as-contract (stx-transfer? collateral-to-return
                                         (as-contract tx-sender)
                                         tx-sender)))
        
        (match (safe-subtract-numbers (get collateral-amount vault-info) 
                                    collateral-to-return)
            remaining-collateral
            (match (safe-subtract-numbers (get synthetic-tokens-minted vault-info) 
                                        burn-amount)
                remaining-minted-tokens
                (begin
                    (map-set user-vault tx-sender
                        {
                            collateral-amount: remaining-collateral,
                            synthetic-tokens-minted: remaining-minted-tokens,
                            entry-price: (var-get oracle-asset-price)
                        })
                    
                    (match (safe-subtract-numbers holder-balance burn-amount)
                        updated-holder-balance
                        (begin
                            (map-set synthetic-token-balances tx-sender updated-holder-balance)
                            (match (safe-subtract-numbers (var-get total-synthetic-tokens-supply) 
                                                        burn-amount)
                                updated-total-supply
                                (begin
                                    (var-set total-synthetic-tokens-supply updated-total-supply)
                                    (ok true))
                                error ERR-ARITHMETIC-OVERFLOW))
                        error ERR-ARITHMETIC-OVERFLOW))
                error ERR-ARITHMETIC-OVERFLOW)
            error ERR-ARITHMETIC-OVERFLOW))
        error ERR-ARITHMETIC-OVERFLOW))
)

(define-public (transfer-synthetic-tokens (recipient principal) (transfer-amount uint))
    (begin
        ;; Input validation
        (asserts! (> transfer-amount u0) ERR-ZERO-AMOUNT)
        (asserts! (<= transfer-amount (get-token-holder-balance tx-sender)) ERR-INSUFFICIENT-TOKEN-BALANCE)
        (asserts! (not (is-eq tx-sender recipient)) ERR-INVALID-RECIPIENT)
        
        ;; Only proceed with transfer if validations pass
        (execute-token-transfer tx-sender recipient transfer-amount))
)

(define-public (deposit-additional-collateral (additional-collateral uint))
    (let (
        (vault-info (default-to 
            {
                collateral-amount: u0, 
                synthetic-tokens-minted: u0, 
                entry-price: u0
            }
            (get-vault-information tx-sender)))
    )
    (asserts! (> additional-collateral u0) ERR-ZERO-AMOUNT)
    (try! (stx-transfer? additional-collateral tx-sender (as-contract tx-sender)))
    
    (match (safe-add-numbers (get collateral-amount vault-info) 
                            additional-collateral)
        updated-collateral-amount
        (begin
            (map-set user-vault tx-sender
                {
                    collateral-amount: updated-collateral-amount,
                    synthetic-tokens-minted: (get synthetic-tokens-minted vault-info),
                    entry-price: (var-get oracle-asset-price)
                })
            (ok true))
        error ERR-ARITHMETIC-OVERFLOW))
)

(define-public (liquidate-undercollateralized-vault (vault-owner principal))
    (let (
        (vault-info (unwrap! (get-vault-information vault-owner) 
                            ERR-NO-VAULT-EXISTS))
        (current-ratio (unwrap! (calculate-current-collateral-ratio vault-owner) 
                               ERR-UNAUTHORIZED-ACCESS))
    )
    (asserts! (< current-ratio LIQUIDATION-THRESHOLD-RATIO) 
              ERR-UNAUTHORIZED-ACCESS)
    
    ;; Transfer collateral to liquidator
    (try! (as-contract (stx-transfer? (get collateral-amount vault-info)
                                     (as-contract tx-sender)
                                     tx-sender)))
    
    ;; Clear the vault
    (map-delete user-vault vault-owner)
    
    ;; Burn the synthetic tokens
    (map-set synthetic-token-balances vault-owner u0)
    (match (safe-subtract-numbers (var-get total-synthetic-tokens-supply) 
                                 (get synthetic-tokens-minted vault-info))
        updated-total-supply
        (begin
            (var-set total-synthetic-tokens-supply updated-total-supply)
            (ok true))
        error ERR-ARITHMETIC-OVERFLOW))
)