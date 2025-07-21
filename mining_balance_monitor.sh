#!/bin/bash

# Mining Balance Monitor Script (XMR + XTM)
# Author: DevOps Engineer
# Description: Monitor XMR and XTM mining balance and send formatted alerts to WeChat Robot

set -euo pipefail

# Store environment variables before loading config file (if they exist)
_SAVED_LOG_FILE_PATH="${LOG_FILE_PATH:-}"
_SAVED_XMR_BALANCE_HISTORY_PATH="${XMR_BALANCE_HISTORY_PATH:-}"
_SAVED_XTM_BALANCE_HISTORY_PATH="${XTM_BALANCE_HISTORY_PATH:-}"
_SAVED_WECHAT_WEBHOOK_URL="${WECHAT_WEBHOOK_URL:-}"
_SAVED_XTM_POOL="${XTM_POOL:-}"

# Load configuration from file if exists
CONFIG_FILE="$(dirname "$0")/mining_config.env"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Restore environment variables (environment variables take precedence)
[[ -n "$_SAVED_LOG_FILE_PATH" ]] && LOG_FILE_PATH="$_SAVED_LOG_FILE_PATH"
[[ -n "$_SAVED_XMR_BALANCE_HISTORY_PATH" ]] && XMR_BALANCE_HISTORY_PATH="$_SAVED_XMR_BALANCE_HISTORY_PATH"
[[ -n "$_SAVED_XTM_BALANCE_HISTORY_PATH" ]] && XTM_BALANCE_HISTORY_PATH="$_SAVED_XTM_BALANCE_HISTORY_PATH"
[[ -n "$_SAVED_WECHAT_WEBHOOK_URL" ]] && WECHAT_WEBHOOK_URL="$_SAVED_WECHAT_WEBHOOK_URL"
[[ -n "$_SAVED_XTM_POOL" ]] && XTM_POOL="$_SAVED_XTM_POOL"

# Configuration
readonly XMR_API_URL="https://www.supportxmr.com/api/miner/45GkAa8FmTMWjeM1jCnH1r8psZWMBCi3vdmdrPqPCdDHRS4RZqb2Tnc55BqkUmuhd9KwvvhcoAVRqZMJVWe6wT3V32ZbN5W/stats"

# XTM Mining Pool Configurations
readonly XTM_LUCKYPOOL_WALLET_ADDRESS="16meX2eiPWFAAU94fRF8u2DejfpQaV21a8bqYQviMDaSKfwuCgQJNAEauk9PTnx3jmKkTVuLXrgcbmXtAvtVUvn6K3BpkDjZeVnSuv1qMKY"
readonly XTM_LUCKYPOOL_API_URL="https://api-tari.luckypool.io/stats_address?address=${XTM_LUCKYPOOL_WALLET_ADDRESS}"
readonly XTM_SUPPORTXMR_WALLET_ADDRESS="47jSCEJCzjWVmxJiD4HvjY3dtDqaUjGxv9hKSJ2Lxce8RofZkLioFXpbbX9mfFRv5nev4gbVNCGzkP9UUH1shxCAEBUXsmr"
readonly XTM_SUPPORTXMR_API_URL="https://www.supportxmr.com/api/tari/balance/${XTM_SUPPORTXMR_WALLET_ADDRESS}"

# XTM Pool selection (LUCKYPOOL or SUPPORTXMR) - can be overridden by environment variable
readonly XTM_POOL="${XTM_POOL:-BOTH}"

# Price API URLs
readonly XMR_PRICE_API_URL="https://www.xt.com/sapi/v4/market/public/ticker/24h?symbol=xmr_usdt"
readonly XTM_PRICE_API_URL="https://www.xt.com/sapi/v4/market/public/ticker/24h?symbol=xtm_usdt"

# 微信机器人webhook地址 - 优先级：环境变量 > 配置文件 > 默认值
readonly WECHAT_WEBHOOK_URL="${WECHAT_WEBHOOK_URL:-https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=3fc21e51-d7b7-46ca-9b86-f68deab4fd61}"
readonly LOG_FILE="${LOG_FILE_PATH:-/root/MINING/mining_balance_monitor.log}"
readonly XMR_BALANCE_HISTORY_FILE="${XMR_BALANCE_HISTORY_PATH:-/root/MINING/xmr_balance_history.txt}"
readonly XTM_BALANCE_HISTORY_FILE="${XTM_BALANCE_HISTORY_PATH:-/root/MINING/xtm_balance_history.txt}"

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

# XTM balance variables for multiple pools
export XTM_LUCKYPOOL_PAID_BALANCE=""
export XTM_LUCKYPOOL_UNLOCKED_BALANCE=""
export XTM_LUCKYPOOL_LOCKED_BALANCE=""
export XTM_LUCKYPOOL_TOTAL_BALANCE=""

export XTM_SUPPORTXMR_PAID_BALANCE=""
export XTM_SUPPORTXMR_PENDING_BALANCE=""
export XTM_SUPPORTXMR_TOTAL_BALANCE=""

export XTM_TOTAL_BALANCE=""
export XTM_BALANCE_GROWTH=""

# Global variables for price data
export XMR_PRICE=""
export XTM_PRICE=""
export XMR_TOTAL_VALUE_USD=""
export XTM_TOTAL_VALUE_USD=""
export TOTAL_VALUE_USD=""

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

# Fetch XTM balance data from LuckyPool API
fetch_xtm_luckypool_balance_data() {
    log_message "INFO" "Fetching XTM mining stats from LuckyPool API..."

    local response
    response=$(curl -s --connect-timeout 15 --max-time 45 "$XTM_LUCKYPOOL_API_URL" 2>/dev/null) || {
        log_message "ERROR" "Failed to fetch XTM data from LuckyPool API"
        return 1
    }

    # Check if response is empty
    if [[ -z "$response" ]]; then
        log_message "WARN" "Empty response from LuckyPool XTM API"
        return 1
    fi

    # Check if response contains error
    if [[ "$response" == *"error"* ]] || [[ "$response" == *"Error"* ]]; then
        log_message "ERROR" "LuckyPool XTM API returned error: $response"
        return 1
    fi

    # Extract stats data
    local stats
    stats=$(echo "$response" | jq '.stats' 2>/dev/null)
    if [[ "$stats" == "null" ]] || [[ -z "$stats" ]]; then
        log_message "ERROR" "Unable to get XTM stats data from LuckyPool response: $response"
        return 1
    fi

    echo "$stats"
}

# Fetch XTM balance data from SupportXMR API
fetch_xtm_supportxmr_balance_data() {
    log_message "INFO" "Fetching XTM balance from SupportXMR API..."

    local response
    response=$(curl -s --connect-timeout 10 --max-time 30 "$XTM_SUPPORTXMR_API_URL" 2>/dev/null) || {
        log_message "WARN" "SupportXMR XTM API request failed, using default values"
        echo '{"paid": 0, "pending": 0}'
        return
    }

    # Check if response is empty
    if [[ -z "$response" ]]; then
        log_message "WARN" "SupportXMR XTM API returned empty data, using default values"
        echo '{"paid": 0, "pending": 0}'
        return
    fi

    # Validate JSON format
    if ! echo "$response" | jq empty 2>/dev/null; then
        log_message "WARN" "SupportXMR XTM API returned non-JSON data, using default values"
        echo '{"paid": 0, "pending": 0}'
        return
    fi

    echo "$response"
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
    local history_file="${XMR_BALANCE_HISTORY_PATH:-/root/MINING/xmr_balance_history.txt}"
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

# Parse XTM LuckyPool balance data and calculate totals
parse_xtm_luckypool_balance_data() {
    local json_data="$1"

    log_message "DEBUG" "Raw LuckyPool XTM JSON response: $json_data"

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

    log_message "INFO" "LuckyPool XTM原始数据 - Paid: $paid_raw, Unlocked: $unlocked_raw, Locked: $locked_raw"

    # 验证数据有效性
    if [[ ! "$paid_raw" =~ ^[0-9]+$ ]] || [[ ! "$unlocked_raw" =~ ^[0-9]+$ ]] || [[ ! "$locked_raw" =~ ^[0-9]+$ ]]; then
        log_message "ERROR" "LuckyPool XTM数据格式无效"
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

    # Export values
    export XTM_LUCKYPOOL_PAID_BALANCE="$paid_decimal"
    export XTM_LUCKYPOOL_UNLOCKED_BALANCE="$unlocked_decimal"
    export XTM_LUCKYPOOL_LOCKED_BALANCE="$locked_decimal"
    export XTM_LUCKYPOOL_TOTAL_BALANCE="$total_balance"

    log_message "INFO" "Parsed LuckyPool XTM balance - Paid: $paid_decimal XTM, Unlocked: $unlocked_decimal XTM, Locked: $locked_decimal XTM, Total: $total_balance XTM"
}

# Parse XTM SupportXMR balance data using SupportXMR API format
parse_xtm_supportxmr_balance_data() {
    local json_data="$1"
    log_message "DEBUG" "Raw SupportXMR XTM JSON response: $json_data"
    
    local paid_raw="" pending_raw=""
    
    # Method 1: Use jq for parsing (preferred)
    if command -v jq &> /dev/null; then
        paid_raw=$(echo "$json_data" | jq -r '.paid // 0' 2>/dev/null || echo "")
        pending_raw=$(echo "$json_data" | jq -r '.pending // 0' 2>/dev/null || echo "")
        log_message "DEBUG" "SupportXMR jq parsing result - paid_raw: $paid_raw, pending_raw: $pending_raw"
    fi
    
    # Method 2: Regex fallback (if jq parsing fails)
    if [[ -z "$paid_raw" || "$paid_raw" == "null" ]]; then
        if [[ "$json_data" =~ \"paid\":([0-9]+) ]]; then
            paid_raw="${BASH_REMATCH[1]}"
            log_message "DEBUG" "SupportXMR regex parsing paid: $paid_raw"
        fi
    fi
    if [[ -z "$pending_raw" || "$pending_raw" == "null" ]]; then
        if [[ "$json_data" =~ \"pending\":([0-9]+) ]]; then
            pending_raw="${BASH_REMATCH[1]}"
            log_message "DEBUG" "SupportXMR regex parsing pending: $pending_raw"
        fi
    fi
    
    # Clean and validate values
    paid_raw=$(echo "$paid_raw" | sed 's/[^0-9]//g' || echo "0")
    pending_raw=$(echo "$pending_raw" | sed 's/[^0-9]//g' || echo "0")
    
    # Set defaults
    [[ -z "$paid_raw" ]] && paid_raw="0"
    [[ -z "$pending_raw" ]] && pending_raw="0"
    
    log_message "INFO" "SupportXMR XTM parsing result - paid_raw: $paid_raw, pending_raw: $pending_raw"
    
    # Convert to readable format (divide by 1000000, keep 6 decimal places)
    local paid_decimal=$(printf "%d.%06d" "$((paid_raw / 1000000))" "$((paid_raw % 1000000))")
    local pending_decimal=$(printf "%d.%06d" "$((pending_raw / 1000000))" "$((pending_raw % 1000000))")
    local total_raw=$((paid_raw + pending_raw))
    local total_decimal=$(printf "%d.%06d" "$((total_raw / 1000000))" "$((total_raw % 1000000))")
    
    # Export values
    export XTM_SUPPORTXMR_PAID_BALANCE="$paid_decimal"
    export XTM_SUPPORTXMR_PENDING_BALANCE="$pending_decimal"
    export XTM_SUPPORTXMR_TOTAL_BALANCE="$total_decimal"
    
    log_message "INFO" "Parsed SupportXMR XTM balance - Paid: $paid_decimal XTM, Pending: $pending_decimal XTM, Total: $total_decimal XTM"
}

# Aggregate XTM balance data from multiple pools and calculate growth
aggregate_xtm_balance_data() {
    local luckypool_total="${XTM_LUCKYPOOL_TOTAL_BALANCE:-0.000000}"
    local supportxmr_total="${XTM_SUPPORTXMR_TOTAL_BALANCE:-0.000000}"
    
    # Calculate combined total balance
    local combined_total
    combined_total=$(echo "scale=6; $luckypool_total + $supportxmr_total" | bc 2>/dev/null || echo "0.000000")
    
    # Get previous total balance for growth calculation
    local history_file="${XTM_BALANCE_HISTORY_PATH:-/root/MINING/xtm_balance_history.txt}"
    local previous_balance="0.000000"
    if [[ -f "$history_file" ]]; then
        previous_balance=$(tail -n 1 "$history_file" 2>/dev/null | awk '{print $NF}' || echo "0.000000")
        [[ -z "$previous_balance" ]] && previous_balance="0.000000"
    fi

    # Calculate balance growth
    local balance_growth
    balance_growth=$(echo "scale=6; $combined_total - $previous_balance" | bc 2>/dev/null || echo "0.000000")

    # Save current combined balance to history
    mkdir -p "$(dirname "$history_file")" 2>/dev/null || true
    echo "$(date '+%Y-%m-%d %H:%M:%S') $combined_total" >> "$history_file" 2>/dev/null || true
    if [[ -f "$history_file" ]]; then
        tail -n 100 "$history_file" > "${history_file}.tmp" 2>/dev/null && mv "${history_file}.tmp" "$history_file" 2>/dev/null || true
    fi

    # Export combined values
    export XTM_TOTAL_BALANCE="$combined_total"
    export XTM_BALANCE_GROWTH="$balance_growth"

    log_message "INFO" "Combined XTM balance - LuckyPool: $luckypool_total XTM, SupportXMR: $supportxmr_total XTM, Total: $combined_total XTM, Growth: $balance_growth XTM"
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

    # Format XTM balances for multiple pools
    local xtm_total_formatted
    local xtm_growth_formatted
    
    # LuckyPool XTM balances
    local xtm_lucky_paid_formatted
    local xtm_lucky_unlocked_formatted
    local xtm_lucky_locked_formatted
    local xtm_lucky_total_formatted
    
    # SupportXMR XTM balances
    local xtm_support_paid_formatted
    local xtm_support_pending_formatted
    local xtm_support_total_formatted

    # Format LuckyPool balances
    if [[ -n "$XTM_LUCKYPOOL_TOTAL_BALANCE" ]]; then
        xtm_lucky_paid_formatted=$(format_balance "$XTM_LUCKYPOOL_PAID_BALANCE")
        xtm_lucky_unlocked_formatted=$(format_balance "$XTM_LUCKYPOOL_UNLOCKED_BALANCE")
        xtm_lucky_locked_formatted=$(format_balance "$XTM_LUCKYPOOL_LOCKED_BALANCE")
        xtm_lucky_total_formatted=$(format_balance "$XTM_LUCKYPOOL_TOTAL_BALANCE")
    else
        xtm_lucky_paid_formatted="数据获取失败"
        xtm_lucky_unlocked_formatted="数据获取失败"
        xtm_lucky_locked_formatted="数据获取失败"
        xtm_lucky_total_formatted="数据获取失败"
    fi
    
    # Format SupportXMR balances
    if [[ -n "$XTM_SUPPORTXMR_TOTAL_BALANCE" ]]; then
        xtm_support_paid_formatted=$(format_balance "$XTM_SUPPORTXMR_PAID_BALANCE")
        xtm_support_pending_formatted=$(format_balance "$XTM_SUPPORTXMR_PENDING_BALANCE")
        xtm_support_total_formatted=$(format_balance "$XTM_SUPPORTXMR_TOTAL_BALANCE")
    else
        xtm_support_paid_formatted="数据获取失败"
        xtm_support_pending_formatted="数据获取失败"
        xtm_support_total_formatted="数据获取失败"
    fi
    
    # Format combined XTM totals
    if [[ -n "$XTM_TOTAL_BALANCE" ]]; then
        xtm_total_formatted=$(format_balance "$XTM_TOTAL_BALANCE")
        xtm_growth_formatted=$(format_balance "$XTM_BALANCE_GROWTH")
    else
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

🎯 LuckyPool 矿池：
💰 已付款：${xtm_lucky_paid_formatted} XTM
🔓 未锁定：${xtm_lucky_unlocked_formatted} XTM
🔒 已锁定：${xtm_lucky_locked_formatted} XTM
💎 小计：${xtm_lucky_total_formatted} XTM

🎯 SupportXMR 矿池：
💰 已支付：${xtm_support_paid_formatted} XTM
⏳ 待支付：${xtm_support_pending_formatted} XTM
💎 小计：${xtm_support_total_formatted} XTM

💎 XTM 总收益：${xtm_total_formatted} XTM
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

# Main function
main() {
    # Create log directory if it doesn't exist
    local log_file="${LOG_FILE_PATH:-/root/MINING/mining_balance_monitor.log}"
    local xmr_history="${XMR_BALANCE_HISTORY_PATH:-/root/MINING/xmr_balance_history.txt}"
    local xtm_history="${XTM_BALANCE_HISTORY_PATH:-/root/MINING/xtm_balance_history.txt}"
    
    mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
    mkdir -p "$(dirname "$xmr_history")" 2>/dev/null || true
    mkdir -p "$(dirname "$xtm_history")" 2>/dev/null || true

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

    # Fetch and parse XTM balance data from multiple pools
    local xtm_luckypool_success=false
    local xtm_supportxmr_success=false
    
    # Process LuckyPool XTM data if enabled
    if [[ "$XTM_POOL" == "LUCKYPOOL" || "$XTM_POOL" == "BOTH" ]]; then
        local xtm_luckypool_data
        if xtm_luckypool_data=$(fetch_xtm_luckypool_balance_data); then
            if parse_xtm_luckypool_balance_data "$xtm_luckypool_data"; then
                xtm_luckypool_success=true
                log_message "INFO" "LuckyPool XTM data processing completed successfully"
            else
                log_message "ERROR" "LuckyPool XTM data processing failed"
            fi
        else
            log_message "ERROR" "LuckyPool XTM data fetching failed"
        fi
    fi
    
    # Process SupportXMR XTM data if enabled
    if [[ "$XTM_POOL" == "SUPPORTXMR" || "$XTM_POOL" == "BOTH" ]]; then
        local xtm_supportxmr_data
        xtm_supportxmr_data=$(fetch_xtm_supportxmr_balance_data)
        if parse_xtm_supportxmr_balance_data "$xtm_supportxmr_data"; then
            xtm_supportxmr_success=true
            log_message "INFO" "SupportXMR XTM data processing completed successfully"
        else
            log_message "ERROR" "SupportXMR XTM data processing failed"
        fi
    fi
    
    # Aggregate XTM data if at least one pool succeeded
    if [[ "$xtm_luckypool_success" == true ]] || [[ "$xtm_supportxmr_success" == true ]]; then
        aggregate_xtm_balance_data
        xtm_success=true
        log_message "INFO" "XTM aggregation completed successfully"
    else
        log_message "ERROR" "All XTM pool data processing failed"
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

# Trap for cleanup
trap 'log_message "INFO" "Script interrupted"' INT TERM

# Script usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Mining Balance Monitor Script (XMR + XTM Multi-Pool)

Options:
    -h, --help      Show this help message
    -v, --version   Show version information

Environment Variables:
    WECHAT_WEBHOOK_URL    WeChat webhook URL for sending alerts
    XTM_POOL              XTM pool selection (LUCKYPOOL, SUPPORTXMR, BOTH) [default: BOTH]
    LOG_FILE_PATH         Log file path [default: /root/MINING/mining_balance_monitor.log]
    XMR_BALANCE_HISTORY_PATH    XMR balance history file path
    XTM_BALANCE_HISTORY_PATH    XTM balance history file path

Examples:
    # Run with console output only (both XTM pools)
    $0

    # Run with WeChat alerts and both XTM pools
    WECHAT_WEBHOOK_URL="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=your-key" $0

    # Run with only SupportXMR XTM pool
    XTM_POOL="SUPPORTXMR" $0

    # Run with only LuckyPool XTM pool
    XTM_POOL="LUCKYPOOL" $0

    # Run as cron job (every 30 minutes)
    */30 * * * * /path/to/mining_balance_monitor.sh >> /var/log/cron.log 2>&1

Supported XTM Pools:
    - LuckyPool: api-tari.luckypool.io
    - SupportXMR: www.supportxmr.com/api/tari/balance
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--version)
            echo "Mining Balance Monitor v2.2.0 (Multi-Pool Support)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
    shift
done

# Run main function
main "$@"