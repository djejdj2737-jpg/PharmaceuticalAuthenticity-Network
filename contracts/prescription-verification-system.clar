;; Prescription Verification System Smart Contract
;; Verify legitimate prescriptions and prevent unauthorized distribution or resale

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_PRESCRIPTION_NOT_FOUND (err u404))
(define-constant ERR_PRESCRIPTION_EXPIRED (err u410))
(define-constant ERR_PRESCRIPTION_USED (err u409))
(define-constant ERR_INVALID_PRESCRIPTION_ID (err u400))
(define-constant ERR_INVALID_DOCTOR (err u402))
(define-constant ERR_INVALID_PHARMACY (err u403))
(define-constant ERR_INVALID_PATIENT (err u405))
(define-constant ERR_INSUFFICIENT_QUANTITY (err u406))
(define-constant ERR_DRUG_NOT_AVAILABLE (err u407))

;; Data Variables
(define-data-var next-prescription-id uint u1)
(define-data-var next-dispensing-id uint u1)

;; Data Maps
(define-map prescriptions
    { prescription-id: uint }
    {
        doctor: principal,
        patient: principal,
        drug-name: (string-ascii 100),
        dosage: (string-ascii 50),
        quantity: uint,
        refills-allowed: uint,
        refills-used: uint,
        issued-date: uint,
        expiry-date: uint,
        medical-condition: (string-ascii 100),
        prescription-hash: (string-ascii 64),
        status: (string-ascii 20),
        created-at: uint,
        updated-at: uint
    }
)

(define-map authorized-doctors
    { doctor: principal }
    {
        doctor-name: (string-ascii 100),
        license-number: (string-ascii 50),
        specialization: (string-ascii 100),
        hospital-affiliation: (string-ascii 100),
        phone-number: (string-ascii 20),
        email: (string-ascii 100),
        is-active: bool,
        registered-at: uint
    }
)

(define-map authorized-pharmacies
    { pharmacy: principal }
    {
        pharmacy-name: (string-ascii 100),
        license-number: (string-ascii 50),
        address: (string-ascii 200),
        phone-number: (string-ascii 20),
        pharmacist-in-charge: (string-ascii 100),
        operating-hours: (string-ascii 50),
        is-active: bool,
        registered-at: uint
    }
)

(define-map patient-records
    { patient: principal }
    {
        patient-name: (string-ascii 100),
        date-of-birth: uint,
        national-id: (string-ascii 50),
        phone-number: (string-ascii 20),
        address: (string-ascii 200),
        allergies: (string-ascii 200),
        medical-history: (string-ascii 500),
        emergency-contact: (string-ascii 100),
        is-active: bool,
        registered-at: uint
    }
)

(define-map prescription-dispensing
    { dispensing-id: uint }
    {
        prescription-id: uint,
        pharmacy: principal,
        pharmacist: principal,
        quantity-dispensed: uint,
        dispensing-date: uint,
        batch-number: (string-ascii 50),
        manufacturer: (string-ascii 100),
        drug-lot-number: (string-ascii 50),
        expiry-date: uint,
        patient-signature: bool,
        verification-status: (string-ascii 20)
    }
)

(define-map drug-interactions
    { drug-name-1: (string-ascii 100), drug-name-2: (string-ascii 100) }
    {
        interaction-level: (string-ascii 20),
        description: (string-ascii 200),
        warning-message: (string-ascii 200)
    }
)

;; Authorization functions
(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (is-authorized-doctor (doctor principal))
    (match (map-get? authorized-doctors { doctor: doctor })
        doctor-info (get is-active doctor-info)
        false
    )
)

(define-private (is-authorized-pharmacy (pharmacy principal))
    (match (map-get? authorized-pharmacies { pharmacy: pharmacy })
        pharmacy-info (get is-active pharmacy-info)
        false
    )
)

(define-private (is-registered-patient (patient principal))
    (match (map-get? patient-records { patient: patient })
        patient-info (get is-active patient-info)
        false
    )
)

;; Public functions for registration
(define-public (register-doctor
    (doctor principal)
    (doctor-name (string-ascii 100))
    (license-number (string-ascii 50))
    (specialization (string-ascii 100))
    (hospital-affiliation (string-ascii 100))
    (phone-number (string-ascii 20))
    (email (string-ascii 100))
    )
    (begin
        (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
        (map-set authorized-doctors
            { doctor: doctor }
            {
                doctor-name: doctor-name,
                license-number: license-number,
                specialization: specialization,
                hospital-affiliation: hospital-affiliation,
                phone-number: phone-number,
                email: email,
                is-active: true,
                registered-at: burn-block-height
            }
        )
        (ok doctor)
    )
)

(define-public (register-pharmacy
    (pharmacy principal)
    (pharmacy-name (string-ascii 100))
    (license-number (string-ascii 50))
    (address (string-ascii 200))
    (phone-number (string-ascii 20))
    (pharmacist-in-charge (string-ascii 100))
    (operating-hours (string-ascii 50))
    )
    (begin
        (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
        (map-set authorized-pharmacies
            { pharmacy: pharmacy }
            {
                pharmacy-name: pharmacy-name,
                license-number: license-number,
                address: address,
                phone-number: phone-number,
                pharmacist-in-charge: pharmacist-in-charge,
                operating-hours: operating-hours,
                is-active: true,
                registered-at: burn-block-height
            }
        )
        (ok pharmacy)
    )
)

(define-public (register-patient
    (patient-name (string-ascii 100))
    (date-of-birth uint)
    (national-id (string-ascii 50))
    (phone-number (string-ascii 20))
    (address (string-ascii 200))
    (allergies (string-ascii 200))
    (medical-history (string-ascii 500))
    (emergency-contact (string-ascii 100))
    )
    (begin
        (map-set patient-records
            { patient: tx-sender }
            {
                patient-name: patient-name,
                date-of-birth: date-of-birth,
                national-id: national-id,
                phone-number: phone-number,
                address: address,
                allergies: allergies,
                medical-history: medical-history,
                emergency-contact: emergency-contact,
                is-active: true,
                registered-at: burn-block-height
            }
        )
        (ok tx-sender)
    )
)

;; Public function to create prescription
(define-public (create-prescription
    (patient principal)
    (drug-name (string-ascii 100))
    (dosage (string-ascii 50))
    (quantity uint)
    (refills-allowed uint)
    (expiry-date uint)
    (medical-condition (string-ascii 100))
    (prescription-hash (string-ascii 64))
    )
    (let
        (
            (prescription-id (var-get next-prescription-id))
        )
        (asserts! (is-authorized-doctor tx-sender) ERR_INVALID_DOCTOR)
        (asserts! (is-registered-patient patient) ERR_INVALID_PATIENT)
        (asserts! (> expiry-date burn-block-height) ERR_PRESCRIPTION_EXPIRED)
        (asserts! (> quantity u0) ERR_INVALID_PRESCRIPTION_ID)
        
        (map-set prescriptions
            { prescription-id: prescription-id }
            {
                doctor: tx-sender,
                patient: patient,
                drug-name: drug-name,
                dosage: dosage,
                quantity: quantity,
                refills-allowed: refills-allowed,
                refills-used: u0,
                issued-date: burn-block-height,
                expiry-date: expiry-date,
                medical-condition: medical-condition,
                prescription-hash: prescription-hash,
                status: "active",
                created-at: burn-block-height,
                updated-at: burn-block-height
            }
        )
        (var-set next-prescription-id (+ prescription-id u1))
        (ok prescription-id)
    )
)

;; Public function to dispense medication
(define-public (dispense-medication
    (prescription-id uint)
    (pharmacist principal)
    (quantity-dispensed uint)
    (batch-number (string-ascii 50))
    (manufacturer (string-ascii 100))
    (drug-lot-number (string-ascii 50))
    (drug-expiry-date uint)
    )
    (let
        (
            (prescription-info (unwrap! (map-get? prescriptions { prescription-id: prescription-id }) ERR_PRESCRIPTION_NOT_FOUND))
            (dispensing-id (var-get next-dispensing-id))
        )
        (asserts! (is-authorized-pharmacy tx-sender) ERR_INVALID_PHARMACY)
        (asserts! (is-eq (get status prescription-info) "active") ERR_PRESCRIPTION_USED)
        (asserts! (< burn-block-height (get expiry-date prescription-info)) ERR_PRESCRIPTION_EXPIRED)
        (asserts! (>= (get quantity prescription-info) quantity-dispensed) ERR_INSUFFICIENT_QUANTITY)
        
        ;; Record dispensing transaction
        (map-set prescription-dispensing
            { dispensing-id: dispensing-id }
            {
                prescription-id: prescription-id,
                pharmacy: tx-sender,
                pharmacist: pharmacist,
                quantity-dispensed: quantity-dispensed,
                dispensing-date: burn-block-height,
                batch-number: batch-number,
                manufacturer: manufacturer,
                drug-lot-number: drug-lot-number,
                expiry-date: drug-expiry-date,
                patient-signature: true,
                verification-status: "verified"
            }
        )
        
        ;; Update prescription quantity and refills
        (let
            (
                (remaining-quantity (- (get quantity prescription-info) quantity-dispensed))
                (new-refills (if (is-eq remaining-quantity u0) (+ (get refills-used prescription-info) u1) (get refills-used prescription-info)))
                (new-status (if (and (is-eq remaining-quantity u0) (>= new-refills (get refills-allowed prescription-info))) "completed" "active"))
            )
            (map-set prescriptions
                { prescription-id: prescription-id }
                (merge prescription-info {
                    quantity: remaining-quantity,
                    refills-used: new-refills,
                    status: new-status,
                    updated-at: burn-block-height
                })
            )
        )
        
        (var-set next-dispensing-id (+ dispensing-id u1))
        (ok dispensing-id)
    )
)

;; Public function to add drug interaction
(define-public (add-drug-interaction
    (drug-name-1 (string-ascii 100))
    (drug-name-2 (string-ascii 100))
    (interaction-level (string-ascii 20))
    (description (string-ascii 200))
    (warning-message (string-ascii 200))
    )
    (begin
        (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
        (map-set drug-interactions
            { drug-name-1: drug-name-1, drug-name-2: drug-name-2 }
            {
                interaction-level: interaction-level,
                description: description,
                warning-message: warning-message
            }
        )
        (ok true)
    )
)

;; Public function to verify prescription authenticity
(define-public (verify-prescription
    (prescription-id uint)
    (verification-hash (string-ascii 64))
    )
    (let
        (
            (prescription-info (unwrap! (map-get? prescriptions { prescription-id: prescription-id }) ERR_PRESCRIPTION_NOT_FOUND))
        )
        (ok (is-eq (get prescription-hash prescription-info) verification-hash))
    )
)

;; Read-only functions
(define-read-only (get-prescription-info (prescription-id uint))
    (map-get? prescriptions { prescription-id: prescription-id })
)

(define-read-only (get-doctor-info (doctor principal))
    (map-get? authorized-doctors { doctor: doctor })
)

(define-read-only (get-pharmacy-info (pharmacy principal))
    (map-get? authorized-pharmacies { pharmacy: pharmacy })
)

(define-read-only (get-patient-info (patient principal))
    (map-get? patient-records { patient: patient })
)

(define-read-only (get-dispensing-info (dispensing-id uint))
    (map-get? prescription-dispensing { dispensing-id: dispensing-id })
)

(define-read-only (get-drug-interaction (drug-name-1 (string-ascii 100)) (drug-name-2 (string-ascii 100)))
    (map-get? drug-interactions { drug-name-1: drug-name-1, drug-name-2: drug-name-2 })
)

(define-read-only (is-prescription-valid (prescription-id uint))
    (match (map-get? prescriptions { prescription-id: prescription-id })
        prescription-info 
        (and 
            (is-eq (get status prescription-info) "active")
            (< burn-block-height (get expiry-date prescription-info))
            (> (get quantity prescription-info) u0)
        )
        false
    )
)

(define-read-only (get-next-prescription-id)
    (var-get next-prescription-id)
)

(define-read-only (get-next-dispensing-id)
    (var-get next-dispensing-id)
)

(define-read-only (check-refills-available (prescription-id uint))
    (match (map-get? prescriptions { prescription-id: prescription-id })
        prescription-info
        (- (get refills-allowed prescription-info) (get refills-used prescription-info))
        u0
    )
)

;; title: prescription-verification-system
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

