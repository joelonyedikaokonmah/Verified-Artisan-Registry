# 🎨 Verified Artisan Registry

## 📋 Overview

The Verified Artisan Registry is a blockchain-based platform that empowers local artisans by providing a decentralized system for authenticating handmade goods and proving their origin. Built on the Stacks blockchain using Clarity smart contracts.

## 🚀 Key Features

- **🆔 Non-Transferable NFT Certificates**: Artisans receive permanent identity certificates
- **✅ Community Validation**: DAO-based verification system with multiple validators
- **📦 Product Authentication**: Link products to verified artisan profiles with cryptographic signatures
- **🔍 Origin Tracing**: Buyers can verify authenticity and trace product origins
- **🛡️ Anti-Counterfeit Protection**: Prevents mass-produced imitations from being misrepresented

## 🏗️ Architecture

The contract implements:
- **Artisan Registration**: Creates unique NFT certificates for artisans
- **Validator Network**: Community members can validate artisan authenticity
- **Product Catalog**: Verified artisans can create authenticated product listings
- **Ownership Tracking**: Products can be transferred while maintaining provenance

## 📖 Usage Instructions

### 👤 For Contract Administrators

#### Add Validators
```clarity
(contract-call? .verified-artisan-registry add-validator 'SP1234567890ABCDEF)
```

#### Set Validation Threshold
```clarity
(contract-call? .verified-artisan-registry update-validation-threshold u3)
```

### 🎨 For Artisans

#### 1. Register as an Artisan
```clarity
(contract-call? .verified-artisan-registry register-artisan 
    "John Smith" 
    "Handwoven Textiles" 
    "Portland, Oregon")
```

#### 2. Create Products (After Validation)
```clarity
(contract-call? .verified-artisan-registry create-product
    u1                              ;; artisan-id
    "Handwoven Scarf"              ;; name
    "Organic cotton scarf with traditional patterns"  ;; description
    "https://example.com/scarf.jpg" ;; image-uri
    u50000000                       ;; price (in micro-STX)
    0x1234567890abcdef...)          ;; cryptographic signature
```

### ✅ For Validators

#### Validate an Artisan
```clarity
(contract-call? .verified-artisan-registry validate-artisan u1)
```

### 🛒 For Buyers

#### Verify Product Authenticity
```clarity
(contract-call? .verified-artisan-registry verify-product-authenticity u1)
```

#### Check Artisan Validation Status
```clarity
(contract-call? .verified-artisan-registry is-artisan-validated u1)
```

## 🔍 Read-Only Functions

### Get Artisan Information
```clarity
(contract-call? .verified-artisan-registry get-artisan u1)
```

### Get Product Details
```clarity
(contract-call? .verified-artisan-registry get-product u1)
```

### Get Contract Statistics
```clarity
(contract-call? .verified-artisan-registry get-contract-stats)
```

## 🛡️ Security Features

- **Access Control**: Only contract owner can manage validators
- **Validation Requirements**: Artisans need multiple validator approvals
- **Non-Transferable NFTs**: Prevents certificate fraud
- **Emergency Pause**: Contract can be paused for security reasons

## 🧪 Testing

To run tests for the contract:

```bash
npm install
npm test
```

## 🚀 Deployment

1. Deploy using Clarinet:
```bash
clarinet deploy --testnet
```

2. Verify deployment:
```bash
clarinet check
```

## 📊 Contract Statistics

The contract tracks:
- Total registered artisans
- Total products created
- Current validation threshold
- Contract pause status

## 📄 License

This project is open source and available under the MIT License.

## 🌟 Impact

This registry empowers small creators by:
- **Building Trust**: Buyers can verify authentic handmade goods
- **Preventing Fraud**: Cryptographic signatures prevent counterfeiting
- **Supporting Artisans**: Direct connection between creators and buyers
- **Preserving Crafts**: Documenting traditional techniques and origins

---

*Built with ❤️ for the artisan community*
