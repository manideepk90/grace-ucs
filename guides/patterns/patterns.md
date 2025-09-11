# UCS Connector Implementation Patterns

This document contains proven patterns and solutions for UCS connector development, covering all payment methods and flows.

## 🏗️ Core Architecture Patterns

### 1. UCS Connector Structure Pattern
```rust
// Standard UCS connector file organization
// File: backend/connector-integration/src/connectors/connector_name.rs

use domain_types::{
    connector_flow::*,
    connector_types::*,
    router_data_v2::RouterDataV2,
};
use interfaces::connector_integration_v2::ConnectorIntegrationV2;

#[derive(Debug, Clone)]
pub struct ConnectorName;

// Always implement ConnectorCommon first
impl ConnectorCommon for ConnectorName {
    fn id(&self) -> &'static str { "connector_name" }
    fn base_url<'a>(&self, connectors: &'a Connectors) -> &'a str {
        connectors.connector_name.base_url.as_ref()
    }
    fn get_currency_unit(&self) -> api::CurrencyUnit { 
        api::CurrencyUnit::Minor // or Base based on connector API
    }
    fn common_get_content_type(&self) -> &'static str { 
        "application/json" // or "application/x-www-form-urlencoded"
    }
}

// Implement each flow separately for better organization
impl ConnectorIntegrationV2<Authorize, PaymentsAuthorizeData, PaymentsResponseData>
    for ConnectorName { /* implementation */ }

impl ConnectorIntegrationV2<Capture, PaymentsCaptureData, PaymentsResponseData>
    for ConnectorName { /* implementation */ }

// Continue for all required flows...
```

### 2. RouterDataV2 Pattern
```rust
// UCS uses RouterDataV2 for enhanced type safety
type AuthorizeRouterData = RouterDataV2<Authorize, PaymentsAuthorizeData, PaymentsResponseData>;
type CaptureRouterData = RouterDataV2<Capture, PaymentsCaptureData, PaymentsResponseData>;
type VoidRouterData = RouterDataV2<Void, PaymentVoidData, PaymentsResponseData>;
type RefundRouterData = RouterDataV2<Refund, RefundsData, RefundsResponseData>;
type SyncRouterData = RouterDataV2<PSync, PaymentsSyncData, PaymentsResponseData>;

// Use these type aliases consistently throughout your connector
```

## 💳 Payment Method Patterns

### 1. Comprehensive Payment Method Handling
```rust
// In transformers.rs - Handle ALL payment methods
impl TryFrom<&AuthorizeRouterData> for ConnectorPaymentRequest {
    type Error = Error;
    
    fn try_from(item: &AuthorizeRouterData) -> Result<Self, Self::Error> {
        let amount = item.request.amount;
        let currency = item.request.currency;
        
        match item.request.payment_method_data.clone() {
            // Card Payments - Most common
            PaymentMethodData::Card(card) => {
                Self::build_card_payment(item, card, amount, currency)
            }
            
            // Digital Wallets
            PaymentMethodData::Wallet(wallet_data) => match wallet_data {
                WalletData::ApplePay(apple_pay) => 
                    Self::build_apple_pay(item, apple_pay, amount, currency),
                WalletData::GooglePay(google_pay) => 
                    Self::build_google_pay(item, google_pay, amount, currency),
                WalletData::PaypalRedirect(paypal) => 
                    Self::build_paypal(item, paypal, amount, currency),
                WalletData::SamsungPay(samsung) => 
                    Self::build_samsung_pay(item, samsung, amount, currency),
                WalletData::WeChatPayRedirect(wechat) => 
                    Self::build_wechat_pay(item, wechat, amount, currency),
                WalletData::AliPayRedirect(alipay) => 
                    Self::build_alipay(item, alipay, amount, currency),
                // Add all wallet types your connector supports
                _ => Err(errors::ConnectorError::NotSupported {
                    message: format!("Wallet type not supported: {:?}", wallet_data),
                    connector: "connector_name"
                }.into())
            },
            
            // Bank Transfers
            PaymentMethodData::BankTransfer(bank_data) => match bank_data {
                BankTransferData::AchBankTransfer => 
                    Self::build_ach_transfer(item, amount, currency),
                BankTransferData::SepaBankTransfer => 
                    Self::build_sepa_transfer(item, amount, currency),
                BankTransferData::BacsBankTransfer => 
                    Self::build_bacs_transfer(item, amount, currency),
                BankTransferData::MultibancoBankTransfer => 
                    Self::build_multibanco(item, amount, currency),
                // Add all bank transfer types
                _ => Err(errors::ConnectorError::NotSupported {
                    message: format!("Bank transfer type not supported: {:?}", bank_data),
                    connector: "connector_name"
                }.into())
            },
            
            // Buy Now Pay Later
            PaymentMethodData::BuyNowPayLater(bnpl_data) => match bnpl_data {
                BuyNowPayLaterData::KlarnaRedirect => 
                    Self::build_klarna(item, amount, currency),
                BuyNowPayLaterData::AffirmRedirect => 
                    Self::build_affirm(item, amount, currency),
                BuyNowPayLaterData::AfterpayClearpayRedirect => 
                    Self::build_afterpay(item, amount, currency),
                BuyNowPayLaterData::AlmaRedirect => 
                    Self::build_alma(item, amount, currency),
                // Add all BNPL providers
                _ => Err(errors::ConnectorError::NotSupported {
                    message: format!("BNPL type not supported: {:?}", bnpl_data),
                    connector: "connector_name"
                }.into())
            },
            
            // Cash and Voucher Payments
            PaymentMethodData::Voucher(voucher_data) => match voucher_data {
                VoucherData::BoletoRedirect => 
                    Self::build_boleto(item, amount, currency),
                VoucherData::OxxoRedirect => 
                    Self::build_oxxo(item, amount, currency),
                VoucherData::SevenElevenRedirect => 
                    Self::build_seven_eleven(item, amount, currency),
                // Add voucher types
                _ => Err(errors::ConnectorError::NotSupported {
                    message: format!("Voucher type not supported: {:?}", voucher_data),
                    connector: "connector_name"
                }.into())
            },
            
            // Cryptocurrency
            PaymentMethodData::Crypto(crypto_data) => {
                Self::build_crypto_payment(item, crypto_data, amount, currency)
            },
            
            // Gift Cards
            PaymentMethodData::GiftCard(gift_card_data) => {
                Self::build_gift_card_payment(item, gift_card_data, amount, currency)
            },
            
            // Catch unimplemented payment methods
            _ => Err(errors::ConnectorError::NotImplemented(
                utils::get_unimplemented_payment_method_error_message("connector_name")
            ).into())
        }
    }
}
```

### 2. Card Payment Pattern
```rust
impl ConnectorPaymentRequest {
    fn build_card_payment(
        item: &AuthorizeRouterData,
        card: Card,
        amount: MinorUnit,
        currency: Currency,
    ) -> Result<Self, Error> {
        // Handle all card networks
        let card_network = card.card_network.unwrap_or(CardNetwork::Visa);
        
        // 3DS handling
        let three_ds_info = item.request.browser_info.as_ref().map(|browser| {
            ConnectorThreeDSInfo {
                browser_info: ConnectorBrowserInfo {
                    user_agent: browser.user_agent.clone(),
                    accept_header: browser.accept_header.clone(),
                    language: browser.language.clone(),
                    color_depth: browser.color_depth,
                    screen_height: browser.screen_height,
                    screen_width: browser.screen_width,
                    time_zone: browser.time_zone,
                    java_enabled: browser.java_enabled,
                    java_script_enabled: browser.java_script_enabled,
                },
                challenge_window_size: None, // Set based on connector requirements
            }
        });
        
        Ok(Self {
            amount: utils::to_currency_base_unit(amount, currency)?,
            currency: currency.to_string(),
            payment_method: ConnectorPaymentMethod::Card {
                number: card.card_number,
                expiry_month: card.card_exp_month,
                expiry_year: card.card_exp_year,
                cvc: card.card_cvc,
                cardholder_name: card.card_holder_name,
                card_network: Some(card_network),
            },
            customer: Self::build_customer_info(item)?,
            billing_address: Self::build_billing_address(item)?,
            shipping_address: Self::build_shipping_address(item)?,
            three_ds_info,
            metadata: Self::build_metadata(item)?,
        })
    }
}
```

## 🔄 Flow Implementation Patterns

### 1. Standard Flow Implementation Pattern - INDEPENDENT FLOWS
```rust
// Template for implementing any flow in UCS
// CRITICAL: Each flow is completely independent - no dependencies on other flows
// You can implement ANY flow without implementing others
impl ConnectorIntegrationV2<FlowType, RequestType, ResponseType> for ConnectorName {
    fn get_headers(
        &self,
        req: &RouterDataV2<FlowType, RequestType, ResponseType>,
        connectors: &Connectors,
    ) -> CustomResult<Vec<(String, Maskable<String>)>, errors::ConnectorError> {
        let auth = ConnectorAuthType::try_from(&req.connector_auth_type)?;
        
        let mut headers = vec![
            ("Content-Type".to_string(), self.get_content_type().to_string().into()),
        ];
        
        // Add authentication headers
        match auth {
            ConnectorAuthType::ApiKey { api_key } => {
                headers.push(("Authorization".to_string(), 
                    format!("Bearer {}", api_key.expose()).into_masked()));
            }
            ConnectorAuthType::BasicAuth { username, password } => {
                let auth_string = format!("{}:{}", username.expose(), password.expose());
                let encoded = base64::engine::general_purpose::STANDARD.encode(auth_string);
                headers.push(("Authorization".to_string(), 
                    format!("Basic {}", encoded).into_masked()));
            }
            // Handle other auth types
        }
        
        // Add connector-specific headers
        headers.extend(self.get_connector_specific_headers(req)?);
        
        Ok(headers)
    }
    
    fn get_content_type(&self) -> &'static str {
        self.common_get_content_type()
    }
    
    fn get_url(
        &self,
        req: &RouterDataV2<FlowType, RequestType, ResponseType>,
        connectors: &Connectors,
    ) -> CustomResult<String, errors::ConnectorError> {
        let base_url = self.base_url(connectors);
        
        // Build flow-specific URL
        match FlowType::default() {
            Authorize => Ok(format!("{}/payments", base_url)),
            Capture => {
                let payment_id = req.request.connector_transaction_id
                    .as_ref()
                    .ok_or(errors::ConnectorError::MissingConnectorTransactionID)?;
                Ok(format!("{}/payments/{}/capture", base_url, payment_id))
            }
            Void => {
                let payment_id = req.request.connector_transaction_id
                    .as_ref()
                    .ok_or(errors::ConnectorError::MissingConnectorTransactionID)?;
                Ok(format!("{}/payments/{}/void", base_url, payment_id))
            }
            Refund => Ok(format!("{}/refunds", base_url)),
            PSync => {
                let payment_id = req.request.connector_transaction_id
                    .as_ref()
                    .ok_or(errors::ConnectorError::MissingConnectorTransactionID)?;
                Ok(format!("{}/payments/{}", base_url, payment_id))
            }
            // Add other flows
        }
    }
    
    fn get_request_body(
        &self,
        req: &RouterDataV2<FlowType, RequestType, ResponseType>,
        _connectors: &Connectors,
    ) -> CustomResult<RequestContent, errors::ConnectorError> {
        let connector_req = ConnectorRequest::try_from(req)?;
        Ok(RequestContent::Json(Box::new(connector_req)))
    }
    
    fn build_request(
        &self,
        req: &RouterDataV2<FlowType, RequestType, ResponseType>,
        connectors: &Connectors,
    ) -> CustomResult<Option<RequestDetails>, errors::ConnectorError> {
        Ok(Some(
            RequestBuilder::new()
                .method(self.get_http_method())
                .url(&self.get_url(req, connectors)?)
                .attach_default_headers()
                .headers(self.get_headers(req, connectors)?)
                .set_body(self.get_request_body(req, connectors)?)
                .build(),
        ))
    }
    
    fn handle_response(
        &self,
        data: &RouterDataV2<FlowType, RequestType, ResponseType>,
        event_builder: Option<&mut ConnectorEvent>,
        res: Response,
    ) -> CustomResult<RouterDataV2<FlowType, RequestType, ResponseType>, errors::ConnectorError> {
        let response: ConnectorResponse = res
            .response
            .parse_struct("ConnectorResponse")
            .change_context(errors::ConnectorError::ResponseDeserializationFailed)?;
        
        event_builder.map(|i| i.set_response_body(&response));
        
        RouterDataV2::try_from(ResponseRouterData {
            response,
            data: data.clone(),
            http_code: res.status_code,
        })
        .change_context(errors::ConnectorError::ResponseHandlingFailed)
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

## 🎣 Webhook Implementation Patterns

### 1. Complete Webhook Handler Pattern
```rust
impl IncomingWebhook for ConnectorName {
    fn get_webhook_object_reference_id(
        &self,
        request: &IncomingWebhookRequestDetails<'_>,
    ) -> CustomResult<ObjectReferenceId, errors::ConnectorError> {
        let webhook: ConnectorWebhook = request
            .body
            .parse_struct("ConnectorWebhook")
            .change_context(errors::ConnectorError::WebhookBodyDecodingFailed)?;
        
        match webhook.object_type.as_str() {
            "payment" => {
                let payment_id = PaymentId::try_from(webhook.object_id)?;
                Ok(ObjectReferenceId::PaymentId(PaymentIdType::PaymentIntentId(payment_id)))
            }
            "refund" => {
                let refund_id = RefundId::try_from(webhook.object_id)?;
                Ok(ObjectReferenceId::RefundId(RefundIdType::RefundId(refund_id)))
            }
            _ => Err(errors::ConnectorError::WebhookEventTypeNotFound.into())
        }
    }
    
    fn get_webhook_event_type(
        &self,
        request: &IncomingWebhookRequestDetails<'_>,
    ) -> CustomResult<IncomingWebhookEvent, errors::ConnectorError> {
        let webhook: ConnectorWebhook = request
            .body
            .parse_struct("ConnectorWebhook")
            .change_context(errors::ConnectorError::WebhookBodyDecodingFailed)?;
        
        match (webhook.event_type.as_str(), webhook.object_type.as_str()) {
            ("payment.authorized", "payment") => Ok(IncomingWebhookEvent::PaymentIntentAuthorizationSuccess),
            ("payment.captured", "payment") => Ok(IncomingWebhookEvent::PaymentIntentSuccess),
            ("payment.failed", "payment") => Ok(IncomingWebhookEvent::PaymentIntentFailure),
            ("payment.cancelled", "payment") => Ok(IncomingWebhookEvent::PaymentIntentCancelled),
            ("refund.succeeded", "refund") => Ok(IncomingWebhookEvent::RefundSuccess),
            ("refund.failed", "refund") => Ok(IncomingWebhookEvent::RefundFailure),
            // Add all webhook event mappings
            _ => Ok(IncomingWebhookEvent::EventNotSupported),
        }
    }
    
    fn get_webhook_resource_object(
        &self,
        request: &IncomingWebhookRequestDetails<'_>,
    ) -> CustomResult<Box<dyn masking::ErasedMaskSerialize>, errors::ConnectorError> {
        let webhook: ConnectorWebhook = request
            .body
            .parse_struct("ConnectorWebhook")
            .change_context(errors::ConnectorError::WebhookBodyDecodingFailed)?;
        
        Ok(Box::new(webhook))
    }
}
```

## 🛡️ Error Handling Patterns

### 1. Comprehensive Error Response Pattern
```rust
impl ConnectorCommon for ConnectorName {
    fn build_error_response(
        &self,
        res: Response,
        event_builder: Option<&mut ConnectorEvent>,
    ) -> CustomResult<ErrorResponse, errors::ConnectorError> {
        let response: ConnectorErrorResponse = res
            .response
            .parse_struct("ConnectorErrorResponse")
            .change_context(errors::ConnectorError::ResponseDeserializationFailed)?;
        
        event_builder.map(|i| i.set_error_response_body(&response));
        
        // Map connector-specific errors to UCS errors
        let (code, message, reason, attempt_status) = match response.error_code.as_str() {
            "insufficient_funds" => (
                "insufficient_funds".to_string(),
                "Insufficient funds in account".to_string(),
                Some("Card has insufficient funds".to_string()),
                Some(AttemptStatus::Failure),
            ),
            "invalid_card" => (
                "invalid_card_details".to_string(),
                "Invalid card details provided".to_string(),
                Some("Card number, expiry, or CVV is invalid".to_string()),
                Some(AttemptStatus::Failure),
            ),
            "card_declined" => (
                "card_declined".to_string(),
                "Card was declined by issuer".to_string(),
                Some("Issuer declined the transaction".to_string()),
                Some(AttemptStatus::Failure),
            ),
            "authentication_required" => (
                "authentication_required".to_string(),
                "3DS authentication required".to_string(),
                Some("Strong customer authentication needed".to_string()),
                Some(AttemptStatus::AuthenticationPending),
            ),
            // Add all connector-specific error mappings
            _ => (
                response.error_code.clone(),
                response.error_message.clone(),
                Some(response.error_description.unwrap_or_default()),
                Some(AttemptStatus::Failure),
            ),
        };
        
        Ok(ErrorResponse {
            status_code: res.status_code,
            code,
            message,
            reason,
            attempt_status,
            connector_transaction_id: response.transaction_id,
            network_decline_code: response.decline_code,
            network_advice_code: response.advice_code,
            network_error_message: response.network_message,
        })
    }
}
```

## 🔧 Utility Patterns

### 1. Amount Conversion Pattern
```rust
impl ConnectorName {
    fn convert_amount(
        amount: MinorUnit,
        currency: Currency,
        target_unit: api::CurrencyUnit,
    ) -> Result<String, Error> {
        match target_unit {
            api::CurrencyUnit::Base => {
                // Convert minor units to major units (e.g., cents to dollars)
                utils::to_currency_base_unit(amount, currency)
                    .map(|amt| amt.to_string())
            }
            api::CurrencyUnit::Minor => {
                // Keep as minor units
                Ok(amount.to_string())
            }
        }
    }
    
    fn get_currency_unit_for_connector() -> api::CurrencyUnit {
        // Return based on what the connector API expects
        api::CurrencyUnit::Base // or Minor
    }
}
```

### 2. Address Handling Pattern
```rust
impl ConnectorPaymentRequest {
    fn build_billing_address(item: &AuthorizeRouterData) -> Result<Option<ConnectorAddress>, Error> {
        item.address.billing.as_ref().map(|billing| {
            Ok(ConnectorAddress {
                street: billing.line1.clone(),
                street2: billing.line2.clone(),
                city: billing.city.clone(),
                state: billing.state.clone(),
                postal_code: billing.zip.clone(),
                country: billing.country.clone(),
            })
        }).transpose()
    }
    
    fn build_shipping_address(item: &AuthorizeRouterData) -> Result<Option<ConnectorAddress>, Error> {
        item.address.shipping.as_ref().map(|shipping| {
            Ok(ConnectorAddress {
                street: shipping.line1.clone(),
                street2: shipping.line2.clone(),
                city: shipping.city.clone(),
                state: shipping.state.clone(),
                postal_code: shipping.zip.clone(),
                country: shipping.country.clone(),
            })
        }).transpose()
    }
}
```

## 🧪 Testing Patterns

### 1. Comprehensive Test Pattern
```rust
#[cfg(test)]
mod tests {
    use super::*;
    use domain_types::connector_types::PaymentTest;
    
    // Test each payment method
    #[test]
    fn test_card_payment_authorize() {
        let router_data = PaymentTest::card_authorize_router_data();
        let request = ConnectorPaymentRequest::try_from(&router_data).unwrap();
        
        assert!(matches!(request.payment_method, ConnectorPaymentMethod::Card { .. }));
        assert_eq!(request.amount, "10.00");
        assert_eq!(request.currency, "USD");
    }
    
    #[test]
    fn test_apple_pay_authorize() {
        let router_data = PaymentTest::apple_pay_authorize_router_data();
        let request = ConnectorPaymentRequest::try_from(&router_data).unwrap();
        
        assert!(matches!(request.payment_method, ConnectorPaymentMethod::ApplePay { .. }));
    }
    
    #[test]
    fn test_bank_transfer_authorize() {
        let router_data = PaymentTest::ach_bank_transfer_router_data();
        let request = ConnectorPaymentRequest::try_from(&router_data).unwrap();
        
        assert!(matches!(request.payment_method, ConnectorPaymentMethod::BankTransfer { .. }));
    }
    
    // Test all flows
    #[test]
    fn test_capture_request() {
        let router_data = PaymentTest::capture_router_data();
        let request = ConnectorCaptureRequest::try_from(&router_data).unwrap();
        
        assert!(request.amount.is_some());
        assert!(request.transaction_id.is_some());
    }
    
    // Test error scenarios
    #[test]
    fn test_unsupported_payment_method() {
        let router_data = PaymentTest::unsupported_payment_method_router_data();
        let result = ConnectorPaymentRequest::try_from(&router_data);
        
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), errors::ConnectorError::NotSupported { .. }));
    }
}
```

## 📊 Key Success Patterns

1. **Flow Independence**: Each flow implemented completely independently with no cross-dependencies
2. **Complete Payment Method Coverage**: Handle all payment methods your connector supports
3. **Consistent Error Handling**: Map all connector errors to appropriate UCS errors
4. **Proper Type Usage**: Use RouterDataV2 and ConnectorIntegrationV2 consistently
5. **Code Validation**: Ensure code compiles and follows UCS patterns correctly
6. **Webhook Implementation**: Handle all webhook events properly
7. **Performance Optimization**: Efficient request/response handling
8. **Documentation**: Clear documentation for all implemented features

## 🔄 Flow Independence Principles

### Critical Independence Rules:
1. **No Shared State**: Each flow maintains its own state and context
2. **No Cross-Flow Dependencies**: Authorize doesn't depend on Capture, Refund doesn't depend on Authorize
3. **Independent Implementation**: Can implement Capture without implementing Authorize
4. **Independent Validation**: Each flow can be validated and compiled independently
5. **Independent Deployment**: Each flow can be enabled/disabled independently

### Examples of Proper Independence:

#### ✅ CORRECT - Independent Flows:
```rust
// Authorize flow - completely independent
impl ConnectorIntegrationV2<Authorize, PaymentsAuthorizeData<T>, PaymentsResponseData>
    for ConnectorName<T>
{
    // No dependencies on other flows
    // Self-contained implementation
}

// Capture flow - completely independent  
impl ConnectorIntegrationV2<Capture, PaymentsCaptureData, PaymentsResponseData>
    for ConnectorName<T>
{
    // No dependencies on Authorize flow
    // Can work even if Authorize is not implemented
    // Uses connector_transaction_id from request, not shared state
}

// Refund flow - completely independent
impl ConnectorIntegrationV2<Refund, RefundsData, RefundsResponseData>
    for ConnectorName<T>
{
    // No dependencies on payment flows
    // Self-contained refund logic
}
```

#### ❌ INCORRECT - Flow Dependencies:
```rust
// DON'T DO THIS - flows should not depend on each other
impl ConnectorIntegrationV2<Capture, PaymentsCaptureData, PaymentsResponseData>
    for ConnectorName<T>
{
    fn get_request_body(&self, req: &CaptureRouterData) -> Result<RequestContent, Error> {
        // WRONG: Don't access authorize flow data or shared state
        // WRONG: Don't assume authorize was called first
        // Each flow should be self-contained
    }
}
```

### Flow Implementation Order:
Since flows are independent, you can implement them in ANY order:
- ✅ Start with Refund flow (without implementing Authorize)
- ✅ Implement only Capture flow for partial captures
- ✅ Add Authorize flow later
- ✅ Implement Sync flows independently
- ✅ Add Webhook handling without other flows

## 🔧 Code Reuse Patterns - AVOID DUPLICATION

### Principle: Independent Flows + Shared Utilities

Flows should be independent but MUST reuse common code to avoid duplication.

#### ✅ CORRECT - Shared Common Code:

```rust
impl<T: PaymentMethodDataTypes + Debug + Sync + Send + 'static + Serialize> ConnectorCommon
    for ConnectorName<T>
{
    // SHARED: All flows use these common methods
    fn get_auth_header(
        &self,
        auth_type: &ConnectorAuthType,
    ) -> CustomResult<Vec<(String, Maskable<String>)>, errors::ConnectorError> {
        // Common authentication logic used by ALL flows
        let auth = ConnectorAuthType::try_from(auth_type)?;
        Ok(vec![(
            headers::AUTHORIZATION.to_string(),
            format!("Bearer {}", auth.api_key.expose()).into(),
        )])
    }
    
    fn get_currency_unit(&self) -> CurrencyUnit {
        // Common currency handling used by ALL flows
        CurrencyUnit::Minor
    }
    
    fn common_get_content_type(&self) -> &'static str {
        // Common content type used by ALL flows
        "application/json"
    }
    
    fn build_error_response(
        &self,
        res: Response,
        event_builder: Option<&mut ConnectorEvent>,
    ) -> CustomResult<ErrorResponse, errors::ConnectorError> {
        // Common error handling used by ALL flows
        // Implementation here...
    }
}

// Each flow reuses the common methods without duplication
impl ConnectorIntegrationV2<Authorize, PaymentsAuthorizeData<T>, PaymentsResponseData>
    for ConnectorName<T>
{
    fn get_headers(
        &self,
        req: &RouterDataV2<Authorize, PaymentsAuthorizeData<T>, PaymentsResponseData>,
        connectors: &Connectors,
    ) -> CustomResult<Vec<(String, Maskable<String>)>, errors::ConnectorError> {
        // REUSE: Use common auth header method
        let mut headers = vec![(
            headers::CONTENT_TYPE.to_string(),
            self.common_get_content_type().to_string().into(),
        )];
        let mut auth_headers = self.get_auth_header(&req.connector_auth_type)?;
        headers.append(&mut auth_headers);
        Ok(headers)
    }
    
    fn get_content_type(&self) -> &'static str {
        // REUSE: Use common content type
        self.common_get_content_type()
    }
    
    fn get_error_response(
        &self,
        res: Response,
        event_builder: Option<&mut ConnectorEvent>,
    ) -> CustomResult<ErrorResponse, errors::ConnectorError> {
        // REUSE: Use common error handling
        self.build_error_response(res, event_builder)
    }
}

impl ConnectorIntegrationV2<Capture, PaymentsCaptureData, PaymentsResponseData>
    for ConnectorName<T>
{
    fn get_headers(
        &self,
        req: &RouterDataV2<Capture, PaymentsCaptureData, PaymentsResponseData>,
        connectors: &Connectors,
    ) -> CustomResult<Vec<(String, Maskable<String>)>, errors::ConnectorError> {
        // REUSE: Same header logic as Authorize (no duplication)
        let mut headers = vec![(
            headers::CONTENT_TYPE.to_string(),
            self.common_get_content_type().to_string().into(),
        )];
        let mut auth_headers = self.get_auth_header(&req.connector_auth_type)?;
        headers.append(&mut auth_headers);
        Ok(headers)
    }
    
    fn get_content_type(&self) -> &'static str {
        // REUSE: Use common content type (no duplication)
        self.common_get_content_type()
    }
    
    fn get_error_response(
        &self,
        res: Response,
        event_builder: Option<&mut ConnectorEvent>,
    ) -> CustomResult<ErrorResponse, errors::ConnectorError> {
        // REUSE: Use common error handling (no duplication)
        self.build_error_response(res, event_builder)
    }
}

// Refund flow also reuses the same common methods
impl ConnectorIntegrationV2<Refund, RefundsData, RefundsResponseData>
    for ConnectorName<T>
{
    fn get_headers(
        &self,
        req: &RouterDataV2<Refund, RefundsData, RefundsResponseData>,
        connectors: &Connectors,
    ) -> CustomResult<Vec<(String, Maskable<String>)>, errors::ConnectorError> {
        // REUSE: Same header logic (no duplication)
        let mut headers = vec![(
            headers::CONTENT_TYPE.to_string(),
            self.common_get_content_type().to_string().into(),
        )];
        let mut auth_headers = self.get_auth_header(&req.connector_auth_type)?;
        headers.append(&mut auth_headers);
        Ok(headers)
    }
    
    // ... other methods also reuse common implementations
}
```

#### ❌ INCORRECT - Code Duplication:

```rust
// DON'T DO THIS - duplicating the same code in each flow
impl ConnectorIntegrationV2<Authorize, PaymentsAuthorizeData<T>, PaymentsResponseData>
    for ConnectorName<T>
{
    fn get_headers(&self, req: &AuthorizeRouterData) -> Result<Vec<(String, Maskable<String>)>, Error> {
        // WRONG: Duplicating auth logic in each flow
        let auth = ConnectorAuthType::try_from(&req.connector_auth_type)?;
        Ok(vec![
            ("Content-Type".to_string(), "application/json".to_string().into()),
            ("Authorization".to_string(), format!("Bearer {}", auth.api_key.expose()).into()),
        ])
    }
}

impl ConnectorIntegrationV2<Capture, PaymentsCaptureData, PaymentsResponseData>
    for ConnectorName<T>
{
    fn get_headers(&self, req: &CaptureRouterData) -> Result<Vec<(String, Maskable<String>)>, Error> {
        // WRONG: Same code duplicated - should reuse common method
        let auth = ConnectorAuthType::try_from(&req.connector_auth_type)?;
        Ok(vec![
            ("Content-Type".to_string(), "application/json".to_string().into()),
            ("Authorization".to_string(), format!("Bearer {}", auth.api_key.expose()).into()),
        ])
    }
}
```

### Common Code Categories to Reuse:

1. **Authentication**: `get_auth_header()` method in ConnectorCommon
2. **Content Type**: `common_get_content_type()` method in ConnectorCommon  
3. **Error Handling**: `build_error_response()` method in ConnectorCommon
4. **Currency Handling**: `get_currency_unit()` method in ConnectorCommon
5. **Base URL**: `base_url()` method in ConnectorCommon
6. **Connector ID**: `id()` method in ConnectorCommon

### Flow-Specific Code (No Reuse):

1. **URL Building**: Each flow has different endpoints
2. **Request Body**: Each flow has different request structures
3. **Response Handling**: Each flow has different response processing
4. **Business Logic**: Each flow has unique processing requirements

### Benefits of This Pattern:

1. **No Code Duplication**: Common logic implemented once
2. **Flow Independence**: Each flow still works independently
3. **Maintainability**: Changes to auth/headers/errors in one place
4. **Consistency**: All flows use same auth, error handling, etc.
5. **Testability**: Can test flows independently while reusing common code

## 🧠 Troubleshooting & Pattern Learning

### When You Get Stuck

If implementation becomes unclear or you encounter challenges:

#### Step 1: Study Existing UCS Connectors
```rust
// Read these connectors for reference patterns:
// - backend/connector-integration/src/connectors/adyen.rs (comprehensive)
// - backend/connector-integration/src/connectors/razorpayv2.rs (modern patterns)  
// - backend/connector-integration/src/connectors/checkout.rs (clean structure)
```

#### Step 2: Pattern Analysis Process
1. **Overall Structure**: How is the main connector file organized?
2. **Flow Implementation**: How are different flows implemented?
3. **Request Building**: How are API requests constructed?
4. **Response Handling**: How are API responses parsed and mapped?
5. **Error Handling**: How are connector errors mapped to UCS errors?
6. **Payment Methods**: How are different payment types handled?

#### Step 3: Learn, Don't Copy
```rust
// ❌ DON'T DO THIS - Direct copying
let headers = vec![
    ("Authorization".to_string(), "Bearer xyz".into()), // Copied from another connector
];

// ✅ DO THIS - Pattern understanding and adaptation
fn get_auth_header(&self, auth_type: &ConnectorAuthType) -> Result<...> {
    // Understand: WHY do other connectors use this pattern?
    // Adapt: How does this pattern apply to MY connector's API?
    // Verify: Does this pattern work for MY connector's requirements?
    let auth = MyConnectorAuthType::try_from(auth_type)?;
    match self.get_auth_method() {
        AuthMethod::ApiKey => Ok(vec![("X-API-Key".to_string(), auth.api_key.expose().into())]),
        AuthMethod::Bearer => Ok(vec![("Authorization".to_string(), format!("Bearer {}", auth.token.expose()).into())]),
        // Adapted for YOUR connector's specific auth requirements
    }
}
```

#### Step 4: Common Learning Scenarios

**Scenario 1: "How do I handle authentication?"**
```bash
# Study these patterns:
grep -r "get_auth_header" backend/connector-integration/src/connectors/
# Understand different auth patterns, adapt for your connector
```

**Scenario 2: "How do I structure request transformations?"**
```bash
# Study transformers in existing connectors:
cat backend/connector-integration/src/connectors/adyen/transformers.rs
cat backend/connector-integration/src/connectors/razorpayv2/transformers.rs
# Learn the pattern, adapt for your API structure
```

**Scenario 3: "How do I handle payment method variations?"**
```rust
// Study how existing connectors handle PaymentMethodData
// Learn the pattern of matching payment method types
// Adapt for your connector's payment method support
match item.request.payment_method_data.clone() {
    PaymentMethodData::Card(card) => {
        // Learn: How do other connectors transform card data?
        // Adapt: What does YOUR connector's API expect for cards?
    }
    PaymentMethodData::Wallet(wallet_data) => {
        // Learn: How do other connectors handle wallets?
        // Adapt: Which wallets does YOUR connector support?
    }
    // Continue pattern...
}
```

#### Step 5: Troubleshooting Workflow
```
Problem/Question → Study Similar Implementation → Understand Pattern → Adapt for Your Connector → Test → Continue
```

### Reference Guide by Problem Type

| Problem | Study These Connectors | Focus Area |
|---------|------------------------|------------|
| Authentication issues | adyen.rs, razorpayv2.rs | `get_auth_header()` method |
| Request building | checkout.rs, adyen.rs | `get_request_body()` method |
| Response parsing | razorpayv2.rs | `handle_response()` method |
| Error mapping | adyen.rs | `build_error_response()` method |
| Payment methods | adyen.rs (comprehensive) | transformers.rs patterns |
| URL construction | checkout.rs | `get_url()` method |
| Webhook handling | adyen.rs | IncomingWebhook trait |

### Key Learning Principles

1. **Understand the Why**: Don't just copy patterns, understand why they exist
2. **Adapt, Don't Copy**: Every connector has unique API requirements
3. **Verify Fit**: Ensure the pattern works for your specific use case
4. **Test Thoroughly**: Patterns must work with your connector's actual API
5. **Document Learning**: Update GRACE-UCS guides with new insights

Remember: These patterns are battle-tested and should be followed consistently across all UCS connector implementations. When stuck, learn from existing implementations but always adapt patterns to your specific connector's requirements.