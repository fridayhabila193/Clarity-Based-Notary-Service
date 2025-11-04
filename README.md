# 📜 Clarity Notary Service

A blockchain-based notary service built on Stacks that provides **immutable notarization** of agreements, statements, and documents. Perfect for creating tamper-proof records with cryptographic verification! 🔐

## ✨ Features

- 🏷️ **Document Notarization**: Notarize documents using SHA-256 hashes
- 🔍 **Instant Verification**: Verify document authenticity instantly
- 📊 **User Statistics**: Track notarization history and stats
- 💰 **Fee-based Service**: Configurable service fees in STX
- 🔒 **Immutable Records**: Permanent blockchain storage
- 👤 **User Management**: Personal document tracking

## 🚀 Quick Start

### Prerequisites
- Clarinet installed
- Stacks wallet with STX tokens

### Installation

```bash
git clone <your-repo>
cd notary-service
clarinet check
```

## 📖 Usage

### 🔖 Notarize a Document

```clarity
(contract-call? .notary-service notarize-document 
  0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
  "My Important Contract"
  "Legal agreement between parties A and B")
```

### 🔍 Verify a Document

```clarity
(contract-call? .notary-service verify-document 
  0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef)
```

### 📄 Get Document Details

```clarity
(contract-call? .notary-service get-document u1)
```

### 📊 Check Your Stats

```clarity
(contract-call? .notary-service get-user-document-count tx-sender)
(contract-call? .notary-service get-notary-stats tx-sender)
```

## 🛠️ Core Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `notarize-document` | 📝 Notarize a new document | `hash`, `title`, `metadata` |
| `verify-document` | ✅ Verify document authenticity | `hash` |
| `get-document` | 📋 Get document by ID | `document-id` |
| `get-document-by-hash` | 🔎 Get document by hash | `hash` |
| `get-user-document-count` | 📈 Get user's document count | `user` |
| `get-notary-stats` | 📊 Get notary statistics | `notary` |

## 💡 How It Works

1. **Hash Your Document** 🔐: Create a SHA-256 hash of your document
2. **Pay Fee** 💳: Service fee is automatically deducted in STX
3. **Blockchain Storage** ⛓️: Document hash and metadata stored immutably
4. **Instant Verification** ⚡: Anyone can verify document authenticity
5. **Permanent Record** 📚: Records exist forever on the blockchain

## 🔧 Configuration

### Service Fee
Default fee: `1 STX` (1,000,000 microSTX)

Only contract owner can update fees:
```clarity
(contract-call? .notary-service update-service-fee u2000000)
```

## 🏗️ Contract Architecture

- **Documents Map**: Stores all notarized documents
- **Hash-to-ID Map**: Quick hash lookups
- **User Documents**: Track user's documents
- **Statistics**: Notary performance metrics
- **Fee Management**: Automated fee collection

## 🔒 Security Features

- ✅ Duplicate hash prevention
- ✅ Input validation
- ✅ Owner-only administrative functions
- ✅ Secure fee handling
- ✅ Immutable timestamps

## 📈 Use Cases

- 📋 **Legal Contracts**: Notarize agreements and contracts
- 🎓 **Certificates**: Academic and professional credentials  
- 📊 **Business Documents**: Important corporate records
- 🏥 **Medical Records**: Patient consent forms
- 🏛️ **Government**: Official statements and declarations
- 💼 **Intellectual Property**: Timestamp creative works

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

MIT License - feel free to use in your projects!

---

**Built with ❤️ on Stacks blockchain** 🟠
```

**Git Commit Message:**
```
feat: implement blockchain notary service with document verification and user statistics
```

**GitHub Pull Request Title:**
```
🚀 Add Clarity-based Notary Service MVP with immutable document notarization
```

**GitHub Pull Request Description:**
```
## 📜 Notary Service MVP Implementation

This PR introduces a complete blockchain-based notary service built with Clarity smart contracts.

### ✨ What's Added

- **Core notarization functionality** - Users can notarize documents using SHA-256 hashes
- **Document verification system** - Instant verification of document authenticity  
- **User statistics tracking** - Personal notarization history and metrics
- **Fee-based service model** - Configurable STX fees with automated collection
- **Administrative controls** - Owner-only fee updates and fund withdrawal
- **Comprehensive data maps** - Efficient storage and retrieval of notarized documents

### 🔧 Technical Features

- 150+ lines of production-ready Clarity code
- Input validation and error handling
- Immutable blockchain storage
- Gas-optimized map structures
- Security-first design patterns

### 📚 Documentation

- Complete README with usage examples
- Function reference table
- Setup and installation guide
- Use case scenarios

Ready for immediate deployment and testing on Stacks testnet! 🚀
