;; Drug Manufacturing Registry Smart Contract
;; Track pharmaceutical production, quality control tests, and batch certifications
;; from raw ingredients to finished products

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_BATCH_NOT_FOUND (err u404))
(define-constant ERR_BATCH_ALREADY_EXISTS (err u409))
(define-constant ERR_INVALID_BATCH_ID (err u400))
(define-constant ERR_INVALID_FACILITY (err u402))
(define-constant ERR_INVALID_STATUS (err u403))
(define-constant ERR_EXPIRED_BATCH (err u410))

;; Data Variables
(define-data-var next-batch-id uint u1)

;; Data Maps
(define-map drug-batches 
    { batch-id: uint }
    {
        manufacturer: principal,
        facility-id: (string-ascii 50),
        drug-name: (string-ascii 100),
        batch-number: (string-ascii 50),
        manufacturing-date: uint,
        expiry-date: uint,
        quantity: uint,
        unit: (string-ascii 20),
        status: (string-ascii 20),
        raw-materials-hash: (string-ascii 64),
        quality-tests-passed: uint,
        quality-tests-total: uint,
        created-at: uint,
        updated-at: uint
    }
)

(define-map manufacturing-facilities
    { facility-id: (string-ascii 50) }
    {
        owner: principal,
        facility-name: (string-ascii 100),
        location: (string-ascii 100),
        license-number: (string-ascii 50),
        certification-level: (string-ascii 20),
        is-active: bool,
        registered-at: uint
    }
)

(define-map quality-tests
    { batch-id: uint, test-id: uint }
    {
        test-name: (string-ascii 50),
        test-result: (string-ascii 20),
        tested-by: principal,
        test-date: uint,
        test-value: (string-ascii 100),
        acceptable-range: (string-ascii 100),
        certification-body: (string-ascii 100)
    }
)

(define-map raw-materials
    { batch-id: uint, material-id: uint }
    {
        material-name: (string-ascii 100),
        supplier: (string-ascii 100),
        lot-number: (string-ascii 50),
        quantity-used: uint,
        purity-level: (string-ascii 20),
        source-country: (string-ascii 50),
        verification-status: (string-ascii 20)
    }
)

(define-map authorized-manufacturers
    { manufacturer: principal }
    {
        company-name: (string-ascii 100),
        registration-number: (string-ascii 50),
        authorized-at: uint,
        authorized-by: principal,
        is-active: bool
    }
)

;; Authorization functions
(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (is-authorized-manufacturer (manufacturer principal))
    (match (map-get? authorized-manufacturers { manufacturer: manufacturer })
        manufacturer-info (get is-active manufacturer-info)
        false
    )
)

(define-private (is-valid-facility (facility-id (string-ascii 50)))
    (match (map-get? manufacturing-facilities { facility-id: facility-id })
        facility-info (get is-active facility-info)
        false
    )
)

;; Public functions for facility management
(define-public (register-facility 
    (facility-id (string-ascii 50))
    (facility-name (string-ascii 100))
    (location (string-ascii 100))
    (license-number (string-ascii 50))
    (certification-level (string-ascii 20))
    )
    (begin
        (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
        (map-set manufacturing-facilities
            { facility-id: facility-id }
            {
                owner: tx-sender,
                facility-name: facility-name,
                location: location,
                license-number: license-number,
                certification-level: certification-level,
                is-active: true,
                registered-at: burn-block-height
            }
        )
        (ok facility-id)
    )
)

(define-public (authorize-manufacturer
    (manufacturer principal)
    (company-name (string-ascii 100))
    (registration-number (string-ascii 50))
    )
    (begin
        (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
        (map-set authorized-manufacturers
            { manufacturer: manufacturer }
            {
                company-name: company-name,
                registration-number: registration-number,
                authorized-at: burn-block-height,
                authorized-by: tx-sender,
                is-active: true
            }
        )
        (ok manufacturer)
    )
)

;; Public function to register a new drug batch
(define-public (register-batch
    (facility-id (string-ascii 50))
    (drug-name (string-ascii 100))
    (batch-number (string-ascii 50))
    (manufacturing-date uint)
    (expiry-date uint)
    (quantity uint)
    (unit (string-ascii 20))
    (raw-materials-hash (string-ascii 64))
    )
    (let 
        (
            (batch-id (var-get next-batch-id))
        )
        (asserts! (is-authorized-manufacturer tx-sender) ERR_NOT_AUTHORIZED)
        (asserts! (is-valid-facility facility-id) ERR_INVALID_FACILITY)
        (asserts! (> expiry-date manufacturing-date) ERR_EXPIRED_BATCH)
        (asserts! (> quantity u0) ERR_INVALID_BATCH_ID)
        
        (map-set drug-batches
            { batch-id: batch-id }
            {
                manufacturer: tx-sender,
                facility-id: facility-id,
                drug-name: drug-name,
                batch-number: batch-number,
                manufacturing-date: manufacturing-date,
                expiry-date: expiry-date,
                quantity: quantity,
                unit: unit,
                status: "manufactured",
                raw-materials-hash: raw-materials-hash,
                quality-tests-passed: u0,
                quality-tests-total: u0,
                created-at: burn-block-height,
                updated-at: burn-block-height
            }
        )
        (var-set next-batch-id (+ batch-id u1))
        (ok batch-id)
    )
)

;; Public function to add quality test results
(define-public (add-quality-test
    (batch-id uint)
    (test-id uint)
    (test-name (string-ascii 50))
    (test-result (string-ascii 20))
    (test-value (string-ascii 100))
    (acceptable-range (string-ascii 100))
    (certification-body (string-ascii 100))
    )
    (let
        (
            (batch-info (unwrap! (map-get? drug-batches { batch-id: batch-id }) ERR_BATCH_NOT_FOUND))
        )
        (asserts! (is-eq (get manufacturer batch-info) tx-sender) ERR_NOT_AUTHORIZED)
        
        (map-set quality-tests
            { batch-id: batch-id, test-id: test-id }
            {
                test-name: test-name,
                test-result: test-result,
                tested-by: tx-sender,
                test-date: burn-block-height,
                test-value: test-value,
                acceptable-range: acceptable-range,
                certification-body: certification-body
            }
        )
        
        ;; Update batch with new test count
        (let
            (
                (new-total (+ (get quality-tests-total batch-info) u1))
                (new-passed (if (is-eq test-result "passed")
                                (+ (get quality-tests-passed batch-info) u1)
                                (get quality-tests-passed batch-info)
                            )
                )
            )
            (map-set drug-batches
                { batch-id: batch-id }
                (merge batch-info {
                    quality-tests-total: new-total,
                    quality-tests-passed: new-passed,
                    updated-at: burn-block-height
                })
            )
        )
        (ok test-id)
    )
)

;; Public function to add raw material information
(define-public (add-raw-material
    (batch-id uint)
    (material-id uint)
    (material-name (string-ascii 100))
    (supplier (string-ascii 100))
    (lot-number (string-ascii 50))
    (quantity-used uint)
    (purity-level (string-ascii 20))
    (source-country (string-ascii 50))
    )
    (let
        (
            (batch-info (unwrap! (map-get? drug-batches { batch-id: batch-id }) ERR_BATCH_NOT_FOUND))
        )
        (asserts! (is-eq (get manufacturer batch-info) tx-sender) ERR_NOT_AUTHORIZED)
        
        (map-set raw-materials
            { batch-id: batch-id, material-id: material-id }
            {
                material-name: material-name,
                supplier: supplier,
                lot-number: lot-number,
                quantity-used: quantity-used,
                purity-level: purity-level,
                source-country: source-country,
                verification-status: "verified"
            }
        )
        (ok material-id)
    )
)

;; Public function to update batch status
(define-public (update-batch-status
    (batch-id uint)
    (new-status (string-ascii 20))
    )
    (let
        (
            (batch-info (unwrap! (map-get? drug-batches { batch-id: batch-id }) ERR_BATCH_NOT_FOUND))
        )
        (asserts! (is-eq (get manufacturer batch-info) tx-sender) ERR_NOT_AUTHORIZED)
        
        (map-set drug-batches
            { batch-id: batch-id }
            (merge batch-info {
                status: new-status,
                updated-at: burn-block-height
            })
        )
        (ok new-status)
    )
)

;; Read-only functions
(define-read-only (get-batch-info (batch-id uint))
    (map-get? drug-batches { batch-id: batch-id })
)

(define-read-only (get-facility-info (facility-id (string-ascii 50)))
    (map-get? manufacturing-facilities { facility-id: facility-id })
)

(define-read-only (get-quality-test (batch-id uint) (test-id uint))
    (map-get? quality-tests { batch-id: batch-id, test-id: test-id })
)

(define-read-only (get-raw-material (batch-id uint) (material-id uint))
    (map-get? raw-materials { batch-id: batch-id, material-id: material-id })
)

(define-read-only (get-manufacturer-info (manufacturer principal))
    (map-get? authorized-manufacturers { manufacturer: manufacturer })
)

(define-read-only (get-next-batch-id)
    (var-get next-batch-id)
)

(define-read-only (is-batch-expired (batch-id uint))
    (match (map-get? drug-batches { batch-id: batch-id })
        batch-info (>= burn-block-height (get expiry-date batch-info))
        false
    )
)

(define-read-only (get-batch-quality-score (batch-id uint))
    (match (map-get? drug-batches { batch-id: batch-id })
        batch-info 
        (if (> (get quality-tests-total batch-info) u0)
            (/ (* (get quality-tests-passed batch-info) u100) (get quality-tests-total batch-info))
            u0
        )
        u0
    )
)

;; title: drug-manufacturing-registry
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

