# Payment & Token Module Overview

## 1. Payment Module Architecture

### 1.1 Payment Controller
**Location:** [backend/src/controllers/payment.controller.ts](backend/src/controllers/payment.controller.ts)

**Key Endpoints:**
- **`createPaymentOrder`** - Creates a Razorpay payment order
- **`getTokenBalance`** - Fetches user's token balance and wallet info
- **`getTokenTransactions`** - Lists token transaction history with pagination
- **`handleRazorpayWebhook`** - Processes Razorpay webhook events
- **`getFeatureCosts`** - Returns feature costs summary

### 1.2 Payment Model Schema
**Location:** [backend/src/models/payment.model.ts](backend/src/models/payment.model.ts)

```typescript
// Payment Status Enum
CREATED   // Order created but not paid
PAID      // Successfully paid
FAILED    // Payment failed
REFUNDED  // Refunded

// Payment Document Fields
- user_id (ObjectId, ref: 'User')
- provider (String, default: 'razorpay')
- plan_id (String)
- amount_inr (Number)
- amount_paise (Number) // Amount in smallest currency unit
- tokens_granted (Number) // Token amount granted after payment
- status (Enum)
- order_id (String, indexed)
- payment_id (String) // Razorpay payment ID
- signature (String) // Webhook signature
- receipt (String)
- notes (Mixed)
- timestamps (createdAt, updatedAt)

// Indexes
- user_id + createdAt
- status + createdAt
```

### 1.3 Payment Service
**Location:** [backend/src/services/payment.service.ts](backend/src/services/payment.service.ts)

#### Key Functions:

**1. `createPaymentOrder(params)`**
- Creates Razorpay order via `createRazorpayOrder()`
- Validates plan exists via `resolvePlan()`
- Creates Payment document with status: CREATED
- Returns order details + Razorpay key_id

**2. `handleRazorpayWebhook(params)`**
- Verifies webhook signature
- Listens to payment events: `payment.captured`, `payment.failed`
- On success (captured):
  - Updates Payment status to PAID
  - Stores payment_id and signature
  - **Credits tokens via two services:**
    - `creditFromPayment()` → token.service (manages wallet)
    - `creditTokensForPayment()` → patient-token.service (caps at max)
  - Broadcasts notification to admins
- On failure: Updates status to FAILED

**3. `getPayments(params)`**
- Pagination: page, limit, status filter
- Returns payments with user info (login_id, user_type)

---

## 2. Token System Overview

### 2.1 Token Wallet Model
**Location:** [backend/src/models/tokenwallet.model.ts](backend/src/models/tokenwallet.model.ts)

```typescript
// TokenWallet Schema
- user_id (ObjectId, unique, indexed)
- balance (Number, default: 0)
- max_tokens (Number, default: 200) // Hard cap on balance
- currency (String, default: 'INR')
- timestamps
```

**Key Concept:** Each user has ONE wallet with a maximum balance cap of 200 tokens.

### 2.2 Token Transaction Model
**Location:** [backend/src/models/tokentransaction.model.ts](backend/src/models/tokentransaction.model.ts)

```typescript
// TokenTransaction Schema
- user_id (ObjectId, indexed)
- delta (Number) // Positive for credit, negative for debit
- balance_after (Number) // Wallet balance after transaction
- feature_key (String) // Which feature was used
- weight (Number) // Token amount involved
- source (Enum): USAGE | PAYMENT | ADJUSTMENT
- request_id (String) // For tracing
- payment_id (ObjectId, ref: 'Payment')
- metadata (Mixed)
- timestamps

// Indexes
- user_id + createdAt
- source + createdAt
```

### 2.3 Token = Fee-Based Access Model

**Purpose:** Token system gates access to premium features.

**Feature costs are configured in SystemConfig.feature_weights:**

| Feature | Default Cost (Tokens) |
|---------|------------------------|
| PATIENT_DOSAGE | 2 |
| PATIENT_HEALTH_LOG | 1 |
| PATIENT_PROFILE_UPDATE | 1 |
| PATIENT_REPORT_SUBMIT | 2 |

All feature costs are centrally managed through SystemConfig for consistency and flexibility.

---

## 3. Token Reduction (Deduction) Flow

### 3.1 Two Token Deduction Paths

#### Path A: Feature-Based Deduction (patient-token.service)
**Function:** `deductTokensForFeature(userId, feature, metadata)`

**Step-by-Step:**
1. **Check Sufficient Tokens**
   - Calls `checkSufficientTokens(userId, feature)`
   - Retrieves feature cost from DEFAULT_FEATURE_COSTS
   - Validates wallet.balance >= cost
   - Throws `PAYMENT_REQUIRED` error if insufficient

2. **Deduct from Wallet**
   - Uses atomic operation: `TokenWallet.findOneAndUpdate()`
   - Decrements balance by cost amount
   - Condition: `balance: { $gte: cost }` (atomic check)

3. **Record Transaction**
   - Creates TokenTransaction with:
     - delta: `-cost` (negative for deduction)
     - balance_after: updated balance
     - source: 'PATIENT_SERVICE'
     - feature_key: PatientFeature enum
     - weight: cost amount
     - metadata: optional operation details

4. **Error Handling**
   - If findOneAndUpdate returns null → insufficient balance
   - Throws `PAYMENT_REQUIRED` error

**Usage:** When patient performs paid actions (upload report, log health data, etc.)

---

#### Path B: Generic Weight-Based Deduction (token.service)
**Function:** `debitForFeature(params)`

**Parameters:**
```typescript
{
  userId: string
    featureKey: FeatureKey ('PATIENT_DOSAGE', 'PATIENT_HEALTH_LOG', etc.)
  weight: number // Token amount to deduct
  requestId?: string
}
```

**Step-by-Step:**
1. **Skip if No Cost** - Returns null if weight <= 0

2. **Fetch Token Config**
   - Gets precision setting (default: 2 decimals)
   - Allows fractional tokens if enabled

3. **Atomic Deduction**
   - Condition: `balance: { $gte: params.weight }`
   - Operation: `$inc: { balance: -params.weight }`
   - Returns updated wallet or throws error

4. **Precision Rounding**
   - Rounds balance to configured precision
   - Updates wallet if rounding changed value

5. **Record Transaction**
   - Creates TokenTransaction with:
     - delta: `-params.weight`
     - source: TokenTransactionSource.USAGE
     - feature_key: provided feature
     - weight: token amount

**Usage:** Flexible deduction with weight parameter instead of fixed costs

---

### 3.2 Deduction Process Diagram
```
User Performs Paid Action (e.g., Upload Report)
        ↓
Call deductTokensForFeature(userId, REPORT_UPLOAD)
        ↓
Check Sufficient Tokens (25 tokens needed)
        ↓ (if insufficient)
Throw PAYMENT_REQUIRED Error
        ↓ (if sufficient)
Atomic Update: balance -= 25
        ↓
Create TokenTransaction (delta: -25, source: PATIENT_SERVICE)
        ↓
Return { wallet, transaction }
```

---

## 4. Token Credit (Payment) Flow

### 4.1 Two Credit Services Work Together

#### Service 1: token.service - `creditFromPayment()`
```typescript
creditFromPayment({
  userId,
  amount, // Tokens to credit
  paymentId, // Reference to payment
  requestId?
})
```

**Process:**
1. Fetches token config (precision settings)
2. Loads current wallet
3. Adds amount: `newBalance = balance + amount`
4. Rounds to configured precision
5. Updates wallet: `balance = roundedBalance`
6. Creates TokenTransaction:
   - delta: +amount
   - source: TokenTransactionSource.PAYMENT
   - payment_id: referenced payment

**No Max Cap Check** - Can exceed max_tokens

---

#### Service 2: patient-token.service - `creditTokensForPayment()`
```typescript
creditTokensForPayment(
  userId,
  amount, // Tokens to credit
  paymentId // Payment reference
)
```

**Process:**
1. Validates amount > 0
2. Fetches current wallet
3. **Applies Max Token Cap:**
   - maxTokens = wallet.max_tokens ?? 200
   - `newBalance = Math.min(balance + amount, maxTokens)`
   - Only credits up to cap: `actualCredit = newBalance - balance`

4. Updates wallet with capped balance
5. Creates TokenTransaction:
   - delta: actualCredit (may be less than amount if capped)
   - source: 'PAYMENT'
   - metadata: { payment_id }

**Example:**
```
User balance: 170
Max tokens: 200
Payment amount: 100
Actual credit: 30 (to reach 200 cap)
```

---

### 4.2 Why Two Services?

**In payment.service handleRazorpayWebhook():**
```typescript
// BOTH are called for redundancy + different purposes
await creditFromPayment({...}) // Primary: manages wallet
await creditTokensForPayment({...}) // Secondary: enforces max cap + alternative tracking
```

- **token.service:** Handles core wallet operations, no cap
- **patient-token.service:** Enforces max_tokens cap, patient-specific logic

---

## 5. Token Calculation Logic

### 5.1 Precision & Rounding
**Config Location:** SystemConfig.token_settings

```typescript
token_settings: {
  allow_fractional: Boolean (default: true) // Can balance have decimals?
  precision: Number (default: 2) // Decimal places
}
```

**Rounding Function:**
```typescript
const roundToPrecision = (value: number, precision: number) => {
  const factor = Math.pow(10, precision)
  return Math.round((value + Number.EPSILON) * factor) / factor
}
// Example: roundToPrecision(19.995, 2) = 20.00
```

### 5.2 Feature Cost Configuration
**Config Location:** SystemConfig.feature_weights

**Default Feature Costs (from SystemConfig):**
```typescript
feature_weights: {
  'PATIENT_DOSAGE': 2,
  'PATIENT_HEALTH_LOG': 1,
  'PATIENT_PROFILE_UPDATE': 1,
  'PATIENT_REPORT_SUBMIT': 2,
}
```

All feature costs are now centrally managed through SystemConfig. The `patient-token.service` fetches costs from SystemConfig dynamically when needed, ensuring consistency across the system.

---

## 6. Token Plans & Pricing

**Config Location:** SystemConfig.token_plans

**Default Plans:**
```typescript
token_plans: [
  {
    plan_id: 'basic_49',
    price_inr: 49,
    tokens: 100,
    is_active: true,
  },
  {
    plan_id: 'standard_99',
    price_inr: 99,
    tokens: 220, // Note: Exceeds max_tokens 200 cap
    is_active: true,
  },
]
```

**Important:** Standard plan grants 220 tokens but wallet maxes out at 200!

---

## 7. Complete Payment → Token Credit Flow

```
1. USER INITIATES PAYMENT
   ├─ POST /api/payments/create-order
   ├─ paymentService.createPaymentOrder(userId, planId)
   ├─ Plan Resolution: resolvePlan(planId) validates + gets tokens amount
   ├─ Razorpay Order: createRazorpayOrder(amountPaise) from Razorpay API
   └─ Create Payment Doc: Status = CREATED, tokens_granted = plan.tokens

2. RAZORPAY PROCESSES PAYMENT
   └─ User completes payment via Razorpay UI

3. WEBHOOK CALLBACK
   ├─ POST /api/payments/webhook
   ├─ paymentService.handleRazorpayWebhook(signature, payload)
   ├─ Verify Signature: verifyRazorpayWebhookSignature()
   ├─ Event Type Check: payment.captured or payment.failed
   │
   ├─ IF CAPTURED/SUCCESS:
   │  ├─ Update Payment: status = PAID, store payment_id + signature
   │  ├─ Credit Token (Core): creditFromPayment() via token.service
   │  │  └─ Add amount to balance, round, save
   │  ├─ Credit Token (Patient): creditTokensForPayment() via patient-token.service
   │  │  └─ Cap at max_tokens (200), create transaction
   │  ├─ Create TokenTransaction (from token.service)
   │  │  └─ delta: +amount, source: PAYMENT
   │  ├─ Create TokenTransaction (from patient-token.service)
   │  │  └─ delta: +actualCredit (may be capped), source: PAYMENT
   │  ├─ Notify Admins: broadcastNotification()
   │  └─ Return: { status: 'processed' }
   │
   └─ IF FAILED:
      ├─ Update Payment: status = FAILED
      └─ Return: { status: 'failed' }

4. USER HAS TOKENS
   └─ Balance capped at 200 (max_tokens)
```

---

## 8. API Response Examples

### 8.1 Get Token Balance
**Endpoint:** `GET /api/payments/balance`
**Controller:** `getTokenBalance()`

**Response:**
```json
{
  "statusCode": 200,
  "message": "Token balance fetched",
  "data": {
    "balance": 150,
    "max_tokens": 200,
    "currency": "INR"
  }
}
```

### 8.2 Get Token Transactions
**Endpoint:** `GET /api/payments/transactions?page=1&limit=20`
**Controller:** `getTokenTransactions()`

**Response:**
```json
{
  "statusCode": 200,
  "message": "Token transactions fetched",
  "data": {
    "transactions": [
      {
        "_id": "...",
        "user_id": "...",
        "delta": -25,
        "balance_after": 150,
        "feature_key": "REPORT_UPLOAD",
        "weight": 25,
        "source": "PATIENT_SERVICE",
        "createdAt": "2026-04-06T10:30:00Z"
      }
    ],
    "pagination": {
      "total": 45,
      "page": 1,
      "limit": 20,
      "pages": 3,
      "hasNext": true,
      "hasPrev": false
    }
  }
}
```

### 8.3 Get Feature Costs
**Endpoint:** `GET /api/payments/feature-costs`
**Controller:** `getFeatureCosts()`

**Response:**
```json
{
  "statusCode": 200,
  "message": "Feature costs fetched",
  "data": {
    "costs": {
      "DOCTOR_CONSULTATION": 100,
      "REPORT_UPLOAD": 25,
      "HEALTH_LOG_UPDATE": 10,
      "PROFILE_UPDATE": 15,
      "DOSAGE_LOG": 5,
      "VIDEO_CALL": 50
    }
  }
}
```

---

## 9. Total Token + Payment Module Summary

### 9.1 Architecture Stack
```
Payment Controller Layer
├─ createPaymentOrder()       → Initiates payment
├─ getTokenBalance()          → Wallet query
├─ getTokenTransactions()     → History query
├─ handleRazorpayWebhook()    → Payment confirmation
└─ getFeatureCosts()          → Cost lookup (from SystemConfig)

Payment Service Layer (payment.service)
├─ createPaymentOrder()       → Order creation + Razorpay
├─ handleRazorpayWebhook()    → Event processing
└─ getPayments()              → Admin queries

Token Service Layer (two services)
├─ token.service (generic)
│  ├─ ensureWallet()          → Create if missing
│  ├─ getBalance()            → Query balance
│  ├─ debitForFeature()       → Weight-based deduction
│  ├─ creditFromPayment()     → Credit + precision rounding
│  ├─ listTransactions()      → Transaction history
│  └─ resolvePlan()           → Validate payment plan
│
└─ patient-token.service (patient-specific)
   ├─ getFeatureCost()        → Cost lookup from SystemConfig
   ├─ checkSufficientTokens() → Validation
   ├─ deductTokensForFeature()→ Feature-specific deduction
   ├─ creditTokensForPayment()→ Credit with max cap enforcement
   ├─ getTokenBalance()       → Balance query
   ├─ getTokenHistory()       → Transaction query
   └─ getFeatureCostsSummary()→ Return all costs from SystemConfig

Database Models
├─ Payment              (payment records, status, amounts)
├─ TokenWallet          (per-user balance + cap)
└─ TokenTransaction     (audit trail of all movements)

Configuration (SystemConfig)
├─ token_plans[]          (plan definitions)
└─ feature_weights{}      (cost mapping)
└─ token_settings{}       (precision, fractional)
```

### 9.2 Data Flow Integration
```
                     User
                      ↓
                  Payment
                (PaymentDoc)
                      ↓
         ────────────────────────
         ↓                       ↓
    token.service    patient-token.service
         ↓                       ↓
   TokenWallet         TokenWallet
   (primary)          (capped at 200)
         ↓                       ↓
    TokenTransaction (audit trail)
```

### 9.3 Transaction Source Categories
For audit and analytics:

| Source | Meaning | Created By |
|--------|---------|-----------|
| PAYMENT | Token credit from payment | handleRazorpayWebhook() |
| USAGE | Token debit from feature | deductTokensForFeature(), debitForFeature() |
| ADJUSTMENT | Manual/admin adjustment | admin operations (future) |

### 9.4 Data Consistency Notes
✅ **Single Source of Truth:** All feature costs are now managed through SystemConfig.feature_weights. The `patient-token.service` fetches costs dynamically, eliminating hardcoded defaults and ensuring consistency across the system.

### 9.5 Key Constraints & Limits
```
Max Wallet Balance: 200 tokens (hard cap)
Plan Limit: standard_99 tries to grant 220 tokens (conflicts!)
Token Precision: 2 decimal places (configurable)
Payment Status: CREATED → PAID/FAILED (no PENDING state)
```

---

## 10. Error Scenarios & Handling

### 10.1 Payment Errors
```typescript
// Razorpay not configured
StatusCode: BAD_REQUEST (400)
Message: 'Razorpay credentials are not configured'

// Razorpay API failure
StatusCode: BAD_GATEWAY (502)
Message: 'Failed to create Razorpay order'

// Invalid plan
StatusCode: BAD_REQUEST (400)
Message: 'Invalid or inactive plan'

// Invalid webhook signature
StatusCode: BAD_REQUEST (400)
Message: 'Invalid Razorpay signature'
```

### 10.2 Token Errors
```typescript
// Insufficient balance for deduction
StatusCode: PAYMENT_REQUIRED (402)
Message: 'Insufficient token balance' or
Message: 'Insufficient tokens. Required: X, Available: Y'

// Wallet not found (edge case)
StatusCode: NOT_FOUND (404)
Message: 'Token wallet not found'

// Invalid credit amount
StatusCode: BAD_REQUEST (400)
Message: 'Amount must be greater than 0'
```

---

## Summary

This payment and token module implements a **fee-based feature access system** where:

1. **Users purchase tokens** through Razorpay payment gateway
2. **Tokens are capped** at 200 per wallet (hard limit)
3. **Feature costs are centralized** in SystemConfig.feature_weights (single source of truth)
4. **All movements tracked** in TokenTransaction for audit
5. **Precision controlled** via SystemConfig (2 decimal places by default)
6. **Dual credit services** (token.service + patient-token.service) for comprehensive token management with cap enforcement

The architecture maintains clean separation between core token logic (token.service) and patient-specific features (patient-token.service), while eliminating hardcoded defaults in favor of centralized SystemConfig management.
