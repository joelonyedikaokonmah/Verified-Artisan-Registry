(define-trait nft-trait
    (
        (get-last-token-id () (response uint uint))
        (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
        (get-owner (uint) (response (optional principal) uint))
        (transfer (uint principal principal) (response bool uint))
    ))

(define-non-fungible-token artisan-certificate uint)

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-VALIDATOR (err u400))
(define-constant ERR-NOT-VALIDATOR (err u403))
(define-constant ERR-ALREADY-VALIDATED (err u410))
(define-constant ERR-VALIDATION-FAILED (err u411))
(define-constant ERR-INVALID-PRODUCT (err u412))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u413))
(define-constant ERR-ORDER-NOT-FOUND (err u414))
(define-constant ERR-ORDER-ALREADY-EXISTS (err u415))
(define-constant ERR-INVALID-ORDER-STATUS (err u416))
(define-constant ERR-NOT-BUYER-OR-SELLER (err u417))
(define-constant ERR-DISPUTE-TIMEOUT (err u418))

(define-data-var next-artisan-id uint u1)
(define-data-var validation-threshold uint u3)
(define-data-var contract-paused bool false)

(define-map artisans uint {
    owner: principal,
    name: (string-ascii 50),
    specialty: (string-ascii 100),
    location: (string-ascii 100),
    validated: bool,
    validation-count: uint,
    created-at: uint,
    reputation-score: uint,
    total-sales: uint,
    featured-until: uint
})

(define-map validators principal {
    approved: bool,
    reputation: uint,
    validations-done: uint
})

(define-map artisan-validations {artisan-id: uint, validator: principal} {
    approved: bool,
    timestamp: uint
})

(define-map products uint {
    artisan-id: uint,
    name: (string-ascii 100),
    description: (string-ascii 500),
    image-uri: (string-ascii 200),
    price: uint,
    created-at: uint,
    signature: (buff 65)
})

(define-map product-ownership uint principal)

(define-map escrow-orders uint {
    product-id: uint,
    buyer: principal,
    seller: principal,
    amount: uint,
    status: (string-ascii 20),
    created-at: uint,
    delivered-at: (optional uint),
    dispute-started-at: (optional uint),
    auto-release-at: uint
})

(define-map escrow-balances uint uint)

(define-data-var next-product-id uint u1)
(define-data-var next-order-id uint u1)
(define-data-var dispute-timeout-blocks uint u1008)

(define-read-only (get-last-token-id)
    (ok (- (var-get next-artisan-id) u1)))

(define-read-only (get-token-uri (token-id uint))
    (ok (some (concat "https://artisan-registry.com/metadata/" (uint-to-ascii token-id)))))

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? artisan-certificate token-id)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    ERR-UNAUTHORIZED)

(define-public (add-validator (validator principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
        (ok (map-set validators validator {
            approved: true,
            reputation: u100,
            validations-done: u0
        }))))

(define-public (remove-validator (validator principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (ok (map-delete validators validator))))

(define-public (register-artisan (name (string-ascii 50)) (specialty (string-ascii 100)) (location (string-ascii 100)))
    (let ((artisan-id (var-get next-artisan-id)))
        (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
        (try! (nft-mint? artisan-certificate artisan-id tx-sender))
        (map-set artisans artisan-id {
            owner: tx-sender,
            name: name,
            specialty: specialty,
            location: location,
            validated: false,
            validation-count: u0,
            created-at: stacks-block-height,
            reputation-score: u50,
            total-sales: u0,
            featured-until: u0
        })
        (var-set next-artisan-id (+ artisan-id u1))
        (ok artisan-id)))

(define-public (validate-artisan (artisan-id uint))
    (let (
        (artisan (unwrap! (map-get? artisans artisan-id) ERR-NOT-FOUND))
        (validator-info (unwrap! (map-get? validators tx-sender) ERR-NOT-VALIDATOR))
        (validation-key {artisan-id: artisan-id, validator: tx-sender})
    )
        (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
        (asserts! (get approved validator-info) ERR-NOT-VALIDATOR)
        (asserts! (is-none (map-get? artisan-validations validation-key)) ERR-ALREADY-VALIDATED)
        
        (map-set artisan-validations validation-key {
            approved: true,
            timestamp: stacks-block-height
        })
        
        (let ((new-validation-count (+ (get validation-count artisan) u1)))
            (map-set artisans artisan-id (merge artisan {
                validation-count: new-validation-count,
                validated: (>= new-validation-count (var-get validation-threshold))
            }))
            
            (map-set validators tx-sender (merge validator-info {
                validations-done: (+ (get validations-done validator-info) u1)
            }))
            
            (ok new-validation-count))))

(define-public (create-product (artisan-id uint) (name (string-ascii 100)) (description (string-ascii 500)) (image-uri (string-ascii 200)) (price uint) (signature (buff 65)))
    (let (
        (artisan (unwrap! (map-get? artisans artisan-id) ERR-NOT-FOUND))
        (product-id (var-get next-product-id))
    )
        (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get owner artisan) tx-sender) ERR-UNAUTHORIZED)
        (asserts! (get validated artisan) ERR-VALIDATION-FAILED)
        
        (map-set products product-id {
            artisan-id: artisan-id,
            name: name,
            description: description,
            image-uri: image-uri,
            price: price,
            created-at: stacks-block-height,
            signature: signature
        })
        
        (map-set product-ownership product-id tx-sender)
        (var-set next-product-id (+ product-id u1))
        (ok product-id)))

(define-public (transfer-product (product-id uint) (new-owner principal))
    (let (
        (current-owner (unwrap! (map-get? product-ownership product-id) ERR-NOT-FOUND))
        (product (unwrap! (map-get? products product-id) ERR-NOT-FOUND))
        (artisan-id (get artisan-id product))
        (artisan (unwrap! (map-get? artisans artisan-id) ERR-NOT-FOUND))
    )
        (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
        (asserts! (is-eq tx-sender current-owner) ERR-UNAUTHORIZED)
        (map-set product-ownership product-id new-owner)
        (try! (update-reputation artisan-id u5))
        (ok true)))

(define-public (update-validation-threshold (new-threshold uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (> new-threshold u0) ERR-INVALID-VALIDATOR)
        (ok (var-set validation-threshold new-threshold))))

(define-public (pause-contract)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (ok (var-set contract-paused true))))

(define-public (unpause-contract)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (ok (var-set contract-paused false))))

(define-private (update-reputation (artisan-id uint) (points uint))
    (let ((artisan (unwrap! (map-get? artisans artisan-id) ERR-NOT-FOUND)))
        (let (
            (current-score (get reputation-score artisan))
            (new-score (+ current-score points))
            (capped-score (if (> new-score u100) u100 new-score))
            (new-sales (+ (get total-sales artisan) u1))
        )
            (ok (map-set artisans artisan-id (merge artisan {
                reputation-score: capped-score,
                total-sales: new-sales
            }))))))

(define-public (set-featured-artisan (artisan-id uint) (blocks uint))
    (let ((artisan (unwrap! (map-get? artisans artisan-id) ERR-NOT-FOUND)))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (>= (get reputation-score artisan) u80) ERR-VALIDATION-FAILED)
        (ok (map-set artisans artisan-id (merge artisan {
            featured-until: (+ stacks-block-height blocks)
        })))))

(define-read-only (is-featured-artisan (artisan-id uint))
    (match (map-get? artisans artisan-id)
        artisan (>= (get featured-until artisan) stacks-block-height)
        false))

(define-read-only (get-artisan-reputation (artisan-id uint))
    (match (map-get? artisans artisan-id)
        artisan (some {
            reputation-score: (get reputation-score artisan),
            total-sales: (get total-sales artisan),
            is-featured: (>= (get featured-until artisan) stacks-block-height)
        })
        none))

(define-read-only (get-top-artisans)
    (ok true))

(define-read-only (get-artisan (artisan-id uint))
    (map-get? artisans artisan-id))

(define-read-only (get-product (product-id uint))
    (map-get? products product-id))

(define-read-only (get-product-owner (product-id uint))
    (map-get? product-ownership product-id))

(define-read-only (get-validator (validator principal))
    (map-get? validators validator))

(define-read-only (get-validation (artisan-id uint) (validator principal))
    (map-get? artisan-validations {artisan-id: artisan-id, validator: validator}))

(define-read-only (is-artisan-validated (artisan-id uint))
    (match (map-get? artisans artisan-id)
        artisan (get validated artisan)
        false))

(define-read-only (get-artisan-validation-count (artisan-id uint))
    (match (map-get? artisans artisan-id)
        artisan (get validation-count artisan)
        u0))

(define-read-only (verify-product-authenticity (product-id uint))
    (match (map-get? products product-id)
        product (let ((artisan-id (get artisan-id product)))
            (match (map-get? artisans artisan-id)
                artisan (some {
                    artisan-validated: (get validated artisan),
                    artisan-name: (get name artisan),
                    product-signature: (get signature product),
                    created-at: (get created-at product)
                })
                none))
        none))

(define-read-only (get-artisan-products (artisan-id uint))
    (ok true))

(define-public (purchase-product (product-id uint))
    (let (
        (product (unwrap! (map-get? products product-id) ERR-NOT-FOUND))
        (artisan (unwrap! (map-get? artisans (get artisan-id product)) ERR-NOT-FOUND))
        (order-id (var-get next-order-id))
        (price (get price product))
        (seller (get owner artisan))
        (auto-release-block (+ stacks-block-height (var-get dispute-timeout-blocks)))
    )
        (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
        (asserts! (get validated artisan) ERR-VALIDATION-FAILED)
        (asserts! (> price u0) ERR-INVALID-PRODUCT)
        (asserts! (not (is-eq tx-sender seller)) ERR-UNAUTHORIZED)
        
        (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
        
        (map-set escrow-orders order-id {
            product-id: product-id,
            buyer: tx-sender,
            seller: seller,
            amount: price,
            status: "pending",
            created-at: stacks-block-height,
            delivered-at: none,
            dispute-started-at: none,
            auto-release-at: auto-release-block
        })
        
        (map-set escrow-balances order-id price)
        (var-set next-order-id (+ order-id u1))
        (ok order-id)))

(define-public (confirm-delivery (order-id uint))
    (let (
        (order (unwrap! (map-get? escrow-orders order-id) ERR-ORDER-NOT-FOUND))
        (escrow-amount (unwrap! (map-get? escrow-balances order-id) ERR-ORDER-NOT-FOUND))
    )
        (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
        (asserts! (is-eq tx-sender (get buyer order)) ERR-NOT-BUYER-OR-SELLER)
        (asserts! (is-eq (get status order) "pending") ERR-INVALID-ORDER-STATUS)
        
        (try! (as-contract (stx-transfer? escrow-amount tx-sender (get seller order))))
        
        (map-set escrow-orders order-id (merge order {
            status: "completed",
            delivered-at: (some stacks-block-height)
        }))
        
        (map-delete escrow-balances order-id)
        (try! (update-reputation (get product-id order) u10))
        (ok true)))

(define-public (start-dispute (order-id uint))
    (let (
        (order (unwrap! (map-get? escrow-orders order-id) ERR-ORDER-NOT-FOUND))
    )
        (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
        (asserts! (or (is-eq tx-sender (get buyer order)) (is-eq tx-sender (get seller order))) ERR-NOT-BUYER-OR-SELLER)
        (asserts! (is-eq (get status order) "pending") ERR-INVALID-ORDER-STATUS)
        
        (ok (map-set escrow-orders order-id (merge order {
            status: "disputed",
            dispute-started-at: (some stacks-block-height)
        })))))

(define-public (resolve-dispute (order-id uint) (release-to-seller bool))
    (let (
        (order (unwrap! (map-get? escrow-orders order-id) ERR-ORDER-NOT-FOUND))
        (escrow-amount (unwrap! (map-get? escrow-balances order-id) ERR-ORDER-NOT-FOUND))
        (recipient (if release-to-seller (get seller order) (get buyer order)))
    )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status order) "disputed") ERR-INVALID-ORDER-STATUS)
        
        (try! (as-contract (stx-transfer? escrow-amount tx-sender recipient)))
        
        (map-set escrow-orders order-id (merge order {
            status: (if release-to-seller "completed" "refunded"),
            delivered-at: (if release-to-seller (some stacks-block-height) none)
        }))
        
        (map-delete escrow-balances order-id)
        
        (if release-to-seller
            (update-reputation (get product-id order) u5)
            (ok true))))

(define-public (auto-release-payment (order-id uint))
    (let (
        (order (unwrap! (map-get? escrow-orders order-id) ERR-ORDER-NOT-FOUND))
        (escrow-amount (unwrap! (map-get? escrow-balances order-id) ERR-ORDER-NOT-FOUND))
    )
        (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status order) "pending") ERR-INVALID-ORDER-STATUS)
        (asserts! (>= stacks-block-height (get auto-release-at order)) ERR-DISPUTE-TIMEOUT)
        
        (try! (as-contract (stx-transfer? escrow-amount tx-sender (get seller order))))
        
        (map-set escrow-orders order-id (merge order {
            status: "auto-completed",
            delivered-at: (some stacks-block-height)
        }))
        
        (map-delete escrow-balances order-id)
        (try! (update-reputation (get product-id order) u8))
        (ok true)))

(define-read-only (get-order (order-id uint))
    (map-get? escrow-orders order-id))

(define-read-only (get-order-balance (order-id uint))
    (map-get? escrow-balances order-id))

(define-read-only (can-auto-release (order-id uint))
    (match (map-get? escrow-orders order-id)
        order (and 
            (is-eq (get status order) "pending")
            (>= stacks-block-height (get auto-release-at order)))
        false))

(define-read-only (get-contract-stats)
    {
        total-artisans: (- (var-get next-artisan-id) u1),
        total-products: (- (var-get next-product-id) u1),
        total-orders: (- (var-get next-order-id) u1),
        validation-threshold: (var-get validation-threshold),
        contract-paused: (var-get contract-paused)
    })

(define-read-only (uint-to-ascii (value uint))
    (if (<= value u9)
        (unwrap-panic (element-at "0123456789" value))
        (get r (fold uint-to-ascii-inner 
            0x000000000000000000000000000000000000000000000000000000000000000000000000
            {v: value, r: ""}))))

(define-private (uint-to-ascii-inner (i (buff 1)) (d {v: uint, r: (string-ascii 39)}))
    (if (> (get v d) u0)
        {
            v: (/ (get v d) u10),
            r: (unwrap-panic (as-max-len? (concat (unwrap-panic (element-at "0123456789" (mod (get v d) u10))) (get r d)) u39))
        }
        d))
