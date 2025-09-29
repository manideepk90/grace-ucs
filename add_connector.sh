#!/bin/bash

# =============================================================================
# Hyperswitch Connector Generator v2.0
# =============================================================================
# A robust, maintainable script for generating connector boilerplate code
#
# Usage: ./add_connector_v2.sh <connector_name> <base_url> [options]
#
# Features:
# - Modular design for easy maintenance
# - Comprehensive error handling and validation
# - Self-documenting configuration
# - Future-proof architecture
# =============================================================================

set -euo pipefail  # Strict error handling

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================
# All configurable values are centralized here for easy maintenance

# Script metadata
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="Hyperswitch Connector Generator"

# Paths configuration
readonly ROOT_DIR="$(pwd)"
readonly TEMPLATE_DIR="$ROOT_DIR/grace-ucs/template-generation"
readonly BACKEND_DIR="$ROOT_DIR/backend"
readonly CONFIG_DIR="$ROOT_DIR/config"

# File paths
readonly CONNECTOR_TYPES_FILE="$BACKEND_DIR/interfaces/src/connector_types.rs"
readonly DOMAIN_TYPES_FILE="$BACKEND_DIR/domain_types/src/connector_types.rs"
readonly INTEGRATION_TYPES_FILE="$BACKEND_DIR/connector-integration/src/types.rs"
readonly CONNECTORS_MODULE_FILE="$BACKEND_DIR/connector-integration/src/connectors.rs"
readonly PROTO_FILE="$BACKEND_DIR/grpc-api-types/proto/payment.proto"
readonly CONFIG_FILE="$CONFIG_DIR/development.toml"

# Template files
readonly CONNECTOR_TEMPLATE="$TEMPLATE_DIR/connector.rs.template"
readonly TRANSFORMERS_TEMPLATE="$TEMPLATE_DIR/transformers.rs.template"

# =============================================================================
# DYNAMIC FLOW DETECTION
# =============================================================================
# This script automatically detects all available flows from connector_types.rs
# When new flows are added to the ConnectorServiceTrait, they will be automatically
# included in new connector templates without any manual configuration needed.

# Global array to store detected flows
AVAILABLE_FLOWS=()

# =============================================================================
# FLOW DETECTION FUNCTIONS
# =============================================================================

detect_flows_from_connector_service_trait() {
    log_step "Auto-detecting flows from ConnectorServiceTrait"

    local connector_types_file="$CONNECTOR_TYPES_FILE"
    if [[ ! -f "$connector_types_file" ]]; then
        fatal_error "Cannot find connector_types.rs at: $connector_types_file"
    fi

    # Extract all trait names from ConnectorServiceTrait definition
    # This looks for lines like "+ PaymentAuthorizeV2<T>" or "+ PaymentSyncV2"
    local detected_flows
    detected_flows=$(grep -A 50 "pub trait ConnectorServiceTrait" "$connector_types_file" | \
                    grep -E "^\s*\+\s*[A-Z][A-Za-z0-9]*" | \
                    sed -E 's/^\s*\+\s*([A-Z][A-Za-z0-9]*).*/\1/' | \
                    grep -v "ConnectorCommon" | \
                    sort -u)

    if [[ -z "$detected_flows" ]]; then
        fatal_error "No flows detected from ConnectorServiceTrait"
    fi

    # Convert to array
    while IFS= read -r flow; do
        if [[ -n "$flow" ]]; then
            AVAILABLE_FLOWS+=("$flow")
        fi
    done <<< "$detected_flows"

    log_success "Detected ${#AVAILABLE_FLOWS[@]} flows from ConnectorServiceTrait"
    log_debug "Detected flows: ${AVAILABLE_FLOWS[*]}"
}

# Function to get basic description for any flow
get_flow_description() {
    case "$1" in
        *"Authorize"*) echo "Process payment authorization" ;;
        *"Sync"*) echo "Synchronize status" ;;
        *"Void"*) echo "Void/cancel operations" ;;
        *"Capture"*) echo "Capture authorized payments" ;;
        *"Refund"*) echo "Process refunds" ;;
        *"Mandate"*) echo "Setup recurring payment mandates" ;;
        *"Repeat"*) echo "Process recurring payments" ;;
        *"Order"*) echo "Create payment orders" ;;
        *"Token"*) echo "Handle tokenization" ;;
        *"Dispute"*) echo "Handle payment disputes" ;;
        *"Evidence"*) echo "Submit dispute evidence" ;;
        *"Webhook"*) echo "Handle incoming webhooks" ;;
        *"Validation"*) echo "Basic validation functionality" ;;
        *"Access"*) echo "Handle access tokens" ;;
        *"Session"*) echo "Handle session tokens" ;;
        *"Authenticate"*) echo "Handle authentication" ;;
        *) echo "Payment processing flow" ;;
    esac
}


# =============================================================================
# COLOR CONSTANTS
# =============================================================================

readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_PURPLE='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_RESET='\033[0m'

# =============================================================================
# GLOBAL VARIABLES
# =============================================================================

# User inputs
CONNECTOR_NAME=""
BASE_URL=""
FORCE_MODE=false
YES_MODE=false

# Auto-detected flows (populated by detect_flows_from_connector_service_trait)
SELECTED_FLOWS=()

# Generated values
NAME_SNAKE=""
NAME_PASCAL=""
NAME_UPPER=""
ENUM_ORDINAL=""
BACKUP_DIR=""

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Logging functions with consistent formatting
log_info() {
    echo -e "${COLOR_BLUE}ℹ️  INFO: $1${COLOR_RESET}"
}

log_success() {
    echo -e "${COLOR_GREEN}✅ SUCCESS: $1${COLOR_RESET}"
}

log_warning() {
    echo -e "${COLOR_YELLOW}⚠️  WARNING: $1${COLOR_RESET}"
}

log_error() {
    echo -e "${COLOR_RED}❌ ERROR: $1${COLOR_RESET}"
}

log_step() {
    echo -e "${COLOR_PURPLE}🔧 STEP: $1${COLOR_RESET}"
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${COLOR_CYAN}🐛 DEBUG: $1${COLOR_RESET}"
    fi
}

# Error handling with context
fatal_error() {
    log_error "$1"
    log_error "Script execution terminated."
    exit 1
}

# Validation helpers
validate_file_exists() {
    local file="$1"
    local description="$2"

    if [[ ! -f "$file" ]]; then
        fatal_error "$description not found at: $file"
    fi
    log_debug "Validated file exists: $file"
}

validate_directory_exists() {
    local dir="$1"
    local description="$2"

    if [[ ! -d "$dir" ]]; then
        fatal_error "$description not found at: $dir"
    fi
    log_debug "Validated directory exists: $dir"
}

# String manipulation utilities
to_snake_case() {
    echo "$1" | sed 's/\([A-Z]\)/_\1/g' | sed 's/^_//' | tr '[:upper:]' '[:lower:]'
}

to_pascal_case() {
    # Convert snake_case to PascalCase
    echo "$1" | awk -F'_' '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))} 1' OFS=''
}

to_upper_case() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# =============================================================================
# HELP AND USAGE FUNCTIONS
# =============================================================================

show_version() {
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
}

show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

USAGE:
    $0 <connector_name> <base_url> [OPTIONS]

ARGUMENTS:
    connector_name    Name of the connector (snake_case, e.g., 'my_connector')
    base_url         Base URL for the connector API

OPTIONS:
    --list-flows     Show auto-detected flows from codebase
    --force          Ignore git status and force creation
    -y, --yes        Skip confirmation prompts
    --debug          Enable debug logging
    -h, --help       Show this help message
    -v, --version    Show version information

EXAMPLES:
    # Create connector (automatically detects all flows)
    $0 stripe https://api.stripe.com/v1

    # Force creation with auto-confirmation
    $0 example https://api.example.com --force -y

    # List auto-detected flows
    $0 --list-flows

FEATURES:
    • Auto-detects all flows from ConnectorServiceTrait
    • Future-proof: automatically includes new flows when added to codebase
    • Creates empty implementations for all detected flows
    • No manual flow configuration required

WORKFLOW:
    1. Auto-detects flows from connector_types.rs
    2. Validates environment and inputs
    3. Generates connector boilerplate with all flows
    4. Updates integration files
    5. Validates compilation
    6. Provides next steps guidance

For more information, visit: https://github.com/juspay/hyperswitch
EOF
}

show_available_flows() {
    echo "Auto-Detected Flows from ConnectorServiceTrait:"
    echo "==============================================="
    echo

    # Auto-detect flows first
    detect_flows_from_connector_service_trait

    local flow
    for flow in "${AVAILABLE_FLOWS[@]}"; do
        local description=$(get_flow_description "$flow")
        printf "  %-25s %s\n" "$flow" "$description"
    done

    echo
    echo "NOTE: All flows are automatically included when creating a connector."
    echo "No manual selection is required - the script is future-proof!"
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

parse_arguments() {
    log_debug "Parsing arguments: $*"

    # Handle special cases first
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    if [[ $# -eq 1 ]]; then
        case "$1" in
            --list-flows)
                show_available_flows
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            *)
                log_error "Missing required arguments."
                show_help
                exit 1
                ;;
        esac
    fi

    # Parse required arguments
    if [[ $# -lt 2 ]]; then
        log_error "Missing required arguments: connector_name and base_url"
        show_help
        exit 1
    fi

    CONNECTOR_NAME="$1"
    BASE_URL="$2"
    shift 2

    # Parse optional arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                FORCE_MODE=true
                shift
                ;;
            -y|--yes)
                YES_MODE=true
                shift
                ;;
            --debug)
                DEBUG=true
                shift
                ;;
            --list-flows)
                show_available_flows
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            *)
                fatal_error "Unknown option: $1"
                ;;
        esac
    done

    log_debug "Arguments parsed successfully"
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_environment() {
    log_step "Validating environment"

    # Check if we're in the correct directory
    validate_directory_exists "$TEMPLATE_DIR" "Template directory"
    validate_directory_exists "$BACKEND_DIR" "Backend directory"

    # Check required template files
    validate_file_exists "$CONNECTOR_TEMPLATE" "Connector template"
    validate_file_exists "$TRANSFORMERS_TEMPLATE" "Transformers template"

    # Check target files that will be modified
    validate_file_exists "$CONNECTOR_TYPES_FILE" "Connector types file"
    validate_file_exists "$DOMAIN_TYPES_FILE" "Domain types file"
    validate_file_exists "$INTEGRATION_TYPES_FILE" "Integration types file"
    validate_file_exists "$CONNECTORS_MODULE_FILE" "Connectors module file"
    validate_file_exists "$PROTO_FILE" "Protocol buffer file"

    # Check git status unless forced
    if [[ "$FORCE_MODE" == "false" ]] && command -v git >/dev/null 2>&1; then
        if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
            fatal_error "Git working directory is not clean. Use --force to proceed anyway."
        fi
    fi

    log_success "Environment validation passed"
}

validate_inputs() {
    log_step "Validating inputs"

    # Validate connector name
    if [[ ! "$CONNECTOR_NAME" =~ ^[a-z][a-z0-9_]*$ ]]; then
        fatal_error "Connector name must start with a letter and contain only lowercase letters, numbers, and underscores"
    fi

    # Validate base URL
    if [[ ! "$BASE_URL" =~ ^https?://.+ ]]; then
        fatal_error "Base URL must be a valid HTTP/HTTPS URL"
    fi

    # Generate name variants
    NAME_SNAKE="$CONNECTOR_NAME"
    NAME_PASCAL=$(to_pascal_case "$CONNECTOR_NAME")
    NAME_UPPER=$(to_upper_case "$CONNECTOR_NAME")

    # Auto-detect flows from codebase
    detect_flows_from_connector_service_trait

    # Always use all detected flows (no manual selection)
    SELECTED_FLOWS=("${AVAILABLE_FLOWS[@]}")

    log_success "Input validation passed"
    log_info "Configuration: $NAME_SNAKE → $NAME_PASCAL"
    log_info "Base URL: $BASE_URL"
    log_info "Auto-detected ${#SELECTED_FLOWS[@]} flows: ${SELECTED_FLOWS[*]}"
}

check_naming_conflicts() {
    log_step "Checking for naming conflicts"

    # Check if connector files already exist
    local connector_file="$BACKEND_DIR/connector-integration/src/connectors/$NAME_SNAKE.rs"
    local connector_dir="$BACKEND_DIR/connector-integration/src/connectors/$NAME_SNAKE"

    if [[ -f "$connector_file" ]] || [[ -d "$connector_dir" ]]; then
        fatal_error "Connector '$NAME_SNAKE' already exists"
    fi

    # Check protobuf enum
    if grep -q "$NAME_UPPER =" "$PROTO_FILE" 2>/dev/null; then
        fatal_error "Connector '$NAME_UPPER' already exists in protobuf enum"
    fi

    # Check domain types
    if grep -q "$NAME_PASCAL" "$DOMAIN_TYPES_FILE" 2>/dev/null; then
        fatal_error "Connector '$NAME_PASCAL' already exists in domain types"
    fi

    log_success "No naming conflicts found"
}

# =============================================================================
# CORE GENERATION FUNCTIONS
# =============================================================================

get_next_enum_ordinal() {
    log_step "Determining next enum ordinal"

    if [[ -f "$PROTO_FILE" ]]; then
        # Extract the highest ordinal from Connector enum
        local max_ordinal
        max_ordinal=$(sed -n '/^enum Connector {/,/^}/p' "$PROTO_FILE" | \
                     grep -o '= [0-9]\+;' | \
                     grep -o '[0-9]\+' | \
                     sort -n | \
                     tail -1)

        if [[ -n "$max_ordinal" ]]; then
            ENUM_ORDINAL=$((max_ordinal + 1))
        else
            ENUM_ORDINAL=100
        fi
    else
        ENUM_ORDINAL=100
    fi

    log_debug "Next enum ordinal: $ENUM_ORDINAL"
}

create_backup() {
    log_step "Creating backup"

    BACKUP_DIR="$ROOT_DIR/.connector_backup_$(date +%s)"
    mkdir -p "$BACKUP_DIR"

    local files_to_backup=(
        "$PROTO_FILE"
        "$DOMAIN_TYPES_FILE"
        "$CONNECTORS_MODULE_FILE"
        "$INTEGRATION_TYPES_FILE"
        "$CONFIG_FILE"
    )

    local file
    for file in "${files_to_backup[@]}"; do
        if [[ -f "$file" ]]; then
            cp "$file" "$BACKUP_DIR/$(basename "$file")"
            log_debug "Backed up: $(basename "$file")"
        fi
    done

    log_success "Backup created at: $BACKUP_DIR"
}

substitute_template_variables() {
    local input_file="$1"
    local output_file="$2"

    log_debug "Substituting variables in template: $(basename "$input_file")"

    sed -e "s/{{CONNECTOR_NAME_PASCAL}}/$NAME_PASCAL/g" \
        -e "s/{{CONNECTOR_NAME_SNAKE}}/$NAME_SNAKE/g" \
        -e "s/{{CONNECTOR_NAME_UPPER}}/$NAME_UPPER/g" \
        -e "s|{{BASE_URL}}|$BASE_URL|g" \
        "$input_file" > "$output_file"
}

create_connector_files() {
    log_step "Creating connector files"

    local connectors_dir="$BACKEND_DIR/connector-integration/src/connectors"
    local connector_subdir="$connectors_dir/$NAME_SNAKE"

    # Create main connector file
    substitute_template_variables "$CONNECTOR_TEMPLATE" "$connectors_dir/$NAME_SNAKE.rs"

    # Create connector subdirectory and transformers file
    mkdir -p "$connector_subdir"
    substitute_template_variables "$TRANSFORMERS_TEMPLATE" "$connector_subdir/transformers.rs"

    log_success "Created connector files"
}

# =============================================================================
# FILE UPDATE FUNCTIONS
# =============================================================================

update_protobuf() {
    log_step "Updating protobuf definitions"

    # Add new connector to enum before closing brace
    sed -i.bak "/enum Connector {/,/}/ s/}/  $NAME_UPPER = $ENUM_ORDINAL;\n}/" "$PROTO_FILE"
    rm -f "$PROTO_FILE.bak"

    log_success "Updated protobuf with $NAME_UPPER = $ENUM_ORDINAL"
}

update_domain_types() {
    log_step "Updating domain types"

    # Add to ConnectorEnum
    sed -i.bak "/pub enum ConnectorEnum {/,/}/ s/}/    $NAME_PASCAL,\\n}/" "$DOMAIN_TYPES_FILE"

    # Add to gRPC mapping - find the line with "Unspecified =>" and add before it
    sed -i.bak "/grpc_api_types::payments::Connector::Unspecified =>/ i\\
            grpc_api_types::payments::Connector::$NAME_PASCAL => Ok(Self::$NAME_PASCAL)," "$DOMAIN_TYPES_FILE"

    rm -f "$DOMAIN_TYPES_FILE.bak"

    log_success "Updated domain types with $NAME_PASCAL"
}

update_connectors_module() {
    log_step "Updating connectors module"

    # Add module declaration and use statement
    cat >> "$CONNECTORS_MODULE_FILE" << EOF

pub mod $NAME_SNAKE;
pub use self::${NAME_SNAKE}::${NAME_PASCAL};
EOF

    log_success "Updated connectors module"
}

update_integration_types() {
    log_step "Updating integration types"

    # Add import to use statement
    sed -i.bak "/use crate::connectors::{/,/};/ s/Xendit,/Xendit, $NAME_PASCAL,/" "$INTEGRATION_TYPES_FILE"

    # Add enum mapping
    sed -i.bak "/ConnectorEnum::Helcim => Box::new(Helcim::new()),/a\\
            ConnectorEnum::$NAME_PASCAL => Box::new($NAME_PASCAL::new())," "$INTEGRATION_TYPES_FILE"

    rm -f "$INTEGRATION_TYPES_FILE.bak"

    log_success "Updated integration types with $NAME_PASCAL mapping"
}

update_config() {
    log_step "Updating configuration"

    if [[ -f "$CONFIG_FILE" ]]; then
        # Add connector configuration
        echo "" >> "$CONFIG_FILE"
        echo "# $NAME_PASCAL connector configuration" >> "$CONFIG_FILE"
        echo "$NAME_SNAKE.base_url = \"$BASE_URL\"" >> "$CONFIG_FILE"

        log_success "Updated configuration"
    else
        log_warning "Configuration file not found, skipping config update"
    fi
}

# =============================================================================
# VALIDATION AND CLEANUP
# =============================================================================

format_code() {
    log_step "Formatting code"

    if command -v cargo >/dev/null 2>&1; then
        if cargo +nightly fmt --all >/dev/null 2>&1; then
            log_success "Code formatted with nightly rustfmt"
        elif cargo fmt --all >/dev/null 2>&1; then
            log_success "Code formatted with stable rustfmt"
        else
            log_warning "Code formatting failed"
        fi
    else
        log_warning "Cargo not found, skipping code formatting"
    fi
}

validate_compilation() {
    log_step "Validating compilation"

    if command -v cargo >/dev/null 2>&1; then
        log_info "Running cargo check..."

        if cargo check 2>&1; then
            log_success "Compilation validation passed"
            return 0
        else
            log_error "Compilation validation failed"
            return 1
        fi
    else
        log_warning "Cargo not found, skipping compilation validation"
        return 0
    fi
}

cleanup_backup() {
    if [[ -n "$BACKUP_DIR" ]] && [[ -d "$BACKUP_DIR" ]]; then
        rm -rf "$BACKUP_DIR"
        log_debug "Cleaned up backup directory"
    fi
}

emergency_rollback() {
    log_step "Performing emergency rollback"

    if [[ -n "$BACKUP_DIR" ]] && [[ -d "$BACKUP_DIR" ]]; then
        # Remove created files
        rm -f "$BACKEND_DIR/connector-integration/src/connectors/$NAME_SNAKE.rs"
        rm -rf "$BACKEND_DIR/connector-integration/src/connectors/$NAME_SNAKE"

        # Restore backed up files
        local backup_file
        for backup_file in "$BACKUP_DIR"/*; do
            if [[ -f "$backup_file" ]]; then
                local filename
                filename=$(basename "$backup_file")
                case "$filename" in
                    "payment.proto")
                        cp "$backup_file" "$PROTO_FILE"
                        ;;
                    "connector_types.rs")
                        cp "$backup_file" "$DOMAIN_TYPES_FILE"
                        ;;
                    "connectors.rs")
                        cp "$backup_file" "$CONNECTORS_MODULE_FILE"
                        ;;
                    "types.rs")
                        cp "$backup_file" "$INTEGRATION_TYPES_FILE"
                        ;;
                    "development.toml")
                        cp "$backup_file" "$CONFIG_FILE"
                        ;;
                esac
            fi
        done

        rm -rf "$BACKUP_DIR"
        log_success "Emergency rollback completed"
    else
        log_warning "No backup found for rollback"
    fi
}

# =============================================================================
# USER INTERACTION
# =============================================================================

show_implementation_plan() {
    if [[ "$YES_MODE" == "true" ]]; then
        return 0
    fi

    echo
    log_step "Implementation Plan"
    echo "====================="
    echo
    echo "📁 Files to create:"
    echo "   ├── backend/connector-integration/src/connectors/$NAME_SNAKE.rs"
    echo "   └── backend/connector-integration/src/connectors/$NAME_SNAKE/transformers.rs"
    echo
    echo "📝 Files to modify:"
    echo "   ├── backend/grpc-api-types/proto/payment.proto"
    echo "   ├── backend/domain_types/src/connector_types.rs"
    echo "   ├── backend/connector-integration/src/connectors.rs"
    echo "   ├── backend/connector-integration/src/types.rs"
    echo "   └── config/development.toml"
    echo
    echo "🎯 Configuration:"
    echo "   ├── Connector: $NAME_PASCAL"
    echo "   ├── Enum ordinal: $ENUM_ORDINAL"
    echo "   ├── Base URL: $BASE_URL"
    echo "   └── Flows: ${SELECTED_FLOWS[*]}"
    echo

    read -p "❓ Proceed with implementation? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "Implementation cancelled by user"
        exit 1
    fi
}

show_next_steps() {
    echo
    log_success "Connector '$NAME_SNAKE' successfully created!"
    echo
    log_step "Next Steps"
    echo "============"
    echo
    echo "1️⃣  Implement Core Logic:"
    echo "   📁 Edit: backend/connector-integration/src/connectors/$NAME_SNAKE/transformers.rs"
    echo "      • Update request/response structures for your API"
    echo "      • Implement proper field mappings"
    echo "      • Handle authentication requirements"
    echo
    echo "2️⃣  Customize Connector:"
    echo "   📁 Edit: backend/connector-integration/src/connectors/$NAME_SNAKE.rs"
    echo "      • Update URL patterns and endpoints"
    echo "      • Implement error handling"
    echo "      • Add connector-specific logic"
    echo
    echo "3️⃣  Validation Commands:"
    echo "   📋 Check compilation: cargo check --package connector-integration"
    echo "   📋 Run tests: cargo test --package connector-integration"
    echo "   📋 Build: cargo build --package connector-integration"
    echo
    log_success "Connector '$NAME_PASCAL' is ready for implementation!"
}

# =============================================================================
# MAIN EXECUTION FLOW
# =============================================================================

main() {
    # Print header
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
    echo "======================================="
    echo

    # Set up error handling
    trap 'emergency_rollback; exit 1' ERR

    # Core execution flow
    parse_arguments "$@"
    validate_environment
    validate_inputs
    check_naming_conflicts
    get_next_enum_ordinal

    # Show implementation plan and get confirmation
    show_implementation_plan

    # Create backup for safety
    create_backup

    # Execute main operations
    create_connector_files
    update_protobuf
    update_domain_types
    update_connectors_module
    update_integration_types
    update_config

    # Validate and finalize
    format_code
    if ! validate_compilation; then
        emergency_rollback
        exit 1
    fi

    # Success cleanup and guidance
    cleanup_backup
    show_next_steps
}

# Execute main function with all arguments
main "$@"