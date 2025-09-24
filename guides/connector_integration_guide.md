# UCS Connector Integration: Comprehensive Step-by-Step Guide

This guide provides a complete, resumable process for integrating payment connectors into the UCS (Universal Connector Service) system. It supports all payment methods and flows, and can be used to continue partial implementations.

> **Important:** This guide is UCS-specific. The architecture differs significantly from traditional Hyperswitch implementations.

## 🏗️ UCS Architecture Overview

### Key Components
```rust
// Core UCS imports for all connectors
use domain_types::{
    connector_flow::{Authorize, Capture, Void, Refund, PSync, RSync},
    connector_types::{
        PaymentsAuthorizeData, PaymentsCaptureData, PaymentVoidData,
        RefundsData, PaymentsSyncData, RefundSyncData,
        PaymentsResponseData, RefundsResponseData, RequestDetails, ResponseId
    },
    router_data_v2::RouterDataV2,
    router_response_types::Response,
};
use interfaces::connector_integration_v2::ConnectorIntegrationV2;
```

### UCS-Specific Patterns
- **RouterDataV2**: Enhanced type-safe data handling
- **ConnectorIntegrationV2**: Modern trait-based integration
- **Domain Types**: Centralized domain modeling
- **gRPC-first**: All communication via Protocol Buffers
- **Stateless**: No database dependencies

## 🎯 Connector Implementation States

### State Assessment
Before starting, determine your current implementation state:

1. **Fresh Start**: No implementation exists
2. **Partial Core**: Basic auth and authorize flow implemented
3. **Core Complete**: All basic flows working (auth, capture, void, refund)
4. **Extended**: Advanced flows and multiple payment methods
5. **Near Complete**: Only specific flows or payment methods missing
6. **Debug/Fix**: Implementation exists but has issues

## 📋 Complete Flow Coverage

### Core Payment Flows (Priority 1)
- **Authorize**: Initial payment authorization[See Authorize Pattern Guide](patterns/pattern_authorize.md)
- **Capture**: Capture authorized amounts
- **Void**: Cancel authorized payments- [See Refund Pattern Guide](patterns/void.md)
- **Refund**: Process refunds (full/partial) - [See Refund Pattern Guide](patterns/pattern_refund.md)
- **PSync**: Payment status synchronization - - [See Refund Pattern Guide](patterns/Psync.md)
- **RSync**: Refund status synchronization - [See Refund Pattern Guide](patterns/pattern_refund.md)

### Advanced Flows (Priority 2)
- **CreateOrder**: Multi-step payment initiation
- **CreateSessionToken**: Secure session management
- **SetupMandate**: Recurring payment setup
- **DefendDispute**: Handle chargeback disputes
- **SubmitEvidence**: Submit dispute evidence

### Webhook Integration (Priority 3)
- **IncomingWebhook**: Real-time payment notifications
- **WebhookSourceVerification**: Signature validation
- **EventMapping**: Webhook event to status mapping

## 💳 Payment Method Support

### Card Payments
```rust
PaymentMethodData::Card(card_data) => {
    // Handle all card networks: Visa, Mastercard, Amex, Discover, etc.
    // Support 3DS authentication
    // Handle CVV verification
}
```

### Digital Wallets
```rust
PaymentMethodData::Wallet(wallet_data) => match wallet_data {
    WalletData::ApplePay(_) => // Apple Pay implementation
    WalletData::GooglePay(_) => // Google Pay implementation
    WalletData::PaypalRedirect(_) => // PayPal implementation
    // ... other wallets
}
```

### Bank Transfers
```rust
PaymentMethodData::BankTransfer(bank_data) => match bank_data {
    BankTransferData::AchBankTransfer => // ACH implementation
    BankTransferData::SepaBank => // SEPA implementation
    BankTransferData::Bacs => // BACS implementation
    // ... other bank transfer methods
}
```

### Buy Now Pay Later
```rust
PaymentMethodData::BuyNowPayLater(bnpl_data) => match bnpl_data {
    BuyNowPayLaterData::KlarnaRedirect => // Klarna implementation
    BuyNowPayLaterData::AffirmRedirect => // Affirm implementation
    BuyNowPayLaterData::AfterpayClearpayRedirect => // Afterpay implementation
    // ... other BNPL providers
}
```

## 🛠️ Implementation Process

### Phase 1: Preparation and Planning

#### Step 1.1: Analyze Current State
If resuming partial implementation:
```bash
# AI Command: "analyze current state of [ConnectorName] in UCS"
# The AI will examine existing code and identify:
# - Implemented flows
# - Supported payment methods  
# - Missing functionality
# - Code quality issues
```

#### Step 1.2: API Documentation Review (CRITICAL - IMPLEMENTATION BLOCKING)

**🚨 MANDATORY: THIS STEP BLOCKS ALL IMPLEMENTATION - CANNOT BE SKIPPED**

**ENFORCEMENT RULE**: No connector flow implementation can proceed without completing this mandatory API documentation review phase.

### **API Documentation Analysis Workflow** (REQUIRED FOR EVERY FLOW):

#### **Phase 1: Documentation Loading** (BLOCKING)
```bash
# ALWAYS start any flow implementation with this exact phrase:
"Let me first review the [ConnectorName] OpenAPI specification/API documentation for [FlowName] endpoints to ensure accurate implementation."

# Required actions:
1. Load OpenAPI specification (openapi.json/swagger.json) 
2. Locate official API documentation for the specific flow
3. Verify API version compatibility
4. Confirm documentation completeness for target flow
```

#### **Phase 2: Schema Extraction** (MANDATORY)
```bash
# For EACH flow being implemented, extract:
✅ EXACT request schema (required vs optional fields)
✅ EXACT response schema (actual fields returned, not examples)
✅ Error response formats and status codes
✅ Authentication requirements specific to this flow
✅ URL pattern and HTTP method requirements
✅ Any empty body requirements (common in refunds)
```

#### **Phase 3: Cross-Flow Validation** (CRITICAL)
```bash
# Compare this flow against other flows to identify:
⚠️ Response schema differences (Payment vs Refund vs Capture)
⚠️ Status value variations between flows
⚠️ URL pattern differences
⚠️ HTTP method differences
⚠️ Authentication differences
⚠️ Field presence/absence variations
```

#### Step 1.3: API Documentation Review (CRITICAL)

**⚠️ MANDATORY: Always review actual API documentation before implementing any flow**

Before implementing any connector flow, you MUST:

1. **Locate Official API Documentation**:
   - Find the connector's OpenAPI specification (openapi.json/swagger.json)
   - Download or access the most recent API documentation
   - Verify the API version you're implementing against

2. **Flow-Specific Schema Validation**:
   ```bash
   # For each flow you're implementing, verify:
   # - Request schema (required/optional fields)
   # - Response schema (actual fields returned)
   # - Error response formats
   # - Status codes and their meanings
   ```

3. **Critical Validation Points**:
   - **Request Body Requirements**: Some flows require empty bodies (common for full refunds)
   - **Response Field Differences**: Refund responses often differ from payment responses
   - **Status Value Mappings**: Actual status strings vs documentation examples
   - **URL Patterns**: Verify endpoint patterns for each flow type
   - **HTTP Methods**: Confirm GET/POST/PUT requirements per flow

4. **Common API Documentation Pitfalls**:
   - ❌ **Don't assume consistency**: Payment and refund APIs often have different schemas
   - ❌ **Don't copy-paste structures**: Each flow may have unique response fields
   - ❌ **Don't trust examples only**: Verify actual field requirements
   - ✅ **Do cross-reference**: Compare docs with actual API responses when possible
   - ✅ **Do check for flow-specific sections**: Many connectors have separate docs per flow

5. **Implementation Validation**:
   ```rust
   // Before coding, answer these questions:
   // 1. What fields are actually returned in the response?
   // 2. Are there flow-specific status values?
   // 3. Does this flow require a different base URL pattern?
   // 4. Are there flow-specific authentication requirements?
   ```

**Example from Worldpay Refund Implementation:**
```rust
// ❌ WRONG: Assumed refund response matches payment response
pub struct RefundResponse {
    pub outcome: String,
    pub transaction_reference: String, // This field doesn't exist in refund responses!
    pub issuer: Option<Issuer>,        // This field doesn't exist in refund responses!
    pub links: Links,
}

// ✅ CORRECT: Based on actual openapi.json specification review
pub struct RefundResponse {
    pub outcome: String,               // ✅ Only field actually returned
    pub links: Links,                  // ✅ Standard links object
    // No transaction_reference or issuer fields in refund responses
}

// ✅ CORRECT: Empty refund request body (from API docs)
pub struct RefundRequest {
    // Empty - serializes to {} for full refunds
}
```

**AI Implementation Note**: When implementing flows, always start with: "Let me first review the [ConnectorName] OpenAPI specification for the [FlowName] endpoints to ensure accurate implementation."

#### Step 1.4: Implementation Planning
```bash
# AI will create detailed plan based on:
# - Current implementation state
# - Missing functionality
# - Priority of remaining work
# Use: grace-ucs/connector_integration/template/planner_steps.md
```

### Phase 2: Core Implementation

#### Step 2.1: Connector Structure Setup
```rust
// File: backend/connector-integration/src/connectors/connector_name.rs

#[derive(Debug, Clone)]
pub struct ConnectorName;

impl ConnectorCommon for ConnectorName {
    fn id(&self) -> &'static str {
        "connector_name"
    }
    
    fn base_url<'a>(&self, connectors: &'a Connectors) -> &'a str {
        connectors.connector_name.base_url.as_ref()
    }
    
    fn get_currency_unit(&self) -> api::CurrencyUnit {
        api::CurrencyUnit::Minor // or Base, depending on connector
    }
    
    fn common_get_content_type(&self) -> &'static str {
        "application/json"
    }
    
    fn build_error_response(
        &self,
        res: Response,
        event_builder: Option<&mut ConnectorEvent>,
    ) -> CustomResult<ErrorResponse, errors::ConnectorError> {
        // UCS-specific error handling
    }
}
```

#### Step 2.2: Authentication Implementation
```rust
#[derive(Debug, Clone)]
pub struct ConnectorNameAuthType {
    pub api_key: SecretSerdeValue,
    // Add other auth fields as needed
}

impl TryFrom<&ConnectorAuthType> for ConnectorNameAuthType {
    type Error = Error;
    
    fn try_from(auth_type: &ConnectorAuthType) -> Result<Self, Self::Error> {
        // Implementation for auth type conversion
    }
}
```

### Phase 3: Flow Implementation

#### Step 3.1: Authorize Flow
```rust
impl ConnectorIntegrationV2<Authorize, PaymentsAuthorizeData, PaymentsResponseData>
    for ConnectorName
{
    fn get_headers(
        &self,
        req: &RouterDataV2<Authorize, PaymentsAuthorizeData, PaymentsResponseData>,
        connectors: &Connectors,
    ) -> CustomResult<Vec<(String, Maskable<String>)>, errors::ConnectorError> {
        // Implementation
    }
    
    fn get_content_type(&self) -> &'static str {
        self.common_get_content_type()
    }
    
    fn get_url(
        &self,
        req: &RouterDataV2<Authorize, PaymentsAuthorizeData, PaymentsResponseData>,
        connectors: &Connectors,
    ) -> CustomResult<String, errors::ConnectorError> {
        // Build connector-specific URL
    }
    
    fn get_request_body(
        &self,
        req: &RouterDataV2<Authorize, PaymentsAuthorizeData, PaymentsResponseData>,
        _connectors: &Connectors,
    ) -> CustomResult<RequestContent, errors::ConnectorError> {
        // Transform UCS data to connector format
        let connector_req = transformers::ConnectorNamePaymentsRequest::try_from(req)?;
        Ok(RequestContent::Json(Box::new(connector_req)))
    }
    
    fn build_request(
        &self,
        req: &RouterDataV2<Authorize, PaymentsAuthorizeData, PaymentsResponseData>,
        connectors: &Connectors,
    ) -> CustomResult<Option<RequestDetails>, errors::ConnectorError> {
        // Build complete HTTP request
    }
    
    fn handle_response(
        &self,
        data: &RouterDataV2<Authorize, PaymentsAuthorizeData, PaymentsResponseData>,
        event_builder: Option<&mut ConnectorEvent>,
        res: Response,
    ) -> CustomResult<RouterDataV2<Authorize, PaymentsAuthorizeData, PaymentsResponseData>, errors::ConnectorError> {
        // Handle connector response and transform back to UCS format
    }
    
    fn get_error_response(
        &self,
        res: Response,
        event_builder: Option<&mut ConnectorEvent>,
    ) -> CustomResult<ErrorResponse, errors::ConnectorError> {
        self.build_error_response(res, event_builder)
    }
}
```

#### Step 3.2: Payment Method Handling
```rust
// In transformers.rs
impl TryFrom<&RouterDataV2<Authorize, PaymentsAuthorizeData, PaymentsResponseData>>
    for ConnectorNamePaymentsRequest
{
    type Error = Error;
    
    fn try_from(
        item: &RouterDataV2<Authorize, PaymentsAuthorizeData, PaymentsResponseData>,
    ) -> Result<Self, Self::Error> {
        match item.request.payment_method_data.clone() {
            PaymentMethodData::Card(req_card) => {
                // Handle card payments
                Self::build_card_request(item, req_card)
            }
            PaymentMethodData::Wallet(wallet_data) => {
                // Handle wallet payments
                Self::build_wallet_request(item, wallet_data)
            }
            PaymentMethodData::BankTransfer(bank_data) => {
                // Handle bank transfers
                Self::build_bank_transfer_request(item, bank_data)
            }
            PaymentMethodData::BuyNowPayLater(bnpl_data) => {
                // Handle BNPL
                Self::build_bnpl_request(item, bnpl_data)
            }
            // Add all other payment method types
            _ => Err(errors::ConnectorError::NotImplemented(
                utils::get_unimplemented_payment_method_error_message("connector_name")
            ).into())
        }
    }
}
```

### Phase 4: Advanced Features

#### Step 4.1: Webhook Implementation
```rust
impl IncomingWebhook for ConnectorName {
    fn get_webhook_object_reference_id(
        &self,
        request: &IncomingWebhookRequestDetails<'_>,
    ) -> CustomResult<ObjectReferenceId, errors::ConnectorError> {
        // Extract payment/refund ID from webhook
    }
    
    fn get_webhook_event_type(
        &self,
        request: &IncomingWebhookRequestDetails<'_>,
    ) -> CustomResult<IncomingWebhookEvent, errors::ConnectorError> {
        // Map connector webhook events to UCS events
    }
    
    fn get_webhook_resource_object(
        &self,
        request: &IncomingWebhookRequestDetails<'_>,
    ) -> CustomResult<Box<dyn masking::ErasedMaskSerialize>, errors::ConnectorError> {
        // Parse webhook payload
    }
    
    fn get_dispute_details(
        &self,
        request: &IncomingWebhookRequestDetails<'_>,
    ) -> CustomResult<DisputePayload, errors::ConnectorError> {
        // Handle dispute webhooks if supported
    }
}
```

## 🧪 Testing Strategy

### Unit Tests
```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_payment_authorize_success() {
        // Test successful authorization for all payment methods
    }
    
    #[test]
    fn test_payment_authorize_failure() {
        // Test failure scenarios
    }
    
    // Add tests for all flows and payment methods
}
```

### Integration Tests
```rust
// File: backend/grpc-server/tests/connector_name_test.rs
// Comprehensive gRPC integration tests
```

### Refund Flow Testing Guidelines

#### Essential Refund Test Cases
```rust
#[cfg(test)]
mod refund_flow_tests {
    use super::*;

    #[test]
    fn test_refund_request_empty_body_serialization() {
        // Test that empty refund requests serialize to {} correctly
        let refund_request = RefundRequest {};
        let serialized = serde_json::to_string(&refund_request).unwrap();
        assert_eq!(serialized, "{}");
    }

    #[test]
    fn test_refund_response_without_transaction_reference() {
        // Critical: Test that response doesn't expect non-existent fields
        let json_response = r#"{"outcome":"sentForRefund","_links":{"self":{"href":"https://api.connector.com/payments/123"}}}"#;
        let response: RefundResponse = serde_json::from_str(json_response).unwrap();
        assert_eq!(response.outcome, "sentForRefund");
    }

    #[test]
    fn test_refund_status_mapping_comprehensive() {
        // Test all possible refund status mappings
        assert_eq!(map_refund_status("sentForRefund"), RefundStatus::Pending);
        assert_eq!(map_refund_status("refunded"), RefundStatus::Success);
        assert_eq!(map_refund_status("refused"), RefundStatus::Failure);
        assert_eq!(map_refund_status("failed"), RefundStatus::Failure);
        assert_eq!(map_refund_status("unknown_status"), RefundStatus::Pending);
    }

    #[test]
    fn test_refund_url_construction() {
        // Test URL building for refunds follows correct pattern
        let router_data = create_test_refund_router_data();
        let url = connector.get_refund_url(&router_data).unwrap();
        assert!(url.contains("/payments/"));
        assert!(url.ends_with("/refunds"));
    }

    #[test]
    fn test_rsync_url_construction() {
        // Test RSync URL building
        let router_data = create_test_rsync_router_data();
        let url = connector.get_rsync_url(&router_data).unwrap();
        assert!(url.contains("/refunds/"));
    }

    #[test]
    fn test_connector_transaction_id_extraction() {
        // Test ID extraction from various response formats
        let response_with_href = RefundResponse {
            outcome: "sentForRefund".to_string(),
            links: Links {
                self_link: Href { href: "https://api.com/payments/txn_123".to_string() }
            }
        };
        let extracted_id = extract_transaction_id(&response_with_href.links.self_link.href);
        assert_eq!(extracted_id, Some("txn_123".to_string()));
    }
}

// Integration test with real API flow
#[tokio::test]
async fn test_full_refund_integration() {
    // 1. Create successful payment first
    let payment_result = create_test_payment().await.expect("Payment should succeed");
    
    // 2. Process full refund
    let refund_request = RefundRequest {
        connector_transaction_id: payment_result.transaction_id,
        minor_refund_amount: payment_result.amount,
        currency: payment_result.currency,
    };
    
    let refund_result = process_refund(refund_request).await.expect("Refund should succeed");
    assert_eq!(refund_result.refund_status, RefundStatus::Pending);
    
    // 3. Check refund status via RSync
    let sync_result = sync_refund_status(&refund_result.connector_refund_id).await;
    assert!(sync_result.is_ok());
}
```

#### Refund Testing Checklist
- [ ] **Empty Body Handling**: Verify empty request bodies serialize correctly
- [ ] **Response Schema Validation**: Test against actual API responses, not assumptions
- [ ] **Status Mapping Coverage**: Test all possible refund status values
- [ ] **URL Pattern Verification**: Confirm correct endpoint construction
- [ ] **ID Extraction**: Test transaction ID extraction from various response formats
- [ ] **Error Scenario Testing**: Test refund-specific error conditions
- [ ] **Integration Flow**: Test complete refund flow with real API
- [ ] **RSync Functionality**: Verify refund status checking works
- [ ] **Partial vs Full Refunds**: Test both scenarios if supported
- [ ] **Amount Validation**: Test refund amount limits and validation

#### Common Refund Testing Pitfalls
1. **Assuming Response Consistency**: Don't test based on payment response structure
2. **Missing Empty Body Tests**: Many connectors require empty bodies for full refunds
3. **Incomplete Status Coverage**: Test unknown/unexpected status values
4. **URL Pattern Assumptions**: Verify actual endpoint patterns with connector docs
5. **ID Extraction Edge Cases**: Test different response formats for transaction IDs

## 🔄 Resuming Partial Implementation

### Common Resume Scenarios

#### "I have authorize working, need to add capture"
```bash
# AI Command: "add capture flow to existing [ConnectorName] connector in UCS"
# AI will:
# 1. Analyze existing authorize implementation
# 2. Create capture flow following same patterns
# 3. Ensure consistency with existing code style
```

#### "Need to add wallet support"
```bash
# AI Command: "add [WalletType] support to [ConnectorName] connector in UCS"
# AI will:
# 1. Analyze existing payment method handling
# 2. Add wallet-specific transformations
# 3. Update request/response structures
```

#### "Webhook implementation missing"
```bash
# AI Command: "implement webhook handling for [ConnectorName] connector in UCS"
# AI will:
# 1. Create webhook trait implementation
# 2. Add signature verification
# 3. Map webhook events to UCS events
```

## 🚨 Common UCS Pitfalls

### 1. RouterData vs RouterDataV2
```rust
// WRONG (traditional Hyperswitch)
RouterData<Flow, Request, Response>

// CORRECT (UCS)
RouterDataV2<Flow, Request, Response>
```

### 2. Trait Implementation
```rust
// WRONG (traditional)
ConnectorIntegration<Flow, Request, Response>

// CORRECT (UCS)
ConnectorIntegrationV2<Flow, Request, Response>
```

### 3. Error Handling
```rust
// UCS uses domain_types errors, not hyperswitch_domain_models
use domain_types::errors;
```

### 4. Import Paths
```rust
// UCS-specific imports
use domain_types::*;
use interfaces::connector_integration_v2::*;
// NOT hyperswitch_interfaces or hyperswitch_domain_models
```

## 📊 Implementation Checklist

### Core Implementation ✅
- [ ] Connector structure and auth
- [ ] Authorize flow
- [ ] Capture flow  
- [ ] Void flow
- [ ] Refund flow
- [ ] Payment sync
- [ ] Refund sync
- [ ] Error handling

### Payment Methods ✅
- [ ] Card payments (all networks)
- [ ] Digital wallets
- [ ] Bank transfers
- [ ] Buy Now Pay Later
- [ ] Crypto payments
- [ ] Regional methods
- [ ] Cash/voucher methods

### Advanced Features ✅
- [ ] Webhook implementation
- [ ] 3DS authentication
- [ ] Recurring/mandate setup
- [ ] Dispute handling
- [ ] Multi-currency support
- [ ] Partial capture/refund

### Quality & Testing ✅
- [ ] Unit tests for all flows
- [ ] Integration tests
- [ ] Error scenario testing
- [ ] Performance testing
- [ ] Documentation updates
- [ ] Code review ready

## 🎯 Success Metrics

A complete UCS connector implementation should:
1. **Support all relevant payment methods** for the connector
2. **Handle all core flows** (auth, capture, void, refund, sync)
3. **Process webhooks** if supported by connector
4. **Have comprehensive test coverage** (>90%)
5. **Follow UCS patterns** consistently
6. **Handle errors gracefully** with proper mapping
7. **Be production-ready** with proper logging and metrics

## 🔄 Continuous Integration

The UCS connector can be continuously improved:
- **Add new payment methods** as connector supports them
- **Implement new flows** as they become available
- **Optimize performance** based on usage patterns
- **Enhance error handling** based on production data
- **Update for API changes** as connector evolves

Remember: GRACE-UCS makes connector development resumable at any stage. You can always continue where you left off!
