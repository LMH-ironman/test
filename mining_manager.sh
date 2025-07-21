#!/bin/bash

# 统一挖矿监控管理脚本
# Unified Mining Monitor Management Script
# Author: DevOps Engineer
# Version: 3.0.0
# Description: All-in-one mining monitor with management capabilities

set -euo pipefail

# Version and help information
readonly SCRIPT_VERSION="3.0.0"
readonly SCRIPT_NAME="Mining Monitor Manager"

# Configuration
readonly XMR_API_URL="https://www.supportxmr.com/api/miner/45GkAa8FmTMWjeM1jCnH1r8psZWMBCi3vdmdrPqPCdDHRS4RZqb2Tnc55BqkUmuhd9KwvvhcoAVRqZMJVWe6wT3V32ZbN5W/stats"
readonly XTM_WALLET_ADDRESS="16meX2eiPWFAAU94fRF8u2DejfpQaV21a8bqYQviMDaSKfwuCgQJNAEauk9PTnx3jmKkTVuLXrgcbmXtAvtVUvn6K3BpkDjZeVnSuv1qMKY"
readonly XTM_API_URL="https://api-tari.luckypool.io/stats_address?address=${XTM_WALLET_ADDRESS}"
readonly XMR_PRICE_API_URL="https://www.xt.com/sapi/v4/market/public/ticker/24h?symbol=xmr_usdt"
readonly XTM_PRICE_API_URL="https://www.xt.com/sapi/v4/market/public/ticker/24h?symbol=xtm_usdt"

# Store environment variables before loading config file
_SAVED_LOG_FILE_PATH="${LOG_FILE_PATH:-}"
_SAVED_XMR_BALANCE_HISTORY_PATH="${XMR_BALANCE_HISTORY_PATH:-}"
_SAVED_XTM_BALANCE_HISTORY_PATH="${XTM_BALANCE_HISTORY_PATH:-}"
_SAVED_WECHAT_WEBHOOK_URL="${WECHAT_WEBHOOK_URL:-}"

# Load configuration from file if exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/mining_config.env"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Restore environment variables (environment variables take precedence)
[[ -n "$_SAVED_LOG_FILE_PATH" ]] && LOG_FILE_PATH="$_SAVED_LOG_FILE_PATH"
[[ -n "$_SAVED_XMR_BALANCE_HISTORY_PATH" ]] && XMR_BALANCE_HISTORY_PATH="$_SAVED_XMR_BALANCE_HISTORY_PATH"
[[ -n "$_SAVED_XTM_BALANCE_HISTORY_PATH" ]] && XTM_BALANCE_HISTORY_PATH="$_SAVED_XTM_BALANCE_HISTORY_PATH"
[[ -n "$_SAVED_WECHAT_WEBHOOK_URL" ]] && WECHAT_WEBHOOK_URL="$_SAVED_WECHAT_WEBHOOK_URL"

# Default paths
if [[ $EUID -eq 0 ]]; then
    # Root user defaults
    DEFAULT_LOG_DIR="/root/MINING"
    DEFAULT_LOG_FILE="$DEFAULT_LOG_DIR/mining_balance_monitor.log"
    DEFAULT_XMR_HISTORY="$DEFAULT_LOG_DIR/xmr_balance_history.txt"
    DEFAULT_XTM_HISTORY="$DEFAULT_LOG_DIR/xtm_balance_history.txt"
else
    # Non-root user defaults
    DEFAULT_LOG_DIR="$HOME/mining_logs"
    DEFAULT_LOG_FILE="$DEFAULT_LOG_DIR/mining_balance_monitor.log"
    DEFAULT_XMR_HISTORY="$DEFAULT_LOG_DIR/xmr_balance_history.txt"
    DEFAULT_XTM_HISTORY="$DEFAULT_LOG_DIR/xtm_balance_history.txt"
fi

# Configuration with defaults
readonly WECHAT_WEBHOOK_URL="${WECHAT_WEBHOOK_URL:-https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=3fc21e51-d7b7-46ca-9b86-f68deab4fd61}"
readonly LOG_FILE="${LOG_FILE_PATH:-$DEFAULT_LOG_FILE}"
readonly XMR_BALANCE_HISTORY_FILE="${XMR_BALANCE_HISTORY_PATH:-$DEFAULT_XMR_HISTORY}"
readonly XTM_BALANCE_HISTORY_FILE="${XTM_BALANCE_HISTORY_PATH:-$DEFAULT_XTM_HISTORY}"
readonly PID_FILE="$DEFAULT_LOG_DIR/mining_daemon.pid"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Global variables for balance data
export XMR_PAID_BALANCE=""
export XMR_DUE_BALANCE=""
export XMR_TOTAL_BALANCE=""
export XMR_BALANCE_GROWTH=""
export XMR_GROWTH_INT=""

export XTM_PAID_BALANCE=""
export XTM_UNLOCKED_BALANCE=""
export XTM_LOCKED_BALANCE=""
export XTM_TOTAL_BALANCE=""
export XTM_BALANCE_GROWTH=""

# Global variables for price data
export XMR_PRICE=""
export XTM_PRICE=""
export XMR_TOTAL_VALUE_USD=""
export XTM_TOTAL_VALUE_USD=""
export TOTAL_VALUE_USD=""

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Logging function
log_message() {
    local level="$1"
    shift
    local log_file="${LOG_FILE_PATH:-/tmp/mining_monitor.log}"
    local message="$(date '+%Y-%m-%d %H:%M:%S') [$level] $*"
    echo "$message"
    echo "$message" >> "$log_file" 2>/dev/null || true
}

# Error handling function
error_exit() {
    log_message "ERROR" "$1"
    exit 1
}

# Check dependencies
check_dependencies() {
    local dependencies=("curl" "bc" "jq")

    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            if [[ "$cmd" == "jq" ]]; then
                log_message "WARN" "$cmd is not installed. Installing..."
                if command -v apt-get &> /dev/null; then
                    sudo apt-get update && sudo apt-get install -y jq
                elif command -v yum &> /dev/null; then
                    sudo yum install -y jq
                else
                    error_exit "$cmd is required but not installed. Please install it manually."
                fi
            elif [[ "$cmd" == "bc" ]]; then
                log_message "WARN" "$cmd is not installed. Installing..."
                if command -v apt-get &> /dev/null; then
                    sudo apt-get update && sudo apt-get install -y bc
                elif command -v yum &> /dev/null; then
                    sudo yum install -y bc
                else
                    error_exit "$cmd is required but not installed. Please install it manually."
                fi
            else
                error_exit "$cmd is required but not installed. Please install it first."
            fi
        fi
    done
}

# Setup directories
setup_directories() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    mkdir -p "$(dirname "$XMR_BALANCE_HISTORY_FILE")" 2>/dev/null || true
    mkdir -p "$(dirname "$XTM_BALANCE_HISTORY_FILE")" 2>/dev/null || true
    mkdir -p "$(dirname "$PID_FILE")" 2>/dev/null || true
}

# =============================================================================
# MINING BALANCE FUNCTIONS
# =============================================================================

# Fetch XMR balance data from API
fetch_xmr_balance_data() {
    log_message "INFO" "Fetching XMR mining stats from API..."

    local response
    response=$(curl -s --connect-timeout 10 --max-time 30 "$XMR_API_URL" 2>/dev/null) || {
        log_message "ERROR" "Failed to fetch XMR data from API, using default values"
        echo '{"amtPaid": 0, "amtDue": 0}'
        return
    }

    # Check if response is empty
    if [[ -z "$response" ]]; then
        log_message "WARN" "Empty response from XMR API, using default values"
        echo '{"amtPaid": 0, "amtDue": 0}'
        return
    fi

    # Basic JSON validation
    if ! echo "$response" | jq empty 2>/dev/null; then
        log_message "WARN" "Invalid JSON response from XMR API: $response"
        log_message "WARN" "Using default values"
        echo '{"amtPaid": 0, "amtDue": 0}'
        return
    fi

    echo "$response"
}

# Fetch XTM balance data from API
fetch_xtm_balance_data() {
    log_message "INFO" "Fetching XTM mining stats from API..."

    local response
    response=$(curl -s --connect-timeout 15 --max-time 45 "$XTM_API_URL" 2>/dev/null) || {
        log_message "ERROR" "Failed to fetch XTM data from API"
        return 1
    }

    # Check if response is empty
    if [[ -z "$response" ]]; then
        log_message "WARN" "Empty response from XTM API"
        return 1
    fi

    # Check if response contains error
    if [[ "$response" == *"error"* ]] || [[ "$response" == *"Error"* ]]; then
        log_message "ERROR" "XTM API returned error: $response"
        return 1
    fi

    # Extract stats data
    local stats
    stats=$(echo "$response" | jq '.stats' 2>/dev/null)
    if [[ "$stats" == "null" ]] || [[ -z "$stats" ]]; then
        log_message "ERROR" "Unable to get XTM stats data from response: $response"
        return 1
    fi

    echo "$stats"
}

# Convert XMR raw value to decimal (divide by 1000000000000)
convert_xmr_to_decimal() {
    local raw_value="$1"

    # Handle zero or empty values
    if [[ -z "$raw_value" || "$raw_value" == "0" || "$raw_value" == "null" ]]; then
        echo "0.000000000000"
        return
    fi

    # 使用bash内置算术进行精确计算 (除以10^12)
    local integer_part=$((raw_value / 1000000000000))
    local decimal_part=$((raw_value % 1000000000000))

    # 格式化输出，确保小数部分有12位数字
    printf "%d.%012d" "$integer_part" "$decimal_part"
}

# Convert XTM raw value to decimal (divide by 1000000)
convert_xtm_to_decimal() {
    local raw_value="$1"

    # Handle zero or empty values
    if [[ -z "$raw_value" || "$raw_value" == "0" || "$raw_value" == "null" ]]; then
        echo "0.000000"
        return
    fi

    # 使用bc进行精确计算，去掉后6位相当于除以1000000
    echo "scale=6; $raw_value / 1000000" | bc
}

# Fetch XMR price from XT exchange
fetch_xmr_price() {
    local response
    response=$(curl -s --connect-timeout 10 --max-time 30 "$XMR_PRICE_API_URL" 2>/dev/null) || {
        log_message "ERROR" "Failed to fetch XMR price from API"
        echo "0"
        return
    }

    # Check if response is empty
    if [[ -z "$response" ]]; then
        log_message "WARN" "Empty response from XMR price API"
        echo "0"
        return
    fi

    # Extract price using jq
    local price
    price=$(echo "$response" | jq -r '.result[0].c // "0"' 2>/dev/null)
    
    # If jq fails, try regex extraction
    if [[ "$price" == "null" || -z "$price" || "$price" == "0" ]]; then
        price=$(echo "$response" | grep -o '"c":"[^"]*"' | sed 's/"c":"//g' | sed 's/"//g' | head -1)
        [[ -z "$price" ]] && price="0"
    fi

    # Clean and validate price format
    price=$(echo "$price" | sed 's/[^0-9.]//g')
    if [[ ! "$price" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        log_message "WARN" "Invalid XMR price format: $price"
        price="0"
    fi

    echo "$price"
}

# Fetch XTM price from XT exchange
fetch_xtm_price() {
    local response
    response=$(curl -s --connect-timeout 10 --max-time 30 "$XTM_PRICE_API_URL" 2>/dev/null) || {
        log_message "ERROR" "Failed to fetch XTM price from API"
        echo "0"
        return
    }

    # Check if response is empty
    if [[ -z "$response" ]]; then
        log_message "WARN" "Empty response from XTM price API"
        echo "0"
        return
    fi

    # Extract price using jq
    local price
    price=$(echo "$response" | jq -r '.result[0].c // "0"' 2>/dev/null)
    
    # If jq fails, try regex extraction
    if [[ "$price" == "null" || -z "$price" || "$price" == "0" ]]; then
        price=$(echo "$response" | grep -o '"c":"[^"]*"' | sed 's/"c":"//g' | sed 's/"//g' | head -1)
        [[ -z "$price" ]] && price="0"
    fi

    # Clean and validate price format
    price=$(echo "$price" | sed 's/[^0-9.]//g')
    if [[ ! "$price" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        log_message "WARN" "Invalid XTM price format: $price"
        price="0"
    fi

    echo "$price"
}

# Calculate USD values
calculate_usd_values() {
    log_message "INFO" "Calculating USD values..."

    # Calculate XMR value in USD
    if [[ -n "$XMR_TOTAL_BALANCE" && -n "$XMR_PRICE" && "$XMR_PRICE" != "0" ]]; then
        # Clean the values - extract only first valid number
        local clean_xmr_balance=$(echo "$XMR_TOTAL_BALANCE" | grep -o '^[0-9]*\.[0-9]*' | head -1)
        local clean_xmr_price=$(echo "$XMR_PRICE" | grep -o '^[0-9]*\.[0-9]*' | head -1)
        
        # Validate cleaned values
        if [[ -n "$clean_xmr_balance" && -n "$clean_xmr_price" ]]; then
            XMR_TOTAL_VALUE_USD=$(echo "scale=2; $clean_xmr_balance * $clean_xmr_price" | bc 2>/dev/null || echo "0.00")
            log_message "INFO" "XMR calculation: $clean_xmr_balance XMR * $clean_xmr_price USD = $XMR_TOTAL_VALUE_USD USD"
        else
            XMR_TOTAL_VALUE_USD="0.00"
            log_message "WARN" "XMR value cleaning failed - balance: '$clean_xmr_balance', price: '$clean_xmr_price'"
        fi
    else
        XMR_TOTAL_VALUE_USD="0.00"
        log_message "WARN" "Cannot calculate XMR USD value - missing price or balance data"
    fi

    # Calculate XTM value in USD
    if [[ -n "$XTM_TOTAL_BALANCE" && -n "$XTM_PRICE" && "$XTM_PRICE" != "0" ]]; then
        # Clean the values - extract only first valid number
        local clean_xtm_balance=$(echo "$XTM_TOTAL_BALANCE" | grep -o '^[0-9]*\.[0-9]*' | head -1)
        local clean_xtm_price=$(echo "$XTM_PRICE" | grep -o '^[0-9]*\.[0-9]*' | head -1)
        
        # Validate cleaned values
        if [[ -n "$clean_xtm_balance" && -n "$clean_xtm_price" ]]; then
            XTM_TOTAL_VALUE_USD=$(echo "scale=2; $clean_xtm_balance * $clean_xtm_price" | bc 2>/dev/null || echo "0.00")
            log_message "INFO" "XTM calculation: $clean_xtm_balance XTM * $clean_xtm_price USD = $XTM_TOTAL_VALUE_USD USD"
        else
            XTM_TOTAL_VALUE_USD="0.00"
            log_message "WARN" "XTM value cleaning failed - balance: '$clean_xtm_balance', price: '$clean_xtm_price'"
        fi
    else
        XTM_TOTAL_VALUE_USD="0.00"
        log_message "WARN" "Cannot calculate XTM USD value - missing price or balance data"
    fi

    # Calculate total value in USD
    local clean_xmr_value=$(echo "$XMR_TOTAL_VALUE_USD" | grep -o '^[0-9]*\.[0-9]*' | head -1)
    local clean_xtm_value=$(echo "$XTM_TOTAL_VALUE_USD" | grep -o '^[0-9]*\.[0-9]*' | head -1)
    
    # Set defaults if cleaning failed
    [[ -z "$clean_xmr_value" ]] && clean_xmr_value="0.00"
    [[ -z "$clean_xtm_value" ]] && clean_xtm_value="0.00"
    
    TOTAL_VALUE_USD=$(echo "scale=2; $clean_xmr_value + $clean_xtm_value" | bc 2>/dev/null || echo "0.00")
    log_message "INFO" "Total portfolio value: $clean_xmr_value + $clean_xtm_value = $TOTAL_VALUE_USD USD"

    # Export values
    export XMR_TOTAL_VALUE_USD
    export XTM_TOTAL_VALUE_USD
    export TOTAL_VALUE_USD
}

# Parse XMR balance data and calculate totals
parse_xmr_balance_data() {
    local json_data="$1"

    log_message "DEBUG" "Raw XMR JSON response: $json_data"

    local paid_raw
    local due_raw

    # 使用jq解析
    paid_raw=$(echo "$json_data" | jq -r '.amtPaid // 0' 2>/dev/null || echo "0")
    due_raw=$(echo "$json_data" | jq -r '.amtDue // 0' 2>/dev/null || echo "0")

    # 如果jq解析失败，使用正则表达式
    if [[ "$paid_raw" == "null" || "$paid_raw" == "0" ]]; then
        if [[ "$json_data" =~ \"amtPaid\":([0-9]+) ]]; then
            paid_raw="${BASH_REMATCH[1]}"
        fi
    fi

    if [[ "$due_raw" == "null" || "$due_raw" == "0" ]]; then
        if [[ "$json_data" =~ \"amtDue\":([0-9]+) ]]; then
            due_raw="${BASH_REMATCH[1]}"
        fi
    fi

    # 清理和验证数值
    paid_raw=$(echo "$paid_raw" | sed 's/[^0-9]//g' 2>/dev/null || echo "0")
    due_raw=$(echo "$due_raw" | sed 's/[^0-9]//g' 2>/dev/null || echo "0")

    # 设置默认值
    [[ -z "$paid_raw" ]] && paid_raw="0"
    [[ -z "$due_raw" ]] && due_raw="0"

    log_message "INFO" "XMR解析结果 - paid: $paid_raw, due: $due_raw"

    local paid_decimal
    local due_decimal
    local total_balance

    paid_decimal=$(convert_xmr_to_decimal "$paid_raw")
    due_decimal=$(convert_xmr_to_decimal "$due_raw")

    # 计算总余额
    local total_raw=$((paid_raw + due_raw))
    total_balance=$(convert_xmr_to_decimal "$total_raw")

    # Store current balance for growth calculation
    local history_file="$XMR_BALANCE_HISTORY_FILE"
    local previous_balance="0.000000000000"
    if [[ -f "$history_file" ]]; then
        previous_balance=$(tail -n 1 "$history_file" 2>/dev/null | awk '{print $NF}' || echo "0.000000000000")
        [[ -z "$previous_balance" ]] && previous_balance="0.000000000000"
    fi

    # Calculate growth
    local current_int=$(echo "$total_balance" | sed 's/\.//' | sed 's/^0*//')
    local previous_int=$(echo "$previous_balance" | sed 's/\.//' | sed 's/^0*//')

    [[ -z "$current_int" ]] && current_int="0"
    [[ -z "$previous_int" ]] && previous_int="0"

    local growth_int=$((current_int - previous_int))
    local balance_growth
    balance_growth=$(convert_xmr_to_decimal "$growth_int")

    # Save current balance to history
    mkdir -p "$(dirname "$history_file")" 2>/dev/null || true
    echo "$(date '+%Y-%m-%d %H:%M:%S') $total_balance" >> "$history_file" 2>/dev/null || true
    if [[ -f "$history_file" ]]; then
        tail -n 100 "$history_file" > "${history_file}.tmp" 2>/dev/null && mv "${history_file}.tmp" "$history_file" 2>/dev/null || true
    fi

    # Export values
    export XMR_PAID_BALANCE="$paid_decimal"
    export XMR_DUE_BALANCE="$due_decimal"
    export XMR_TOTAL_BALANCE="$total_balance"
    export XMR_BALANCE_GROWTH="$balance_growth"
    export XMR_GROWTH_INT="$growth_int"

    log_message "INFO" "Parsed XMR balance - Paid: $paid_decimal XMR, Due: $due_decimal XMR, Total: $total_balance XMR"
}

# Parse XTM balance data and calculate totals
parse_xtm_balance_data() {
    local json_data="$1"

    log_message "DEBUG" "Raw XTM JSON response: $json_data"

    # 提取三个关键值 - 使用字符串模式避免数字精度问题
    local paid_raw
    local unlocked_raw
    local locked_raw

    paid_raw=$(echo "$json_data" | jq -r '.paid // "0"' | sed 's/"//g')
    unlocked_raw=$(echo "$json_data" | jq -r '.unlocked // "0"' | sed 's/"//g')
    locked_raw=$(echo "$json_data" | jq -r '.locked // "0"' | sed 's/"//g')
    
    # 如果jq失败，使用正则表达式提取
    if [[ "$paid_raw" == "null" || -z "$paid_raw" ]]; then
        paid_raw=$(echo "$json_data" | grep -o '"paid":[^,}]*' | sed 's/"paid"://' | sed 's/[^0-9]//g')
        [[ -z "$paid_raw" ]] && paid_raw="0"
    fi
    
    if [[ "$unlocked_raw" == "null" || -z "$unlocked_raw" ]]; then
        unlocked_raw=$(echo "$json_data" | grep -o '"unlocked":[^,}]*' | sed 's/"unlocked"://' | sed 's/[^0-9]//g')
        [[ -z "$unlocked_raw" ]] && unlocked_raw="0"
    fi
    
    if [[ "$locked_raw" == "null" || -z "$locked_raw" ]]; then
        locked_raw=$(echo "$json_data" | grep -o '"locked":[^,}]*' | sed 's/"locked"://' | sed 's/[^0-9]//g')
        [[ -z "$locked_raw" ]] && locked_raw="0"
    fi

    log_message "INFO" "XTM原始数据 - Paid: $paid_raw, Unlocked: $unlocked_raw, Locked: $locked_raw"

    # 验证数据有效性
    if [[ ! "$paid_raw" =~ ^[0-9]+$ ]] || [[ ! "$unlocked_raw" =~ ^[0-9]+$ ]] || [[ ! "$locked_raw" =~ ^[0-9]+$ ]]; then
        log_message "ERROR" "XTM数据格式无效"
        return 1
    fi

    # 转换为小数
    local paid_decimal
    local unlocked_decimal
    local locked_decimal

    paid_decimal=$(convert_xtm_to_decimal "$paid_raw")
    unlocked_decimal=$(convert_xtm_to_decimal "$unlocked_raw")
    locked_decimal=$(convert_xtm_to_decimal "$locked_raw")

    # 计算总收益
    local total_balance
    total_balance=$(echo "scale=6; $paid_decimal + $unlocked_decimal + $locked_decimal" | bc)

    # 获取上次收益
    local history_file="$XTM_BALANCE_HISTORY_FILE"
    local previous_balance="0.000000"
    if [[ -f "$history_file" ]]; then
        previous_balance=$(tail -n 1 "$history_file" 2>/dev/null | awk '{print $NF}' || echo "0.000000")
        [[ -z "$previous_balance" ]] && previous_balance="0.000000"
    fi

    # 计算收益增长
    local balance_growth
    balance_growth=$(echo "scale=6; $total_balance - $previous_balance" | bc)

    # Save current balance to history
    mkdir -p "$(dirname "$history_file")" 2>/dev/null || true
    echo "$(date '+%Y-%m-%d %H:%M:%S') $total_balance" >> "$history_file" 2>/dev/null || true
    if [[ -f "$history_file" ]]; then
        tail -n 100 "$history_file" > "${history_file}.tmp" 2>/dev/null && mv "${history_file}.tmp" "$history_file" 2>/dev/null || true
    fi

    # Export values
    export XTM_PAID_BALANCE="$paid_decimal"
    export XTM_UNLOCKED_BALANCE="$unlocked_decimal"
    export XTM_LOCKED_BALANCE="$locked_decimal"
    export XTM_TOTAL_BALANCE="$total_balance"
    export XTM_BALANCE_GROWTH="$balance_growth"

    log_message "INFO" "Parsed XTM balance - Paid: $paid_decimal XTM, Unlocked: $unlocked_decimal XTM, Locked: $locked_decimal XTM, Total: $total_balance XTM"
}

# Format balance for display (remove trailing zeros)
format_balance() {
    local balance="$1"

    # 移除尾随零并清理格式
    local formatted
    formatted=$(echo "$balance" | sed 's/\.000000000000$//' | sed 's/\.000000$//' | sed 's/0*$//' | sed 's/\.$//')

    # 如果结果为空，返回0
    [[ -z "$formatted" ]] && formatted="0"

    echo "$formatted"
}

# Generate formatted alert message
generate_alert_message() {
    local current_time
    current_time=$(date '+%Y-%m-%d %H:%M:%S')

    # Format XMR balances
    local xmr_paid_formatted
    local xmr_due_formatted
    local xmr_total_formatted
    local xmr_growth_formatted

    if [[ -n "$XMR_PAID_BALANCE" ]]; then
        xmr_paid_formatted=$(format_balance "$XMR_PAID_BALANCE")
        xmr_due_formatted=$(format_balance "$XMR_DUE_BALANCE")
        xmr_total_formatted=$(format_balance "$XMR_TOTAL_BALANCE")
        xmr_growth_formatted=$(format_balance "$XMR_BALANCE_GROWTH")
    else
        xmr_paid_formatted="数据获取失败"
        xmr_due_formatted="数据获取失败"
        xmr_total_formatted="数据获取失败"
        xmr_growth_formatted="数据获取失败"
    fi

    # Format XTM balances
    local xtm_paid_formatted
    local xtm_unlocked_formatted
    local xtm_locked_formatted
    local xtm_total_formatted
    local xtm_growth_formatted

    if [[ -n "$XTM_PAID_BALANCE" ]]; then
        xtm_paid_formatted=$(format_balance "$XTM_PAID_BALANCE")
        xtm_unlocked_formatted=$(format_balance "$XTM_UNLOCKED_BALANCE")
        xtm_locked_formatted=$(format_balance "$XTM_LOCKED_BALANCE")
        xtm_total_formatted=$(format_balance "$XTM_TOTAL_BALANCE")
        xtm_growth_formatted=$(format_balance "$XTM_BALANCE_GROWTH")
    else
        xtm_paid_formatted="数据获取失败"
        xtm_unlocked_formatted="数据获取失败"
        xtm_locked_formatted="数据获取失败"
        xtm_total_formatted="数据获取失败"
        xtm_growth_formatted="数据获取失败"
    fi

    # Determine XMR growth indicator
    local xmr_growth_indicator=""
    if [[ -n "$XMR_GROWTH_INT" ]]; then
        if [[ "$XMR_GROWTH_INT" -gt 0 ]]; then
            xmr_growth_indicator="📈 +"
        elif [[ "$XMR_GROWTH_INT" -lt 0 ]]; then
            xmr_growth_indicator="📉 "
        else
            xmr_growth_indicator="➡️ "
        fi
    else
        xmr_growth_indicator="➡️ "
    fi

    # Determine XTM growth indicator
    local xtm_growth_indicator=""
    if [[ -n "$XTM_BALANCE_GROWTH" ]]; then
        if (( $(echo "$XTM_BALANCE_GROWTH > 0" | bc -l) )); then
            xtm_growth_indicator="📈 +"
        elif (( $(echo "$XTM_BALANCE_GROWTH < 0" | bc -l) )); then
            xtm_growth_indicator="📉 "
        else
            xtm_growth_indicator="➡️ "
        fi
    else
        xtm_growth_indicator="➡️ "
    fi

    # Format price and USD values
    local xmr_price_formatted=""
    local xtm_price_formatted=""
    local xmr_value_formatted=""
    local xtm_value_formatted=""
    local total_value_formatted=""

    if [[ -n "$XMR_PRICE" && "$XMR_PRICE" != "0" ]]; then
        # Extract only first valid number from price
        local clean_price=$(echo "$XMR_PRICE" | grep -o '^[0-9]*\.[0-9]*' | head -1)
        if [[ -n "$clean_price" ]]; then
            xmr_price_formatted=$(printf "%.2f" "$clean_price" 2>/dev/null || echo "获取失败")
        else
            xmr_price_formatted="获取失败"
        fi
        
        # Clean USD value display
        local clean_value=$(echo "$XMR_TOTAL_VALUE_USD" | grep -o '^[0-9]*\.[0-9]*' | head -1)
        if [[ -n "$clean_value" ]]; then
            xmr_value_formatted=$(printf "%.2f" "$clean_value" 2>/dev/null || echo "计算失败")
        else
            xmr_value_formatted="计算失败"
        fi
    else
        xmr_price_formatted="获取失败"
        xmr_value_formatted="计算失败"
    fi

    if [[ -n "$XTM_PRICE" && "$XTM_PRICE" != "0" ]]; then
        # Extract only first valid number from price
        local clean_price=$(echo "$XTM_PRICE" | grep -o '^[0-9]*\.[0-9]*' | head -1)
        if [[ -n "$clean_price" ]]; then
            xtm_price_formatted=$(printf "%.6f" "$clean_price" 2>/dev/null || echo "获取失败")
        else
            xtm_price_formatted="获取失败"
        fi
        
        # Clean USD value display  
        local clean_value=$(echo "$XTM_TOTAL_VALUE_USD" | grep -o '^[0-9]*\.[0-9]*' | head -1)
        if [[ -n "$clean_value" ]]; then
            xtm_value_formatted=$(printf "%.2f" "$clean_value" 2>/dev/null || echo "计算失败")
        else
            xtm_value_formatted="计算失败"
        fi
    else
        xtm_price_formatted="获取失败"
        xtm_value_formatted="计算失败"
    fi

    if [[ -n "$TOTAL_VALUE_USD" ]]; then
        # Clean total USD value display
        local clean_total=$(echo "$TOTAL_VALUE_USD" | grep -o '^[0-9]*\.[0-9]*' | head -1)
        if [[ -n "$clean_total" ]]; then
            total_value_formatted=$(printf "%.2f" "$clean_total" 2>/dev/null || echo "计算失败")
        else
            total_value_formatted="计算失败"
        fi
    else
        total_value_formatted="计算失败"
    fi

    cat << EOF
💰 挖矿收益报告

🪙 XMR 收益详情：
💰 已支付：${xmr_paid_formatted} XMR
⏳ 待支付：${xmr_due_formatted} XMR
💎 总收益：${xmr_total_formatted} XMR
📈 收益增长：${xmr_growth_indicator}${xmr_growth_formatted} XMR
💵 当前价格：${xmr_price_formatted} USDT
💲 总价值：${xmr_value_formatted} USD

🔶 XTM 收益详情：
💰 已付款：${xtm_paid_formatted} XTM
🔓 未锁定：${xtm_unlocked_formatted} XTM
🔒 已锁定：${xtm_locked_formatted} XTM
💎 总收益：${xtm_total_formatted} XTM
📈 收益增长：${xtm_growth_indicator}${xtm_growth_formatted} XTM
💵 当前价格：${xtm_price_formatted} USDT
💲 总价值：${xtm_value_formatted} USD

🏦 投资组合总览：
💲 总价值：${total_value_formatted} USD

📅 更新时间：${current_time}
🔗 数据来源：SupportXMR Pool & XTM LuckyPool & XT Exchange
EOF
}

# Send alert to WeChat webhook
send_wechat_alert() {
    if [[ -z "$WECHAT_WEBHOOK_URL" ]]; then
        log_message "WARN" "WeChat webhook URL not configured, skipping alert"
        return 0
    fi

    local message_text
    message_text=$(generate_alert_message)

    local payload
    payload=$(jq -n \
        --arg msgtype "text" \
        --arg content "$message_text" \
        '{
            "msgtype": $msgtype,
            "text": {
                "content": $content
            }
        }')

    log_message "INFO" "Sending alert to WeChat..."

    local response
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$WECHAT_WEBHOOK_URL" 2>/dev/null) || {
        log_message "ERROR" "Failed to send WeChat alert"
        return 1
    }

    if [[ "$response" == *'"errcode":0'* ]]; then
        log_message "INFO" "WeChat alert sent successfully"
    else
        log_message "ERROR" "WeChat alert failed: $response"
        return 1
    fi
}

# Display console output
display_console_output() {
    local message_text
    message_text=$(generate_alert_message)

    echo -e "${BLUE}================================${NC}"
    echo -e "${GREEN}$message_text${NC}"
    echo -e "${BLUE}================================${NC}"
}

# =============================================================================
# DAEMON MANAGEMENT FUNCTIONS
# =============================================================================

# Start daemon process
start_daemon() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "⚠️  挖矿监控守护进程已在运行 (PID: $(cat "$PID_FILE"))"
        return 1
    fi
    
    echo "🚀 启动挖矿监控守护进程..."
    
    # Start daemon process in background
    nohup bash -c "
        echo \"=== 挖矿收益监控守护进程启动 ===\" >> \"$LOG_FILE\"
        echo \"开始时间: \$(date)\" >> \"$LOG_FILE\"
        echo \"执行频率: 每5分钟\" >> \"$LOG_FILE\"
        echo \"脚本路径: $SCRIPT_DIR/$0\" >> \"$LOG_FILE\"
        echo \"\" >> \"$LOG_FILE\"
        
        run_count=0
        while true; do
            run_count=\$((run_count + 1))
            echo \"\$(date '+%Y-%m-%d %H:%M:%S') [DAEMON] 开始第 \$run_count 次执行\" >> \"$LOG_FILE\"
            
            if $0 monitor >> \"$LOG_FILE\" 2>&1; then
                echo \"\$(date '+%Y-%m-%d %H:%M:%S') [DAEMON] 第 \$run_count 次执行成功\" >> \"$LOG_FILE\"
            else
                echo \"\$(date '+%Y-%m-%d %H:%M:%S') [DAEMON] 第 \$run_count 次执行失败\" >> \"$LOG_FILE\"
            fi
            
            # Wait 5 minutes
            sleep 300
        done
    " > "$(dirname "$LOG_FILE")/daemon_output.log" 2>&1 &
    
    local daemon_pid=$!
    
    # Save PID
    echo "$daemon_pid" > "$PID_FILE"
    
    echo "✅ 守护进程已启动 (PID: $daemon_pid)"
    echo "📊 日志文件: $LOG_FILE"
    echo "🔍 查看日志: $0 logs"
    echo ""
    echo "💡 守护进程将每5分钟执行一次挖矿收益监控"
}

# Stop daemon process
stop_daemon() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo "⚠️  没有找到PID文件，守护进程可能未运行"
        return 1
    fi
    
    local pid=$(cat "$PID_FILE")
    
    if kill -0 "$pid" 2>/dev/null; then
        echo "🛑 停止挖矿监控守护进程 (PID: $pid)..."
        kill "$pid"
        
        # Wait for process to end
        sleep 2
        
        if kill -0 "$pid" 2>/dev/null; then
            echo "⚠️  进程未能正常结束，强制终止..."
            kill -9 "$pid"
        fi
        
        rm -f "$PID_FILE"
        echo "✅ 守护进程已停止"
    else
        echo "⚠️  进程 $pid 不存在，清理PID文件"
        rm -f "$PID_FILE"
    fi
}

# Show daemon status
show_daemon_status() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        local pid=$(cat "$PID_FILE")
        echo "✅ 挖矿监控守护进程正在运行"
        echo "   PID: $pid"
        echo "   启动时间: $(ps -o lstart= -p "$pid" 2>/dev/null || echo '未知')"
        echo "   日志文件: $LOG_FILE"
        
        if [[ -f "$LOG_FILE" ]]; then
            local last_run=$(tail -1 "$LOG_FILE" | grep -o '^[0-9-]* [0-9:]*' || echo '未知')
            echo "   最后执行: $last_run"
        fi
    else
        echo "❌ 挖矿监控守护进程未运行"
        if [[ -f "$PID_FILE" ]]; then
            rm -f "$PID_FILE"
        fi
    fi
}

# Show logs
show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        echo "📊 实时日志 (按 Ctrl+C 退出):"
        echo "----------------------------------------"
        tail -f "$LOG_FILE"
    else
        echo "❌ 日志文件不存在: $LOG_FILE"
    fi
}

# Restart daemon
restart_daemon() {
    echo "🔄 重启挖矿监控守护进程..."
    stop_daemon 2>/dev/null || true
    sleep 2
    start_daemon
}

# =============================================================================
# CRON SETUP FUNCTIONS
# =============================================================================

# Setup cron job
setup_cron() {
    local interval="${1:-5}"  # Default 5 minutes
    
    echo "=== 设置挖矿收益监控定时任务（每${interval}分钟） ==="

    # 确保脚本有执行权限
    chmod +x "$0"

    # 备份现有的crontab
    echo "💾 备份现有的crontab..."
    crontab -l > "/tmp/crontab_backup_$(date +%Y%m%d_%H%M%S).txt" 2>/dev/null || echo "   (当前无crontab任务)"

    # 生成新的cron任务
    local cron_job="*/${interval} * * * * $SCRIPT_DIR/$0 monitor >> $(dirname "$LOG_FILE")/cron_mining.log 2>&1"

    echo ""
    echo "📅 将添加的定时任务:"
    echo "   $cron_job"
    echo ""

    # 检查是否已存在相同的任务
    if crontab -l 2>/dev/null | grep -F "mining_manager.sh" > /dev/null; then
        echo "⚠️  检测到已存在的挖矿监控定时任务:"
        crontab -l | grep -F "mining_manager.sh"
        echo ""
        read -p "是否要替换现有任务? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ 用户取消操作"
            exit 0
        fi
        
        # 移除现有相关任务
        echo "🗑️  移除现有任务..."
        (crontab -l 2>/dev/null | grep -v "mining_manager.sh" || true) | crontab -
    fi

    # 添加新任务
    echo "➕ 添加新的定时任务..."
    (crontab -l 2>/dev/null || true; echo "$cron_job") | crontab -

    # 验证任务是否添加成功
    echo ""
    echo "✅ 定时任务设置完成！"
    echo ""
    echo "📋 当前的crontab任务:"
    crontab -l | grep -E "mining" || echo "   (未找到挖矿相关任务)"

    echo ""
    echo "📊 任务详情:"
    echo "   执行频率: 每${interval}分钟"
    echo "   脚本路径: $SCRIPT_DIR/$0"
    echo "   日志文件: $(dirname "$LOG_FILE")/cron_mining.log"
    echo "   配置文件: $CONFIG_FILE"
    echo ""
    echo "🔍 常用命令:"
    echo "   查看日志: tail -f $(dirname "$LOG_FILE")/cron_mining.log"
    echo "   查看定时: crontab -l"
    echo "   移除定时: crontab -e (手动删除对应行)"
    echo ""
    echo "⏱️  下次执行时间: 下一个${interval}分钟整点"

    # 显示当前时间和下次执行时间
    local current_minute=$(date +%M)
    local next_minute=$(( (current_minute / interval + 1) * interval ))
    if [ $next_minute -ge 60 ]; then
        next_minute=$(( next_minute - 60 ))
        local next_hour=$(( $(date +%H) + 1 ))
        if [ $next_hour -ge 24 ]; then
            next_hour=0
        fi
    else
        local next_hour=$(date +%H)
    fi

    echo "   当前时间: $(date '+%H:%M:%S')"
    printf "   下次执行: %02d:%02d:00\n" $next_hour $next_minute

    echo ""
    echo "🎉 设置完成！"
}

# =============================================================================
# TEST FUNCTIONS
# =============================================================================

# Test current setup
test_setup() {
    echo "=== 测试挖矿监控脚本配置 ==="
    echo ""

    # Check configuration file
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "✅ 配置文件存在: $CONFIG_FILE"
        echo ""
        echo "📄 配置文件内容:"
        cat "$CONFIG_FILE"
    else
        echo "⚠️  配置文件不存在: $CONFIG_FILE"
    fi

    echo ""
    echo "📋 当前配置信息:"

    # Show API configuration
    echo "  🔗 XMR API: SupportXMR"
    echo "  🔗 XTM API: LuckyPool"

    echo ""
    echo "🔍 测试脚本运行..."

    # Use temporary directory for testing
    local test_log="/tmp/mining_test_$(date +%s).log"
    local test_xmr_history="/tmp/xmr_history_test.txt"
    local test_xtm_history="/tmp/xtm_history_test.txt"

    echo "  日志文件: $test_log"
    echo "  XMR历史: $test_xmr_history"
    echo "  XTM历史: $test_xtm_history"

    # Run test with 30-second timeout
    echo ""
    echo "⏱️  开始测试运行（30秒超时）..."

    if timeout 30 LOG_FILE_PATH="$test_log" \
       XMR_BALANCE_HISTORY_PATH="$test_xmr_history" \
       XTM_BALANCE_HISTORY_PATH="$test_xtm_history" \
       "$0" monitor > /dev/null 2>&1; then
        
        echo "✅ 脚本运行成功！"
        
        # Show last few lines of log
        if [[ -f "$test_log" ]]; then
            echo ""
            echo "📊 运行日志（最后10行）:"
            tail -10 "$test_log" | sed 's/^/  /'
        fi
        
    else
        echo "❌ 脚本运行失败或超时"
        if [[ -f "$test_log" ]]; then
            echo ""
            echo "📊 错误日志:"
            tail -10 "$test_log" | sed 's/^/  /'
        fi
    fi

    # Clean up test files
    rm -f "$test_log" "$test_xmr_history" "$test_xtm_history"

    echo ""
    echo "🎯 下一步:"
    echo "   如果测试通过，运行以下命令设置5分钟定时任务:"
    echo "   $0 cron 5"
    echo ""
    echo "💡 手动设置定时任务:"
    echo "   crontab -e"
    echo "   添加行: */5 * * * * $SCRIPT_DIR/$0 monitor >> \$(dirname $LOG_FILE)/cron_mining.log 2>&1"
}

# Demo multi-pool functionality
demo_multi_pool() {
    echo "=== XTM 多池挖矿监控演示 ==="
    echo ""

    echo "📋 可用的XTM矿池配置选项:"
    echo "  1. BOTH       - 同时监控两个池 (推荐)"
    echo "  2. LUCKYPOOL  - 仅监控 LuckyPool"
    echo "  3. SUPPORTXMR - 仅监控 SupportXMR"
    echo ""

    echo "🔍 演示 1: 仅监控 SupportXMR 池"
    echo "命令: XTM_POOL=\"SUPPORTXMR\" $0 monitor"
    echo "特点: 显示已支付/待支付两层余额结构"
    echo ""
    read -p "按 Enter 键开始演示 1..." -r
    XTM_POOL="SUPPORTXMR" "$0" monitor
    echo ""
    echo "✅ 演示 1 完成"
    echo ""

    echo "🔍 演示 2: 仅监控 LuckyPool 池"
    echo "命令: XTM_POOL=\"LUCKYPOOL\" $0 monitor"
    echo "特点: 显示已付款/未锁定/已锁定三层余额结构"
    echo ""
    read -p "按 Enter 键开始演示 2..." -r
    XTM_POOL="LUCKYPOOL" "$0" monitor
    echo ""
    echo "✅ 演示 2 完成"
    echo ""

    echo "🔍 演示 3: 同时监控两个池 (推荐)"
    echo "命令: XTM_POOL=\"BOTH\" $0 monitor"
    echo "特点: 显示两个池的详细信息 + 总合计"
    echo ""
    read -p "按 Enter 键开始演示 3..." -r
    XTM_POOL="BOTH" "$0" monitor
    echo ""
    echo "✅ 演示 3 完成"
    echo ""

    echo "🎉 所有演示完成！"
    echo ""
    echo "💡 使用建议:"
    echo "  - 生产环境推荐使用 XTM_POOL=\"BOTH\" 获得完整收益视图"
    echo "  - 配置定时任务: $0 cron 30"
    echo "  - 配置微信机器人获得实时推送通知"
}

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

# Run monitor once
run_monitor() {
    setup_directories
    
    log_message "INFO" "Starting Mining Balance Monitor (XMR + XTM)..."

    # Check dependencies
    check_dependencies

    # Initialize success flags
    local xmr_success=false
    local xtm_success=false

    # Fetch and parse XMR balance data
    local xmr_balance_data
    xmr_balance_data=$(fetch_xmr_balance_data)
    if parse_xmr_balance_data "$xmr_balance_data"; then
        xmr_success=true
        log_message "INFO" "XMR data processing completed successfully"
    else
        log_message "ERROR" "XMR data processing failed"
    fi

    # Fetch and parse XTM balance data
    local xtm_balance_data
    if xtm_balance_data=$(fetch_xtm_balance_data); then
        if parse_xtm_balance_data "$xtm_balance_data"; then
            xtm_success=true
            log_message "INFO" "XTM data processing completed successfully"
        else
            log_message "ERROR" "XTM data processing failed"
        fi
    else
        log_message "ERROR" "XTM data fetching failed"
    fi

    # Fetch price data from XT exchange
    log_message "INFO" "Fetching cryptocurrency prices..."
    XMR_PRICE=$(fetch_xmr_price)
    XTM_PRICE=$(fetch_xtm_price)
    
    # Debug price fetching results
    log_message "DEBUG" "Fetched XMR_PRICE: '$XMR_PRICE'"
    log_message "DEBUG" "Fetched XTM_PRICE: '$XTM_PRICE'"
    
    # Export price variables
    export XMR_PRICE
    export XTM_PRICE

    # Calculate USD values if we have balance data
    if [[ "$xmr_success" == true ]] || [[ "$xtm_success" == true ]]; then
        calculate_usd_values
    fi

    # Only display output and send alerts if at least one currency succeeded
    if [[ "$xmr_success" == true ]] || [[ "$xtm_success" == true ]]; then
        # Display output
        display_console_output

        # Send WeChat alert if configured
        if [[ -n "$WECHAT_WEBHOOK_URL" ]]; then
            send_wechat_alert
        else
            log_message "INFO" "To enable WeChat alerts, set WECHAT_WEBHOOK_URL environment variable"
        fi

        log_message "INFO" "Mining balance monitor completed successfully"
    else
        log_message "ERROR" "Both XMR and XTM data processing failed"
        exit 1
    fi
}

# Show usage information
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

${SCRIPT_NAME} v${SCRIPT_VERSION}

COMMANDS:
    monitor              - 运行一次挖矿监控（默认命令）
    start               - 启动守护进程（每5分钟运行一次）
    stop                - 停止守护进程
    status              - 查看守护进程状态
    restart             - 重启守护进程
    logs                - 查看实时日志
    cron [INTERVAL]     - 设置定时任务 (默认5分钟)
    test                - 测试当前配置
    demo                - 演示多池功能
    -h, --help          - 显示此帮助信息
    -v, --version       - 显示版本信息

EXAMPLES:
    # 运行一次监控
    $0 monitor

    # 启动守护进程
    $0 start

    # 设置每5分钟的定时任务
    $0 cron 5

    # 设置每30分钟的定时任务
    $0 cron 30

    # 测试配置
    $0 test

    # 演示多池功能
    $0 demo

ENVIRONMENT VARIABLES:
    WECHAT_WEBHOOK_URL           - 微信机器人Webhook地址
    LOG_FILE_PATH               - 日志文件路径
    XMR_BALANCE_HISTORY_PATH    - XMR余额历史文件路径
    XTM_BALANCE_HISTORY_PATH    - XTM余额历史文件路径

CONFIGURATION:
    配置文件: $CONFIG_FILE
    日志文件: $LOG_FILE
    数据源: SupportXMR Pool & XTM LuckyPool & XT Exchange

DAEMON MANAGEMENT:
    PID文件: $PID_FILE
    日志目录: $(dirname "$LOG_FILE")

For more information, visit: https://github.com/your-repo/mining-monitor
EOF
}

# Show version information
show_version() {
    echo "${SCRIPT_NAME} v${SCRIPT_VERSION}"
    echo "Author: DevOps Engineer"
    echo "Description: All-in-one mining monitor with management capabilities"
}

# Main execution logic
main() {
    local command="${1:-monitor}"
    
    case "$command" in
        monitor)
            run_monitor
            ;;
        start)
            start_daemon
            ;;
        stop)
            stop_daemon
            ;;
        status)
            show_daemon_status
            ;;
        restart)
            restart_daemon
            ;;
        logs)
            show_logs
            ;;
        cron)
            local interval="${2:-5}"
            setup_cron "$interval"
            ;;
        test)
            test_setup
            ;;
        demo)
            demo_multi_pool
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        *)
            echo "Unknown command: $command"
            echo "Use '$0 --help' for usage information."
            exit 1
            ;;
    esac
}

# Trap for cleanup
trap 'log_message "INFO" "Script interrupted"' INT TERM

# Run main function
main "$@"