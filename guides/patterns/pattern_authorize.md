# Authorize Flow Pattern for Connector Implementation

**🎯 GENERIC PATTERN FILE FOR ANY NEW CONNECTOR**

This document provides comprehensive, reusable patterns for implementing the authorize flow in **ANY** payment connector. These patterns are extracted from successful connector implementations (Adyen, Checkout, PayU, Razorpay) and can be consumed by AI to generate consistent, production-ready authorize flow code for any payment gateway.

## 🚀 Quick Start Guide

To implement a new connector using these patterns:

1. **Choose Your Pattern**: Use [Modern Macro-Based Pattern](#modern-macro-based-pattern-recommended) for 95% of connectors
2. **Replace Placeholders**: Follow the [Placeholder Reference Guide](#placeholder-reference-guide)
3. **Select Components**: Choose auth type, request format, and amount converter based on your connector's API
4. **Follow Checklist**: Use the [Integration Checklist](#integration-checklist) to ensure completeness

### Example: Implementing "NewPayment" Connector

```bash
# Replace placeholders:
{ConnectorName} → NewPayment
{connector_name} → new_payment
{AmountType} → StringMinorUnit (if API expects "1000" for $10.00)
{content_type} → "application/json" (if API uses JSON)
{api_endpoint} → "v1/payments" (your API endpoint)
```

**✅ Result**: Complete, production-ready connector implementation in ~30 minutes

## Table of Contents

1. [Overview](#overview)
2. [Modern Macro-Based Pattern (Recommended)](#modern-macro-based-pattern-recommended)
3. [Legacy Manual Pattern (Reference)](#legacy-manual-pattern-reference)
4. [Authentication Patterns](#authentication-patterns)
5. [Request/Response Format Variations](#requestresponse-format-variations)
6. [Error Handling Patterns](#error-handling-patterns)
7. [Testing Patterns](#testing-patterns)
8. [Common Helper Functions](#common-helper-functions)
9. [Integration Checklist](#integration-checklist)

## Overview

The authorize flow is the core payment processing flow that:
1. Receives payment authorization requests from the router
2. Transforms them to connector-specific format
3. Sends requests to the payment gateway
4. Processes responses and maps statuses
5. Returns standardized responses to the router

### Key Components:
- **Main Connector File**: Implements traits and flow logic
- **Transformers File**: Handles request/response data transformations
- **Authentication**: Manages API credentials and headers
- **Error Handling**: Processes and maps error responses
- **Status Mapping**: Converts connector statuses to standard statuses

## Modern Macro-Based Pattern (Recommended)

This is the current recommended approach using the macro framework for maximum code reuse and consistency.

### File Structure Template

```
connector-service/backend/connector-integration/src/connectors/
├── {connector_name}.rs           # Main connector implementation
└── {connector_name}/
    └── transformers.rs           # Data transformation logic
```

### Main Connector File Pattern

```rust
// File: backend/connector-integration/src/connectors/{connector_name}.rs

pub mod transformers;

use common_utils::{errors::CustomResult, ext_traits::ByteSliceExt};
use domain_types::{
    connector_flow::{
        Accept, Authorize, Capture, CreateOrder, CreateSessionToken, DefendDispute, PSync, RSync,
        Refund, RepeatPayment, SetupMandate, SubmitEvidence, Void,
    },
    connector_types::{
        AcceptDisputeData, DisputeDefendData, DisputeFlowData, DisputeResponseData,
        PaymentCreateOrderData, PaymentCreateOrderResponse, PaymentFlowData, PaymentVoidData,
        PaymentsAuthorizeData, PaymentsCaptureData, PaymentsResponseData, PaymentsSyncData,
        RefundFlowData, RefundSyncData, RefundsData, RefundsResponseData, RepeatPaymentData,
        ResponseId, SessionTokenRequestData, SessionTokenResponseData, SetupMandateRequestData,
        SubmitEvidenceData,
    },
    errors::{self, ConnectorError},
    payment_method_data::PaymentMethodDataTypes,
    router_data::{ConnectorAuthType, ErrorResponse},
    router_data_v2::RouterDataV2,
    router_response_types::Response,
    types::Connectors,
};
use error_stack::ResultExt;
use hyperswitch_masking::{Mask, Maskable};
use interfaces::{
    api::ConnectorCommon, connector_integration_v2::ConnectorIntegrationV2, connector_types,
    events::connector_api_logs::ConnectorEvent,
};
use serde::Serialize;
use transformers::{
    {ConnectorName}AuthorizeRequest, {ConnectorName}AuthorizeResponse, 
    {ConnectorName}ErrorResponse, {ConnectorName}SyncRequest, {ConnectorName}SyncResponse,
    // Add other request/response types as needed
};

use super::macros;
use crate::types::ResponseRouterData;

pub(crate) mod headers {
    // Define headers used by this connector
    pub(crate) const CONTENT_TYPE: &str = "Content-Type";
    pub(crate) const AUTHORIZATION: &str = "Authorization";
    // Add connector-specific headers
    pub(crate) const X_API_KEY: &str = "X-Api-Key";
}

// Trait implementations with generic type parameters
impl<T: PaymentMethodDataTypes + std::fmt::Debug + std::marker::Sync + std::marker::Send + 'static + Serialize>
    connector_types::ConnectorServiceTrait<T> for {ConnectorName}<T>
{
}

impl<T: PaymentMethodDataTypes + std::fmt::Debug + std::marker::Sync + std::marker::Send + 'static + Serialize>
    connector_types::PaymentAuthorizeV2<T> for {ConnectorName}<T>
{
}

impl<T: PaymentMethodDataTypes + std::fmt::Debug + std::marker::Sync + std::marker::Send + 'static + Serialize>
    connector_types::PaymentSyncV2 for {ConnectorName}<T>
{
}

// Add other trait implementations as needed...

// Set up connector using macros with all framework integrations
macros::create_all_prerequisites!(
    connector_name: {ConnectorName},
    generic_type: T,
    api: [
        (
            flow: Authorize,
            request_body: {ConnectorName}AuthorizeRequest<T>,
            response_body: {ConnectorName}AuthorizeResponse,
            router_data: RouterDataV2<Authorize, PaymentFlowData, PaymentsAuthorizeData<T>, PaymentsResponseData>,
        ),
        (
            flow: PSync,
            request_body: {ConnectorName}SyncRequest,
            response_body: {ConnectorName}SyncResponse,
            router_data: RouterDataV2<PSync, PaymentFlowData, PaymentsSyncData, PaymentsResponseData>,
        ),
        // Add other flows as needed...
    ],
    amount_converters: [
        // Choose appropriate amount converter based on connector requirements
        amount_converter: {AmountUnit} // StringMinorUnit, StringMajorUnit, MinorUnit
    ],
    member_functions: {
        pub fn build_headers<F, FCD, Req, Res>(
            &self,
            req: &RouterDataV2<F, FCD, Req, Res>,
        ) -> CustomResult<Vec<(String, Maskable<String>)>, ConnectorError> {
            let mut header = vec![(
                headers::CONTENT_TYPE.to_string(),
                "{content_type}".to_string().into(), // "application/json", "application/x-www-form-urlencoded", etc.
            )];
            let mut auth_header = self.get_auth_header(&req.connector_auth_type)?;
            header.append(&mut auth_header);
            Ok(header)
        }

        pub fn connector_base_url_payments<'a, F, Req, Res>(
            &self,
            req: &'a RouterDataV2<F, PaymentFlowData, Req, Res>,
        ) -> &'a str {
            &req.resource_common_data.connectors.{connector_name}.base_url
        }

        pub fn connector_base_url_refunds<'a, F, Req, Res>(
            &self,
            req: &'a RouterDataV2<F, RefundFlowData, Req, Res>,
        ) -> &'a str {
            &req.resource_common_data.connectors.{connector_name}.base_url
        }

        // Add custom preprocessing if needed (like PayU's base64 decoding)
        pub fn preprocess_response_bytes<F, FCD, Res>(
            &self,
            req: &RouterDataV2<F, FCD, PaymentsAuthorizeData<T>, Res>,
            bytes: bytes::Bytes,
        ) -> CustomResult<bytes::Bytes, ConnectorError> {
            // Custom preprocessing logic here if needed
            // Example: Base64 decoding, XML parsing, etc.
            Ok(bytes)
        }
    }
);

// Implement ConnectorCommon trait
impl<T: PaymentMethodDataTypes + std::fmt::Debug + std::marker::Sync + std::marker::Send + 'static + Serialize>
    ConnectorCommon for {ConnectorName}<T>
{
    fn id(&self) -> &'static str {
        "{connector_name}"
    }

    fn get_currency_unit(&self) -> common_enums::CurrencyUnit {
        common_enums::CurrencyUnit::{Major|Minor} // Choose based on connector requirements
    }

    fn base_url<'a>(&self, connectors: &'a Connectors) -> &'a str {
        &connectors.{connector_name}.base_url
    }

    fn get_auth_header(
        &self,
        auth_type: &ConnectorAuthType,
    ) -> CustomResult<Vec<(String, Maskable<String>)>, ConnectorError> {
        let auth = transformers::{ConnectorName}AuthType::try_from(auth_type)
            .change_context(errors::ConnectorError::FailedToObtainAuthType)?;
        
        // Choose appropriate auth header format based on connector
        Ok(vec![(
            headers::AUTHORIZATION.to_string(),
            // Choose one of the following patterns:
            format!("Bearer {}", auth.api_key.peek()).into_masked(), // Bearer token
            // OR
            format!("Basic {}", auth.generate_basic_auth()).into_masked(), // Basic auth
            // OR
            auth.api_key.into_masked(), // Direct API key
        )])
    }

    fn build_error_response(
        &self,
        res: Response,
        event_builder: Option<&mut ConnectorEvent>,
    ) -> CustomResult<ErrorResponse, errors::ConnectorError> {
        let response: {ConnectorName}ErrorResponse = if res.response.is_empty() {
            // Handle empty responses
            {ConnectorName}ErrorResponse::default()
        } else {
            res.response
                .parse_struct("ErrorResponse")
                .change_context(errors::ConnectorError::ResponseDeserializationFailed)?
        };

        if let Some(i) = event_builder {
            i.set_error_response_body(&response);
        }

        Ok(ErrorResponse {
            status_code: res.status_code,
            code: response.error_code.unwrap_or_default(),
            message: response.error_message.unwrap_or_default(),
            reason: response.error_description,
            attempt_status: None, // Map based on error types
            connector_transaction_id: response.transaction_id,
            network_decline_code: None,
            network_advice_code: None,
            network_error_message: None,
        })
    }
}

// Implement Authorize flow using macro framework
macros::macro_connector_implementation!(
    connector_default_implementations: [get_content_type, get_error_response_v2],
    connector: {ConnectorName},
    curl_request: {Json|FormUrlEncoded}({ConnectorName}AuthorizeRequest), // Choose format
    curl_response: {ConnectorName}AuthorizeResponse,
    flow_name: Authorize,
    resource_common_data: PaymentFlowData,
    flow_request: PaymentsAuthorizeData<T>,
    flow_response: PaymentsResponseData,
    http_method: Post,
    // Add if custom preprocessing needed:
    // preprocess_response: true,
    generic_type: T,
    [PaymentMethodDataTypes + std::fmt::Debug + std::marker::Sync + std::marker::Send + 'static + Serialize],
    other_functions: {
        fn get_headers(
            &self,
            req: &RouterDataV2<Authorize, PaymentFlowData, PaymentsAuthorizeData<T>, PaymentsResponseData>,
        ) -> CustomResult<Vec<(String, Maskable<String>)>, ConnectorError> {
            self.build_headers(req)
        }
        
        fn get_url(
            &self,
            req: &RouterDataV2<Authorize, PaymentFlowData, PaymentsAuthorizeData<T>, PaymentsResponseData>,
        ) -> CustomResult<String, ConnectorError> {
            let base_url = self.connector_base_url_payments(req);
            Ok(format!("{base_url}/{api_endpoint}")) // Replace {api_endpoint} with actual endpoint
        }
    }
);

// Add Source Verification stubs for all flows (Phase 10 placeholders)
use interfaces::verification::SourceVerification;

impl<T: PaymentMethodDataTypes + std::fmt::Debug + std::marker::Sync + std::marker::Send + 'static + Serialize>
    SourceVerification<Authorize, PaymentFlowData, PaymentsAuthorizeData<T>, PaymentsResponseData>
    for {ConnectorName}<T>
{
    // Stub implementations - will be replaced in Phase 10
}

// Add stub implementations for unsupported flows
impl<T: PaymentMethodDataTypes + std::fmt::Debug + std::marker::Sync + std::marker::Send + 'static + Serialize>
    ConnectorIntegrationV2<PSync, PaymentFlowData, PaymentsSyncData, PaymentsResponseData>
    for {ConnectorName}<T>
{
}

// Continue with other flows as needed...
```

### Transformers File Pattern

```rust
// File: backend/connector-integration/src/connectors/{connector_name}/transformers.rs

use std::collections::HashMap;

use common_utils::{ext_traits::OptionExt, pii, request::Method, types::{MinorUnit, StringMinorUnit}};
use domain_types::{
    connector_flow::{self, Authorize, PSync},
    connector_types::{
        PaymentFlowData, PaymentsAuthorizeData, PaymentsResponseData, PaymentsSyncData,
        ResponseId,
    },
    errors::{self, ConnectorError},
    payment_method_data::{
        PaymentMethodData, PaymentMethodDataTypes, RawCardNumber,
    },
    router_data::{ConnectorAuthType, ErrorResponse},
    router_data_v2::RouterDataV2,
    router_response_types::RedirectForm,
};
use error_stack::ResultExt;
use hyperswitch_masking::{ExposeInterface, Secret, PeekInterface};
use serde::{Deserialize, Serialize};

use crate::types::ResponseRouterData;

// Authentication Type Definition
#[derive(Debug)]
pub struct {ConnectorName}AuthType {
    pub api_key: Secret<String>,
    // Add other auth fields as needed
    pub api_secret: Option<Secret<String>>,
}

impl {ConnectorName}AuthType {
    pub fn generate_basic_auth(&self) -> String {
        // Implement basic auth generation if needed
        base64::encode(format!("{}:{}", 
            self.api_key.peek(), 
            self.api_secret.as_ref().map(|s| s.peek()).unwrap_or("")
        ))
    }
}

impl TryFrom<&ConnectorAuthType> for {ConnectorName}AuthType {
    type Error = ConnectorError;
    
    fn try_from(auth_type: &ConnectorAuthType) -> Result<Self, Self::Error> {
        match auth_type {
            ConnectorAuthType::HeaderKey { api_key } => Ok(Self {
                api_key: api_key.to_owned(),
                api_secret: None,
            }),
            ConnectorAuthType::SignatureKey { api_key, api_secret, .. } => Ok(Self {
                api_key: api_key.to_owned(),
                api_secret: Some(api_secret.to_owned()),
            }),
            ConnectorAuthType::BodyKey { api_key, key1 } => Ok(Self {
                api_key: api_key.to_owned(),
                api_secret: Some(key1.to_owned()),
            }),
            _ => Err(ConnectorError::FailedToObtainAuthType),
        }
    }
}

// Request Structure Template
#[derive(Debug, Serialize)]
pub struct {ConnectorName}AuthorizeRequest<
    T: PaymentMethodDataTypes + std::fmt::Debug + std::marker::Sync + std::marker::Send + 'static + Serialize,
> {
    pub amount: {AmountType}, // MinorUnit, StringMinorUnit, etc.
    pub currency: String,
    pub payment_method: {ConnectorName}PaymentMethod<T>,
    // Add other required fields
    pub reference: String,
    pub description: Option<String>,
}

// Payment Method Structure
#[derive(Debug, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum {ConnectorName}PaymentMethod<
    T: PaymentMethodDataTypes + std::fmt::Debug + std::marker::Sync + std::marker::Send + 'static + Serialize,
> {
    Card({ConnectorName}Card<T>),
    // Add other payment methods as needed
}

#[derive(Debug, Serialize)]
pub struct {ConnectorName}Card<
    T: PaymentMethodDataTypes + std::fmt::Debug + std::marker::Sync + std::marker::Send + 'static + Serialize,
> {
    pub number: RawCardNumber<T>,
    pub exp_month: Secret<String>,
    pub exp_year: Secret<String>,
    pub cvc: Option<Secret<String>>,
    pub holder_name: Option<Secret<String>>,
}

// Response Structure Template
#[derive(Debug, Deserialize)]
pub struct {ConnectorName}AuthorizeResponse {
    pub id: String,
    pub status: {ConnectorName}PaymentStatus,
    pub amount: Option<i64>,
    // Add other response fields
    pub reference: Option<String>,
    pub error: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum {ConnectorName}PaymentStatus {
    Pending,
    Succeeded,
    Failed,
    // Add connector-specific statuses
}

// Error Response Structure
#[derive(Debug, Deserialize)]
pub struct {ConnectorName}ErrorResponse {
    pub error_code: Option<String>,
    pub error_message: Option<String>,
    pub error_description: Option<String>,
    pub transaction_id: Option<String>,
}

impl Default for {ConnectorName}ErrorResponse {
    fn default() -> Self {
        Self {
            error_code: Some("UNKNOWN_ERROR".to_string()),
            error_message: Some("Unknown error occurred".to_string()),
            error_description: None,
            transaction_id: None,
        }
    }
}

// Request Transformation Implementation
impl<T: PaymentMethodDataTypes + std::fmt::Debug + std::marker::Sync + std::marker::Send + 'static + Serialize>
    TryFrom<{ConnectorName}RouterData<RouterDataV2<Authorize, PaymentFlowData, PaymentsAuthorizeData<T>, PaymentsResponseData>, T>>
    for {ConnectorName}AuthorizeRequest<T>
{
    type Error = error_stack::Report<ConnectorError>;

    fn try_from(
        item: {ConnectorName}RouterData<RouterDataV2<Authorize, PaymentFlowData, PaymentsAuthorizeData<T>, PaymentsResponseData>, T>,
    ) -> Result<Self, Self::Error> {
        let router_data = &item.router_data;
        
        // Extract payment method data
        let payment_method = match &router_data.request.payment_method_data {
            PaymentMethodData::Card(card_data) => {
                {ConnectorName}PaymentMethod::Card({ConnectorName}Card {
                    number: card_data.card_number.clone(),
                    exp_month: card_data.card_exp_month.clone(),
                    exp_year: card_data.card_exp_year.clone(),
                    cvc: Some(card_data.card_cvc.clone()),
                    holder_name: router_data.request.customer_name.clone().map(Secret::new),
                })
            },
            _ => return Err(ConnectorError::NotImplemented("Payment method not supported".to_string()).into()),
        };

        Ok(Self {
            amount: item.amount, // Use converted amount from RouterData
            currency: router_data.request.currency.to_string(),
            payment_method,
            reference: router_data.resource_common_data.connector_request_reference_id.clone(),
            description: router_data.request.description.clone(),
        })
    }
}

// Response Transformation Implementation
impl<T: PaymentMethodDataTypes + std::fmt::Debug + std::marker::Sync + std::marker::Send + 'static + Serialize>
    TryFrom<ResponseRouterData<{ConnectorName}AuthorizeResponse, RouterDataV2<Authorize, PaymentFlowData, PaymentsAuthorizeData<T>, PaymentsResponseData>>>
    for RouterDataV2<Authorize, PaymentFlowData, PaymentsAuthorizeData<T>, PaymentsResponseData>
{
    type Error = error_stack::Report<ConnectorError>;

    fn try_from(
        item: ResponseRouterData<{ConnectorName}AuthorizeResponse, RouterDataV2<Authorize, PaymentFlowData, PaymentsAuthorizeData<T>, PaymentsResponseData>>,
    ) -> Result<Self, Self::Error> {
        let response = &item.response;
        let router_data = &item.router_data;

        // Map connector status to standard status
        let status = match response.status {
            {ConnectorName}PaymentStatus::Succeeded => common_enums::AttemptStatus::Charged,
            {ConnectorName}PaymentStatus::Pending => common_enums::AttemptStatus::Pending,
            {ConnectorName}PaymentStatus::Failed => common_enums::AttemptStatus::Failure,
        };

        // Handle error responses
        if let Some(error) = &response.error {
            return Ok(Self {
                resource_common_data: PaymentFlowData {
                    status: common_enums::AttemptStatus::Failure,
                    ..router_data.resource_common_data.clone()
                },
                response: Err(ErrorResponse {
                    code: error.clone(),
                    message: error.clone(),
                    reason: Some(error.clone()),
                    status_code: item.http_code,
                    attempt_status: Some(common_enums::AttemptStatus::Failure),
                    connector_transaction_id: Some(response.id.clone()),
                    network_decline_code: None,
                    network_advice_code: None,
                    network_error_message: None,
                }),
                ..router_data.clone()
            });
        }

        // Success response
        let payments_response_data = PaymentsResponseData::TransactionResponse {
            resource_id: ResponseId::ConnectorTransactionId(response.id.clone()),
            redirection_data: None, // Add redirection logic if needed
            mandate_reference: None, // Add mandate handling if needed
            connector_metadata: None,
            network_txn_id: None,
            connector_response_reference_id: response.reference.clone(),
            incremental_authorization_allowed: None,
            status_code: item.http_code,
        };

        Ok(Self {
            resource_common_data: PaymentFlowData {
                status,
                ..router_data.resource_common_data.clone()
            },
            response: Ok(payments_response_data),
            ..router_data.clone()
        })
    }
}

// Helper struct for router data transformation
pub struct {ConnectorName}RouterData<T, U> {
    pub amount: {AmountType},
    pub router_data: T,
    pub connector: U,
}

impl<T, U> TryFrom<({AmountType}, T, U)> for {ConnectorName}RouterData<T, U> {
    type Error = error_stack::Report<ConnectorError>;
    
    fn try_from((amount, router_data, connector): ({AmountType}, T, U)) -> Result<Self, Self::Error> {
        Ok(Self {
            amount,
            router_data,
            connector,
        })
    }
}
```

## Legacy Manual Pattern (Reference)

This pattern shows the older manual implementation style (like Razorpay) for reference or special cases where macros are insufficient.

### Main Connector File (Manual Implementation)

```rust
#[derive(Clone)]
pub struct {ConnectorName}<T> {
    #[allow(dead_code)]
    pub(crate) amount_converter: &'static (dyn AmountConvertor<Output = MinorUnit> + Sync),
    #[allow(dead_code)]
    _phantom: std::marker::PhantomData<T>,
}

impl<T> {ConnectorName}<T> {
    pub const fn new() -> &'static Self {
        &Self {
            amount_converter: &common_utils::types::MinorUnitForConnector,
            _phantom: std::marker::PhantomData,
        }
    }
}

// Manual trait implementations
impl<T: PaymentMethodDataTypes + Debug + Sync + Send + 'static + Serialize>
    ConnectorIntegrationV2<Authorize, PaymentFlowData, PaymentsAuthorizeData<T>, PaymentsResponseData>
    for {ConnectorName}<T>
{
    fn get_headers(
        &self,
        req: &RouterDataV2<Authorize, PaymentFlowData, PaymentsAuthorizeData<T>, PaymentsResponseData>,
    ) -> CustomResult<Vec<(String, Maskable<String>)>, errors::ConnectorError> {
        let mut header = vec![(
            "Content-Type".to_string(),
            "application/json".to_string().into(),
        )];
        let mut api_key = self.get_auth_header(&req.connector_auth_type)?;
        header.append(&mut api_key);
        Ok(header)
    }

    fn get_url(
        &self,
        req: &RouterDataV2<Authorize, PaymentFlowData, PaymentsAuthorizeData<T>, PaymentsResponseData>,
    ) -> CustomResult<String, errors::ConnectorError> {
        let base_url = &req.resource_common_data.connectors.{connector_name}.base_url;
        Ok(format!("{base_url}/{endpoint}"))
    }

    fn get_request_body(
        &self,
        req: &RouterDataV2<Authorize, PaymentFlowData, PaymentsAuthorizeData<T>, PaymentsResponseData>,
    ) -> CustomResult<Option<RequestContent>, errors::ConnectorError> {
        let converted_amount = self
            .amount_converter
            .convert(req.request.minor_amount, req.request.currency)
            .change_context(errors::ConnectorError::RequestEncodingFailed)?;
        
        let connector_router_data = {ConnectorName}RouterData::try_from((converted_amount, req))?;
        let connector_req = {ConnectorName}AuthorizeRequest::try_from(&connector_router_data)?;
        
        Ok(Some(RequestContent::Json(Box::new(connector_req))))
    }

    fn handle_response_v2(
        &self,
        data: &RouterDataV2<Authorize, PaymentFlowData, PaymentsAuthorizeData<T>, PaymentsResponseData>,
        event_builder: Option<&mut ConnectorEvent>,
        res: Response,
    ) -> CustomResult<RouterDataV2<Authorize, PaymentFlowData, PaymentsAuthorizeData<T>, PaymentsResponseData>, errors::ConnectorError> {
        let response: {ConnectorName}AuthorizeResponse = res
            .response
            .parse_struct("{ConnectorName}AuthorizeResponse")
            .change_context(errors::ConnectorError::ResponseDeserializationFailed)?;

        event_builder.map(|i| i.set_response_body(&response));

        RouterDataV2::try_from(ResponseRouterData {
            response,
            data: data.clone(),
            http_code: res.status_code,
        })
        .change_context(errors::ConnectorError::ResponseHandlingFailed)
    }

    fn get_error_response_v2(
        &self,
        res: Response,
        event_builder: Option<&mut ConnectorEvent>,
    ) -> CustomResult<ErrorResponse, errors::ConnectorError> {
        self.build_error_response(res, event_builder)
    }
}
```

## Authentication Patterns

### HeaderKey Authentication (Bearer Token)

```rust
impl TryFrom<&ConnectorAuthType> for {ConnectorName}AuthType {
    type Error = ConnectorError;
    
    fn try_from(auth_type: &ConnectorAuthType) -> Result<Self, Self::Error> {
        match auth_type {
            ConnectorAuthType::HeaderKey { api_key } => Ok(Self {
                api_token: api_key.to_owned(),
            }),
            _ => Err(ConnectorError::FailedToObtainAuthType),
        }
    }
}

// In get_auth_header:
Ok(vec![(
    "Authorization".to_string(),
    format!("Bearer {}", auth.api_token.peek()).into_masked(),
)])
```

### SignatureKey Authentication (API Key + Secret)

```rust
impl TryFrom<&ConnectorAuthType> for {ConnectorName}AuthType {
    type Error = ConnectorError;
    
    fn try_from(auth_type: &ConnectorAuthType) -> Result<Self, Self::Error> {
        match auth_type {
            ConnectorAuthType::SignatureKey { api_key, api_secret, .. } => Ok(Self {
                api_key: api_key.to_owned(),
                api_secret: api_secret.to_owned(),
            }),
            _ => Err(ConnectorError::FailedToObtainAuthType),
        }
    }
}

// Basic Auth generation:
impl {ConnectorName}AuthType {
    pub fn generate_authorization_header(&self) -> String {
        let credentials = format!("{}:{}", self.api_key.peek(), self.api_secret.peek());
        let encoded = base64::Engine::encode(&base64::engine::general_purpose::STANDARD, credentials);
        format!("Basic {encoded}")
    }
}

// In get_auth_header:
Ok(vec![(
    "Authorization".to_string(),
    auth.generate_authorization_header().into_masked(),
)])
```

### BodyKey Authentication (Form-based)

```rust
impl TryFrom<&ConnectorAuthType> for {ConnectorName}AuthType {
    type Error = ConnectorError;
    
    fn try_from(auth_type: &ConnectorAuthType) -> Result<Self, Self::Error> {
        match auth_type {
            ConnectorAuthType::BodyKey { api_key, key1 } => Ok(Self {
                merchant_id: api_key.to_owned(),
                secret_key: key1.to_owned(),
            }),
            _ => Err(ConnectorError::FailedToObtainAuthType),
        }
    }
}

// Include in request body instead of headers
```

## Request/Response Format Variations

### JSON Format (Most Common)

```rust
// In macro implementation:
curl_request: Json({ConnectorName}AuthorizeRequest),

// Content type:
"Content-Type": "application/json"

// Serialization: Automatically handled by serde
```

### Form URL Encoded Format

```rust
// In macro implementation:
curl_request: FormUrlEncoded({ConnectorName}AuthorizeRequest),

// Content type:
"Content-Type": "application/x-www-form-urlencoded"

// Request structure:
#[derive(Debug, Serialize)]
pub struct {ConnectorName}AuthorizeRequest {
    pub amount: String,
    pub currency: String,
    pub method: String,
    // Flatten card data for form encoding
    #[serde(flatten)]
    pub card: Option<{ConnectorName}CardForm>,
}

#[derive(Debug, Serialize)]
pub struct {ConnectorName}CardForm {
    #[serde(rename = "card[number]")]
    pub card_number: String,
    #[serde(rename = "card[exp_month]")]
    pub card_exp_month: String,
    #[serde(rename = "card[exp_year]")]
    pub card_exp_year: String,
    #[serde(rename = "card[cvc]")]
    pub card_cvc: String,
}
```

### XML Format

```rust
// For connectors that use XML (like WorldpayVantiv)
// Custom serialization needed

impl {ConnectorName}AuthorizeRequest<T> {
    pub fn to_xml(&self) -> Result<String, ConnectorError> {
        // Custom XML serialization logic
        let xml = format!(
            r#"<?xml version="1.0" encoding="UTF-8"?>
            <payment>
                <amount>{}</amount>
                <currency>{}</currency>
                <reference>{}</reference>
            </payment>"#,
            self.amount, self.currency, self.reference
        );
        Ok(xml)
    }
}

// In get_request_body:
let xml_body = connector_req.to_xml()?;
Ok(Some(RequestContent::RawBytes(xml_body.into_bytes())))
```

## Error Handling Patterns

### Standard Error Response Mapping

```rust
impl<T: PaymentMethodDataTypes + std::fmt::Debug + std::marker::Sync + std::marker::Send + 'static + Serialize>
    ConnectorCommon for {ConnectorName}<T>
{
    fn build_error_response(
        &self,
        res: Response,
        event_builder: Option<&mut ConnectorEvent>,
    ) -> CustomResult<ErrorResponse, errors::ConnectorError> {
        let response: {ConnectorName}ErrorResponse = if res.response.is_empty() {
            // Handle empty error responses
            {ConnectorName}ErrorResponse {
                error_code: Some("HTTP_ERROR".to_string()),
                error_message: Some(format!("HTTP {}", res.status_code)),
                error_description: None,
                transaction_id: None,
            }
        } else {
            res.response
                .parse_struct("ErrorResponse")
                .change_context(errors::ConnectorError::ResponseDeserializationFailed)?
        };

        if let Some(i) = event_builder {
            i.set_error_response_body(&response);
        }

        // Map connector-specific error codes to standard attempt statuses
        let attempt_status = match response.error_code.as_deref() {
            Some("INSUFFICIENT_FUNDS") => Some(common_enums::AttemptStatus::Failure),
            Some("INVALID_CARD") => Some(common_enums::AttemptStatus::Failure),
            Some("EXPIRED_CARD") => Some(common_enums::AttemptStatus::Failure),
            Some("AUTHENTICATION_FAILED") => Some(common_enums::AttemptStatus::AuthenticationFailed),
            Some("AUTHORIZATION_FAILED") => Some(common_enums::AttemptStatus::AuthorizationFailed),
            Some("NETWORK_ERROR") => Some(common_enums::AttemptStatus::Pending),
            _ => Some(common_enums::AttemptStatus::Failure),
        };

        Ok(ErrorResponse {
            status_code: res.status_code,
            code: response.error_code.unwrap_or_default(),
            message: response.error_message.unwrap_or_default(),
            reason: response.error_description,
            attempt_status,
            connector_transaction_id: response.transaction_id,
            network_decline_code: None,
            network_advice_code: None,
            network_error_message: None,
        })
    }
}
```

### Unified Error Response Pattern

```rust
#[derive(Debug, Deserialize)]
#[serde(untagged)]
pub enum {ConnectorName}ErrorResponse {
    StandardError {
        error: {ConnectorName}Error,
    },
    SimpleError {
        message: String,
        code: Option<String>,
    },
    DetailedError {
        error_code: String,
        error_message: String,
        error_description: Option<String>,
        transaction_id: Option<String>,
    },
}

#[derive(Debug, Deserialize)]
pub struct {ConnectorName}Error {
    pub code: String,
    pub message: String,
    pub description: Option<String>,
}
```

### Status Mapping Pattern

```rust
// Status mapping function
fn map_connector_status_to_attempt_status(
    connector_status: &{ConnectorName}PaymentStatus,
    is_manual_capture: bool,
) -> common_enums::AttemptStatus {
    match connector_status {
        {ConnectorName}PaymentStatus::Succeeded => {
            if is_manual_capture {
                common_enums::AttemptStatus::Authorized
            } else {
                common_enums::AttemptStatus::Charged
            }
        },
        {ConnectorName}PaymentStatus::Pending => common_enums::AttemptStatus::Pending,
        {ConnectorName}PaymentStatus::Failed => common_enums::AttemptStatus::Failure,
        {ConnectorName}PaymentStatus::RequiresAction => common_enums::AttemptStatus::AuthenticationPending,
        {ConnectorName}PaymentStatus::Canceled => common_enums::AttemptStatus::Voided,
    }
}
```

## Testing Patterns

### Unit Test Structure

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use domain_types::connector_types::PaymentFlowData;
    use common_enums::{Currency, AttemptStatus};

    #[test]
    fn test_authorize_request_transformation() {
        // Test request transformation
        let router_data = create_test_router_data();
        let connector_req = {ConnectorName}AuthorizeRequest::try_from(&router_data);
        
        assert!(connector_req.is_ok());
        let req = connector_req.unwrap();
        assert_eq!(req.amount, MinorUnit::new(1000));
        assert_eq!(req.currency, "USD");
    }

    #[test]
    fn test_authorize_response_transformation() {
        // Test response transformation
        let response = {ConnectorName}AuthorizeResponse {
            id: "test_transaction_id".to_string(),
            status: {ConnectorName}PaymentStatus::Succeeded,
            amount: Some(1000),
            reference: Some("test_ref".to_string()),
            error: None,
        };

        let router_data = create_test_router_data();
        let response_router_data = ResponseRouterData {
            response,
            data: router_data,
            http_code: 200,
        };

        let result = RouterDataV2::try_from(response_router_data);
        assert!(result.is_ok());
        
        let router_data_result = result.unwrap();
        assert_eq!(router_data_result.resource_common_data.status, AttemptStatus::Charged);
    }

    #[test]
    fn test_error_response_handling() {
        // Test error response handling
        let error_response = {ConnectorName}ErrorResponse {
            error_code: Some("INSUFFICIENT_FUNDS".to_string()),
            error_message: Some("Insufficient funds".to_string()),
            error_description: Some("Card has insufficient funds".to_string()),
            transaction_id: Some("txn_123".to_string()),
        };

        // Test error response transformation
        // ... assertions
    }

    fn create_test_router_data() -> RouterDataV2<Authorize, PaymentFlowData, PaymentsAuthorizeData<DefaultPCIHolder>, PaymentsResponseData> {
        // Create test router data structure
        // ... implementation
    }
}
```

### Integration Test Pattern

```rust
#[cfg(test)]
mod integration_tests {
    use super::*;
    
    #[tokio::test]
    async fn test_authorize_flow_integration() {
        let connector = {ConnectorName}::new();
        
        // Mock request data
        let request_data = create_test_authorize_request();
        
        // Test headers generation
        let headers = connector.get_headers(&request_data).unwrap();
        assert!(headers.contains(&("Content-Type".to_string(), "application/json".into())));
        
        // Test URL generation
        let url = connector.get_url(&request_data).unwrap();
        assert!(url.contains("{base_url}"));
        
        // Test request body generation
        let request_body = connector.get_request_body(&request_data).unwrap();
        assert!(request_body.is_some());
    }
}
```

## Common Helper Functions

### Amount Conversion Helpers

```rust
// Helper function for amount conversion
pub fn convert_amount(
    amount_converter: &dyn AmountConvertor<Output = {AmountType}>,
    amount: MinorUnit,
    currency: common_enums::Currency,
) -> Result<{AmountType}, ConnectorError> {
    amount_converter
        .convert(amount, currency)
        .change_context(ConnectorError::RequestEncodingFailed)
}

// Amount validation
pub fn validate_amount(amount: MinorUnit) -> Result<(), ConnectorError> {
    if amount.get_amount_as_i64() <= 0 {
        return Err(ConnectorError::InvalidRequestData {
            message: "Amount must be greater than zero".to_string(),
        });
    }
    Ok(())
}
```

### Payment Method Extraction Helpers

```rust
// Helper to extract card data
pub fn extract_card_data<T: PaymentMethodDataTypes>(
    payment_method_data: &PaymentMethodData<T>,
) -> Result<&Card<T>, ConnectorError> {
    match payment_method_data {
        PaymentMethodData::Card(card_data) => Ok(card_data),
        _ => Err(ConnectorError::NotImplemented(
            "Only card payments are supported".to_string(),
        )),
    }
}

// Helper to extract billing address
pub fn extract_billing_address(
    router_data: &RouterDataV2<impl FlowTypes, impl FlowTypes, impl FlowTypes, impl FlowTypes>,
) -> Option<Address> {
    router_data
        .resource_common_data
        .address
        .get_payment_billing()
        .cloned()
}

// Helper to extract customer information
pub fn extract_customer_info(
    router_data: &RouterDataV2<impl FlowTypes, impl FlowTypes, impl FlowTypes, impl FlowTypes>,
) -> Result<{ConnectorName}Customer, ConnectorError> {
    let billing = extract_billing_address(router_data);
    
    Ok({ConnectorName}Customer {
        email: router_data.request.email.clone(),
        phone: billing.and_then(|b| b.phone.as_ref().and_then(|p| p.number.clone())),
        name: router_data.request.customer_name.clone(),
    })
}
```

### URL Construction Helpers

```rust
// Helper for URL construction
pub fn build_connector_url(base_url: &str, endpoint: &str) -> String {
    format!("{}/{}", base_url.trim_end_matches('/'), endpoint.trim_start_matches('/'))
}

// Helper for URL with path parameters
pub fn build_connector_url_with_id(base_url: &str, endpoint: &str, id: &str) -> String {
    format!("{}/{}/{}", 
        base_url.trim_end_matches('/'), 
        endpoint.trim_start_matches('/'), 
        id
    )
}
```

### Response Processing Helpers

```rust
// Helper for processing redirection responses
pub fn create_redirection_form(
    redirect_url: String,
    form_fields: HashMap<String, String>,
) -> RedirectForm {
    if form_fields.is_empty() {
        RedirectForm::Uri { uri: redirect_url }
    } else {
        RedirectForm::Form {
            endpoint: redirect_url,
            method: Method::Post,
            form_fields,
        }
    }
}

// Helper for extracting transaction reference
pub fn extract_transaction_reference(response: &{ConnectorName}AuthorizeResponse) -> Option<String> {
    response.reference.clone()
        .or_else(|| response.id.clone())
}
```

## Integration Checklist

### Pre-Implementation Checklist

- [ ] **API Documentation Review**
  - [ ] Understand connector's API endpoints
  - [ ] Review authentication requirements
  - [ ] Identify required/optional fields
  - [ ] Understand error response formats
  - [ ] Review status codes and meanings

- [ ] **Payment Methods Support**
  - [ ] Identify supported payment methods
  - [ ] Review card network support
  - [ ] Check currency support
  - [ ] Understand amount format requirements

- [ ] **Integration Requirements**
  - [ ] Determine authentication type (HeaderKey, SignatureKey, BodyKey)
  - [ ] Choose request format (JSON, FormUrlEncoded, XML)
  - [ ] Identify amount converter type (MinorUnit, StringMinorUnit, StringMajorUnit)
  - [ ] Review any special preprocessing requirements

### Implementation Checklist

- [ ] **File Structure Setup**
  - [ ] Create main connector file: `{connector_name}.rs`
  - [ ] Create transformers directory: `{connector_name}/`
  - [ ] Create transformers file: `{connector_name}/transformers.rs`

- [ ] **Main Connector Implementation**
  - [ ] Add connector to `ConnectorEnum` in `connector_types.rs`
  - [ ] Implement trait implementations with generic types
  - [ ] Set up `macros::create_all_prerequisites!` with correct parameters
  - [ ] Implement `ConnectorCommon` trait
  - [ ] Implement authorize flow with `macros::macro_connector_implementation!`
  - [ ] Add Source Verification stubs
  - [ ] Add stub implementations for unsupported flows

- [ ] **Transformers Implementation**
  - [ ] Define authentication type and implementation
  - [ ] Create request structures with proper generics
  - [ ] Create response structures
  - [ ] Create error response structures
  - [ ] Implement request transformation (`TryFrom` for request)
  - [ ] Implement response transformation (`TryFrom` for response)
  - [ ] Add helper structures and functions

### Testing Checklist

- [ ] **Unit Tests**
  - [ ] Test request transformation
  - [ ] Test response transformation  
  - [ ] Test error response handling
  - [ ] Test status mapping
  - [ ] Test authentication header generation

- [ ] **Integration Tests**
  - [ ] Test headers generation
  - [ ] Test URL construction
  - [ ] Test request body generation
  - [ ] Test complete authorize flow

### Configuration Checklist

- [ ] **Connector Configuration**
  - [ ] Add connector to `Connectors` struct in `domain_types/src/types.rs`
  - [ ] Add base URL configuration
  - [ ] Add connector metadata if required
  - [ ] Update configuration files (`development.toml`)

- [ ] **Registration**
  - [ ] Add connector to conversion functions
  - [ ] Add to connector list in integration module
  - [ ] Export connector modules properly

### Validation Checklist

- [ ] **Code Quality**
  - [ ] Run `cargo build` and fix all errors
  - [ ] Run `cargo test` and ensure all tests pass
  - [ ] Run `cargo clippy` and fix warnings
  - [ ] Run `cargo fmt` for consistent formatting

- [ ] **Functionality Validation**
  - [ ] Test with sandbox/test credentials
  - [ ] Verify successful payment processing
  - [ ] Verify error handling works correctly
  - [ ] Test different payment methods if supported
  - [ ] Verify status mapping is correct

### Documentation Checklist

- [ ] **Code Documentation**
  - [ ] Add comprehensive doc comments
  - [ ] Document any special requirements or limitations
  - [ ] Add usage examples in comments

- [ ] **Integration Documentation**
  - [ ] Document supported payment methods
  - [ ] Document authentication requirements
  - [ ] Document any special configuration needed
  - [ ] Document known limitations

## Placeholder Reference Guide

**🔄 UNIVERSAL REPLACEMENT SYSTEM**

This is the key to making this pattern work for ANY connector. Simply replace these placeholders with your connector-specific values:

| Placeholder | Description | Example Values | When to Use |
|-------------|-------------|----------------|-------------|
| `{ConnectorName}` | Connector name in PascalCase | `Stripe`, `Adyen`, `PayPal`, `NewPayment` | **Always required** - Used in struct names, type names |
| `{connector_name}` | Connector name in snake_case | `stripe`, `adyen`, `paypal`, `new_payment` | **Always required** - Used in file names, config keys |
| `{AmountType}` | Amount type based on connector API | `MinorUnit`, `StringMinorUnit`, `StringMajorUnit` | **Choose based on API**: See [Amount Type Guide](#amount-type-selection-guide) |
| `{AmountUnit}` | Amount converter type | `MinorUnit`, `StringMinorUnit`, `StringMajorUnit` | **Must match {AmountType}** |
| `{content_type}` | Request content type | `"application/json"`, `"application/x-www-form-urlencoded"` | **Based on API format**: JSON = most common |
| `{api_endpoint}` | API endpoint path | `"payments"`, `"v1/charges"`, `"transactions"` | **From API docs** - Main payment endpoint |
| `{Major\|Minor}` | Currency unit choice | `Major` or `Minor` | **Choose one**: Minor = cents, Major = dollars |

### Amount Type Selection Guide

Choose the right amount type based on your connector's API requirements:

| API Expects | Amount Type | Example |
|-------------|-------------|---------|
| Integer cents (1000 for $10.00) | `MinorUnit` | Stripe, Adyen |
| String cents ("1000" for $10.00) | `StringMinorUnit` | PayU, some legacy APIs |
| String dollars ("10.00" for $10.00) | `StringMajorUnit` | Older banking APIs |

### Authentication Type Selection Guide

Choose based on how your connector handles authentication:

| API Auth Method | ConnectorAuthType | Implementation |
|-----------------|-------------------|----------------|
| `Authorization: Bearer token` | `HeaderKey` | Most modern APIs |
| `Authorization: Basic base64(key:secret)` | `SignatureKey` | Traditional APIs |
| Auth in request body | `BodyKey` | Form-based APIs |

### Real-World Examples

**Example 1: Modern JSON API (like Stripe)**
```bash
{ConnectorName} → MyPayment
{connector_name} → my_payment
{AmountType} → MinorUnit
{content_type} → "application/json"
{api_endpoint} → "v1/payment_intents"
{Major|Minor} → Minor
Auth: HeaderKey
```

**Example 2: Legacy Form API (like PayU)**
```bash
{ConnectorName} → LegacyBank
{connector_name} → legacy_bank
{AmountType} → StringMajorUnit
{content_type} → "application/x-www-form-urlencoded"
{api_endpoint} → "api/process_payment"
{Major|Minor} → Major
Auth: BodyKey
```

**Example 3: Enterprise API (like Adyen)**
```bash
{ConnectorName} → EnterprisePay
{connector_name} → enterprise_pay
{AmountType} → StringMinorUnit
{content_type} → "application/json"
{api_endpoint} → "pal/servlet/Payment/v68/payments"
{Major|Minor} → Minor
Auth: SignatureKey
```

## Best Practices

1. **Use Modern Macro Pattern**: Prefer the macro-based implementation for consistency and reduced boilerplate
2. **Handle All Error Cases**: Implement comprehensive error handling for different response scenarios
3. **Generic Type Safety**: Always use proper generic type constraints for payment method data
4. **Status Mapping**: Carefully map connector statuses to standard statuses
5. **Amount Conversion**: Use appropriate amount converters based on connector requirements
6. **Testing**: Write comprehensive unit and integration tests
7. **Documentation**: Document any special requirements or limitations
8. **Security**: Never log sensitive data like card numbers or auth tokens
9. **Error Context**: Provide meaningful error messages with proper context
10. **Performance**: Minimize unnecessary data transformations and allocations

This pattern document provides a comprehensive template for implementing authorize flows in payment connectors, ensuring consistency and completeness across all implementations.
