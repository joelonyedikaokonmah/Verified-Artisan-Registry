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
    created-at: uint
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

(define-data-var next-product-id uint u1)

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
            created-at: stacks-block-height
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
    (let ((current-owner (unwrap! (map-get? product-ownership product-id) ERR-NOT-FOUND)))
        (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
        (asserts! (is-eq tx-sender current-owner) ERR-UNAUTHORIZED)
        (ok (map-set product-ownership product-id new-owner))))

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

(define-read-only (get-contract-stats)
    {
        total-artisans: (- (var-get next-artisan-id) u1),
        total-products: (- (var-get next-product-id) u1),
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
