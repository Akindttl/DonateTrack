;; Decentralized Charity and Donation Tracking Contract
;; This contract manages charitable organizations, donation campaigns, and tracks all donations
;; transparently on the blockchain. It ensures accountability and provides donors with verifiable
;; proof of their contributions while enabling charities to manage multiple campaigns.

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-CHARITY-NOT-FOUND (err u1001))
(define-constant ERR-CAMPAIGN-NOT-FOUND (err u1002))
(define-constant ERR-CAMPAIGN-ENDED (err u1003))
(define-constant ERR-INVALID-AMOUNT (err u1004))
(define-constant ERR-CHARITY-ALREADY-EXISTS (err u1005))
(define-constant ERR-CAMPAIGN-ALREADY-EXISTS (err u1006))
(define-constant ERR-INSUFFICIENT-FUNDS (err u1007))
(define-constant ERR-WITHDRAWAL-LIMIT-EXCEEDED (err u1008))

;; Data maps and variables
;; Map to store charity information
(define-map charities
    { charity-id: uint }
    {
        name: (string-ascii 100),
        description: (string-ascii 500),
        wallet: principal,
        is-verified: bool,
        total-raised: uint,
        registration-block: uint
    }
)

;; Map to store donation campaigns
(define-map campaigns
    { campaign-id: uint }
    {
        charity-id: uint,
        title: (string-ascii 100),
        description: (string-ascii 500),
        target-amount: uint,
        current-amount: uint,
        start-block: uint,
        end-block: uint,
        is-active: bool
    }
)

;; Map to track individual donations
(define-map donations
    { donation-id: uint }
    {
        donor: principal,
        charity-id: uint,
        campaign-id: uint,
        amount: uint,
        block-height: uint,
        message: (string-ascii 200)
    }
)

;; Map to track donor history per charity
(define-map donor-charity-totals
    { donor: principal, charity-id: uint }
    { total-donated: uint, donation-count: uint }
)

;; Global counters
(define-data-var next-charity-id uint u1)
(define-data-var next-campaign-id uint u1)
(define-data-var next-donation-id uint u1)
(define-data-var total-platform-donations uint u0)

;; Private functions
;; Validate that a charity exists and return its data
(define-private (get-charity-or-fail (charity-id uint))
    (ok (unwrap! (map-get? charities { charity-id: charity-id }) ERR-CHARITY-NOT-FOUND))
)

;; Validate that a campaign exists and return its data
(define-private (get-campaign-or-fail (campaign-id uint))
    (ok (unwrap! (map-get? campaigns { campaign-id: campaign-id }) ERR-CAMPAIGN-NOT-FOUND))
)

;; Check if campaign is still active based on block height
(define-private (is-campaign-active (campaign-data (tuple (charity-id uint) (title (string-ascii 100)) (description (string-ascii 500)) (target-amount uint) (current-amount uint) (start-block uint) (end-block uint) (is-active bool))))
    (and 
        (get is-active campaign-data)
        (>= block-height (get start-block campaign-data))
        (<= block-height (get end-block campaign-data))
    )
)

;; Update donor totals for a specific charity
(define-private (update-donor-totals (donor principal) (charity-id uint) (amount uint))
    (let ((current-totals (default-to { total-donated: u0, donation-count: u0 } 
                                     (map-get? donor-charity-totals { donor: donor, charity-id: charity-id }))))
        (map-set donor-charity-totals 
            { donor: donor, charity-id: charity-id }
            {
                total-donated: (+ (get total-donated current-totals) amount),
                donation-count: (+ (get donation-count current-totals) u1)
            }
        )
    )
)

;; Public functions
;; Register a new charity organization
(define-public (register-charity (name (string-ascii 100)) (description (string-ascii 500)))
    (let ((charity-id (var-get next-charity-id)))
        (asserts! (is-none (map-get? charities { charity-id: charity-id })) ERR-CHARITY-ALREADY-EXISTS)
        (map-set charities 
            { charity-id: charity-id }
            {
                name: name,
                description: description,
                wallet: tx-sender,
                is-verified: false,
                total-raised: u0,
                registration-block: block-height
            }
        )
        (var-set next-charity-id (+ charity-id u1))
        (ok charity-id)
    )
)

;; Verify a charity (only contract owner can do this)
(define-public (verify-charity (charity-id uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (let ((charity-data (try! (get-charity-or-fail charity-id))))
            (map-set charities 
                { charity-id: charity-id }
                (merge charity-data { is-verified: true })
            )
            (ok true)
        )
    )
)

;; Create a new donation campaign
(define-public (create-campaign 
    (charity-id uint) 
    (title (string-ascii 100)) 
    (description (string-ascii 500)) 
    (target-amount uint) 
    (duration-blocks uint))
    (let ((campaign-id (var-get next-campaign-id))
          (charity-data (try! (get-charity-or-fail charity-id))))
        (asserts! (is-eq tx-sender (get wallet charity-data)) ERR-NOT-AUTHORIZED)
        (asserts! (> target-amount u0) ERR-INVALID-AMOUNT)
        (asserts! (> duration-blocks u0) ERR-INVALID-AMOUNT)
        (map-set campaigns 
            { campaign-id: campaign-id }
            {
                charity-id: charity-id,
                title: title,
                description: description,
                target-amount: target-amount,
                current-amount: u0,
                start-block: block-height,
                end-block: (+ block-height duration-blocks),
                is-active: true
            }
        )
        (var-set next-campaign-id (+ campaign-id u1))
        (ok campaign-id)
    )
)

;; Make a donation to a specific campaign
(define-public (donate-to-campaign (campaign-id uint) (amount uint) (message (string-ascii 200)))
    (let ((campaign-data (try! (get-campaign-or-fail campaign-id)))
          (charity-data (try! (get-charity-or-fail (get charity-id campaign-data))))
          (donation-id (var-get next-donation-id)))
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (is-campaign-active campaign-data) ERR-CAMPAIGN-ENDED)
        
        ;; Transfer STX from donor to charity wallet
        (try! (stx-transfer? amount tx-sender (get wallet charity-data)))
        
        ;; Record the donation
        (map-set donations 
            { donation-id: donation-id }
            {
                donor: tx-sender,
                charity-id: (get charity-id campaign-data),
                campaign-id: campaign-id,
                amount: amount,
                block-height: block-height,
                message: message
            }
        )
        
        ;; Update campaign amount
        (map-set campaigns 
            { campaign-id: campaign-id }
            (merge campaign-data { current-amount: (+ (get current-amount campaign-data) amount) })
        )
        
        ;; Update charity total
        (map-set charities 
            { charity-id: (get charity-id campaign-data) }
            (merge charity-data { total-raised: (+ (get total-raised charity-data) amount) })
        )
        
        ;; Update donor totals
        (update-donor-totals tx-sender (get charity-id campaign-data) amount)
        
        ;; Update global counters
        (var-set next-donation-id (+ donation-id u1))
        (var-set total-platform-donations (+ (var-get total-platform-donations) amount))
        
        (ok donation-id)
    )
)

;; Read-only functions for querying data
(define-read-only (get-charity-info (charity-id uint))
    (map-get? charities { charity-id: charity-id })
)

(define-read-only (get-campaign-info (campaign-id uint))
    (map-get? campaigns { campaign-id: campaign-id })
)

(define-read-only (get-donation-info (donation-id uint))
    (map-get? donations { donation-id: donation-id })
)

(define-read-only (get-donor-charity-total (donor principal) (charity-id uint))
    (map-get? donor-charity-totals { donor: donor, charity-id: charity-id })
)

(define-read-only (get-platform-stats)
    {
        total-donations: (var-get total-platform-donations),
        next-charity-id: (var-get next-charity-id),
        next-campaign-id: (var-get next-campaign-id),
        next-donation-id: (var-get next-donation-id)
    }
)


