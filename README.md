# DonateTrack

---

## Table of Contents
- Description
- Features
- Error Codes
- Public Functions
  - `register-charity`
  - `verify-charity`
  - `create-campaign`
  - `donate-to-campaign`
  - `generate-donation-report`
- Read-Only Functions
  - `get-charity-info`
  - `get-campaign-info`
  - `get-donation-info`
  - `get-donor-charity-total`
  - `get-platform-stats`
- How to Use
- Contribution
- License

---

## Description
This Clarity smart contract, **DonateTrack**, establishes a transparent and accountable system for managing charitable organizations, donation campaigns, and tracking contributions on the Stacks blockchain. It ensures verifiable proof of donations for donors and provides charities with robust tools to manage multiple fundraising campaigns.

---

## Features
* **Charity Registration & Verification**: Allows organizations to register and enables the contract owner to verify them.
* **Campaign Management**: Verified charities can create and manage multiple donation campaigns with defined targets and durations.
* **Transparent Donations**: Facilitates secure STX donations to campaigns, with every transaction immutably recorded.
* **Comprehensive Tracking**: Tracks individual donations, donor history per charity, and platform-wide donation statistics.
* **Advanced Reporting**: Provides charities with a function to generate detailed donation reports for specified periods, enhancing transparency and reporting.
* **Decentralized & Verifiable**: All data and transactions are stored on the blockchain, ensuring transparency and immutability.

---

## Error Codes
| Error Code | Identifier                      | Description                                    |
| :--------- | :------------------------------ | :--------------------------------------------- |
| `u1000`    | `ERR-NOT-AUTHORIZED`            | The caller is not authorized to perform this action. |
| `u1001`    | `ERR-CHARITY-NOT-FOUND`         | The specified charity ID does not exist.       |
| `u1002`    | `ERR-CAMPAIGN-NOT-FOUND`        | The specified campaign ID does not exist.      |
| `u1003`    | `ERR-CAMPAIGN-ENDED`            | The donation campaign has ended or is inactive. |
| `u1004`    | `ERR-INVALID-AMOUNT`            | The provided amount is invalid (e.g., zero or negative). |
| `u1005`    | `ERR-CHARITY-ALREADY-EXISTS`    | A charity with the generated ID already exists (internal error). |
| `u1006`    | `ERR-CAMPAIGN-ALREADY-EXISTS`   | A campaign with the generated ID already exists (internal error). |
| `u1007`    | `ERR-INSUFFICIENT-FUNDS`        | The sender has insufficient funds for the transaction. |
| `u1008`    | `ERR-WITHDRAWAL-LIMIT-EXCEEDED` | Not implemented in this version, but reserved for future withdrawal limits. |

---

## Public Functions

### `register-charity`
Registers a new charitable organization on the platform. The `tx-sender` becomes the wallet address for the charity.

* **Parameters**
    * `name` (string-ascii 100): The name of the charity.
    * `description` (string-ascii 500): A brief description of the charity.
* **Returns**
    * `(ok uint)`: The ID of the newly registered charity.
    * `(err u1005)`: If a charity with the generated ID somehow already exists.

### `verify-charity`
Verifies a registered charity. Only the `CONTRACT-OWNER` can call this function. Verified charities are marked as trustworthy.

* **Parameters**
    * `charity-id` (uint): The ID of the charity to verify.
* **Returns**
    * `(ok true)`: If the charity was successfully verified.
    * `(err u1000)`: If the `tx-sender` is not the `CONTRACT-OWNER`.
    * `(err u1001)`: If the charity ID is not found.

### `create-campaign`
Allows a registered charity to create a new donation campaign.

* **Parameters**
    * `charity-id` (uint): The ID of the charity creating the campaign.
    * `title` (string-ascii 100): The title of the campaign.
    * `description` (string-ascii 500): A description of the campaign.
    * `target-amount` (uint): The fundraising target for the campaign in micro-STX.
    * `duration-blocks` (uint): The duration of the campaign in blockchain blocks.
* **Returns**
    * `(ok uint)`: The ID of the newly created campaign.
    * `(err u1001)`: If the charity ID is not found.
    * `(err u1000)`: If the `tx-sender` is not the registered wallet for the specified charity.
    * `(err u1004)`: If `target-amount` or `duration-blocks` is zero.

### `donate-to-campaign`
Allows a donor to contribute STX to an active donation campaign.

* **Parameters**
    * `campaign-id` (uint): The ID of the campaign to donate to.
    * `amount` (uint): The amount of STX (in micro-STX) to donate.
    * `message` (string-ascii 200): An optional message from the donor.
* **Returns**
    * `(ok uint)`: The ID of the recorded donation.
    * `(err u1002)`: If the campaign ID is not found.
    * `(err u1001)`: If the charity associated with the campaign is not found (internal error).
    * `(err u1004)`: If the `amount` is zero.
    * `(err u1003)`: If the campaign has ended or is inactive.
    * `(err u1007)`: If the `tx-sender` has insufficient funds.

### `generate-donation-report`
Generates a detailed report of donations for a specific charity within a given block range, with an optional minimum donation amount filter. Only the charity's registered wallet can call this.

* **Parameters**
    * `charity-id` (uint): The ID of the charity for which to generate the report.
    * `start-block` (uint): The starting block height for the report period.
    * `end-block` (uint): The ending block height for the report period.
    * `min-donation-amount` (uint): The minimum donation amount to include in the report.
* **Returns**
    * `(ok (tuple))` An object containing:
        * `charity-info`: Details about the charity.
        * `report-period`: The start, end, and current block heights of the report.
        * `filters`: Applied filters (e.g., `min-donation-amount`).
        * `analytics`: Total platform donations and this charity's percentage of it.
    * `(err u1001)`: If the charity ID is not found.
    * `(err u1000)`: If the `tx-sender` is not the registered wallet for the specified charity.
    * `(err u1004)`: If `start-block` is greater than `end-block`.

---

## Read-Only Functions
These functions allow anyone to query the contract's state without initiating a transaction.

### `get-charity-info`
Retrieves the details of a specific charity.

* **Parameters**
    * `charity-id` (uint): The ID of the charity.
* **Returns**
    * `(optional (tuple))`: Charity data if found, otherwise `none`.

### `get-campaign-info`
Retrieves the details of a specific donation campaign.

* **Parameters**
    * `campaign-id` (uint): The ID of the campaign.
* **Returns**
    * `(optional (tuple))`: Campaign data if found, otherwise `none`.

### `get-donation-info`
Retrieves the details of a specific donation.

* **Parameters**
    * `donation-id` (uint): The ID of the donation.
* **Returns**
    * `(optional (tuple))`: Donation data if found, otherwise `none`.

### `get-donor-charity-total`
Retrieves the total amount donated by a specific donor to a specific charity and their donation count.

* **Parameters**
    * `donor` (principal): The principal address of the donor.
    * `charity-id` (uint): The ID of the charity.
* **Returns**
    * `(optional (tuple))`: Donor's total and count for the charity if found, otherwise `none`.

### `get-platform-stats`
Retrieves overall platform statistics, including total donations and next available IDs.

* **Parameters**: None
* **Returns**
    * `(tuple)`: An object containing `total-donations`, `next-charity-id`, `next-campaign-id`, and `next-donation-id`.

---

## How to Use
To interact with this contract, you'll need a Stacks wallet and some STX tokens. You can deploy this contract to the Stacks blockchain and then call its public functions using a Clarity-compatible SDK or explorer.

**Example Flow:**
1.  **Deploy** the `DonateTrack` contract to the Stacks blockchain.
2.  **Register a Charity**: A charity owner calls `register-charity` to get a `charity-id`.
3.  **Verify Charity**: The `CONTRACT-OWNER` (deployer of the contract) calls `verify-charity` with the `charity-id` to mark it as verified.
4.  **Create a Campaign**: The verified charity owner calls `create-campaign` to set up a new fundraising initiative.
5.  **Donate**: Donors call `donate-to-campaign` to send STX to a live campaign.
6.  **Generate Reports**: The charity owner can call `generate-donation-report` for transparency and record-keeping.
7.  **Query Data**: Anyone can use the read-only functions like `get-charity-info`, `get-campaign-info`, and `get-donation-info` to verify data.

---

## Contribution
Contributions are welcome! If you have suggestions for improvements or find any issues, please open an issue or submit a pull request to the repository where this contract is hosted.

---

## License
This contract is released under the MIT License. See the `LICENSE` file in the repository for full details.
