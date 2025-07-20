#!/bin/bash

# Mining Balance Monitor Script (XMR + XTM)
# Author: DevOps Engineer
# Description: Monitor XMR and XTM mining balance and send formatted alerts to WeChat Robot

set -euo pipefail

# Load configuration from file if exists
CONFIG_FILE="$(dirname "$0")/mining_config.env"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Configuration
readonly XMR_API_URL="https://www.supportxmr.com/api/miner/45GkAa8FmTMWjeM1jCnH1r8psZWMBCi3vdmdrPqPCdDHRS4RZqb2Tnc55BqkUmuhd9KwvvhcoAVRqZMJVWe6wT3V32ZbN5W/stats"
readonly XTM_WALLET_ADDRESS="16meX2eiPWFAAU94fRF8u2DejfpQaV21a8bqYQviMDaSKfwuCgQJNAEauk9PTnx3jmKkTVuLXrgcbmXtAvtVUvn6K3BpkDjZeVnSuv1qMKY"
readonly XTM_API_URL="https://api-tari.luckypool.io/stats_address?address=${XTM_WALLET_ADDRESS}"

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

# Logging function
log_message() {
    local level="$1"
    shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" | tee -a "$LOG_FILE"
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

# Fetch XTM balance data from API
fetch_xtm_balance_data() {
    log_message "INFO" "Fetching XTM mining stats from API..."

    local response
    response=$(curl -s --connect-timeout 10 --max-time 30 "$XTM_API_URL" 2>/dev/null) || {
        log_message "ERROR" "Failed to fetch XTM data from API"
        return 1
    }

    # Check if response is empty
    if [[ -z "$response" ]]; then
        log_message "WARN" "Empty response from XTM API"
        return 1
    fi

    # Extract stats data
    local stats
    stats=$(echo "$response" | jq '.stats' 2>/dev/null)
    if [[ "$stats" == "null" ]] || [[ -z "$stats" ]]; then
        log_message "ERROR" "Unable to get XTM stats data"
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

    log_message "INFO" "XMR price: $price USDT"
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

    log_message "INFO" "XTM price: $price USDT"
    echo "$price"
}

# Calculate USD values
calculate_usd_values() {
    log_message "INFO" "Calculating USD values..."

    # Calculate XMR value in USD
    if [[ -n "$XMR_TOTAL_BALANCE" && -n "$XMR_PRICE" && "$XMR_PRICE" != "0" ]]; then
        # Clean the values before calculation
        local clean_xmr_balance=$(echo "$XMR_TOTAL_BALANCE" | sed 's/[^0-9.]//g')
        local clean_xmr_price=$(echo "$XMR_PRICE" | sed 's/[^0-9.]//g')
        XMR_TOTAL_VALUE_USD=$(echo "scale=2; $clean_xmr_balance * $clean_xmr_price" | bc 2>/dev/null || echo "0.00")
        log_message "INFO" "XMR total value: $XMR_TOTAL_VALUE_USD USD"
    else
        XMR_TOTAL_VALUE_USD="0.00"
        log_message "WARN" "Cannot calculate XMR USD value - missing price or balance data"
    fi

    # Calculate XTM value in USD
    if [[ -n "$XTM_TOTAL_BALANCE" && -n "$XTM_PRICE" && "$XTM_PRICE" != "0" ]]; then
        # Clean the values before calculation
        local clean_xtm_balance=$(echo "$XTM_TOTAL_BALANCE" | sed 's/[^0-9.]//g')
        local clean_xtm_price=$(echo "$XTM_PRICE" | sed 's/[^0-9.]//g')
        XTM_TOTAL_VALUE_USD=$(echo "scale=2; $clean_xtm_balance * $clean_xtm_price" | bc 2>/dev/null || echo "0.00")
        log_message "INFO" "XTM total value: $XTM_TOTAL_VALUE_USD USD"
    else
        XTM_TOTAL_VALUE_USD="0.00"
        log_message "WARN" "Cannot calculate XTM USD value - missing price or balance data"
    fi

    # Calculate total value in USD
    local clean_xmr_value=$(echo "$XMR_TOTAL_VALUE_USD" | sed 's/[^0-9.]//g')
    local clean_xtm_value=$(echo "$XTM_TOTAL_VALUE_USD" | sed 's/[^0-9.]//g')
    TOTAL_VALUE_USD=$(echo "scale=2; $clean_xmr_value + $clean_xtm_value" | bc 2>/dev/null || echo "0.00")
    log_message "INFO" "Total portfolio value: $TOTAL_VALUE_USD USD"

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
    local previous_balance="0.000000000000"
    if [[ -f "$XMR_BALANCE_HISTORY_FILE" ]]; then
        previous_balance=$(tail -n 1 "$XMR_BALANCE_HISTORY_FILE" 2>/dev/null | awk '{print $NF}' || echo "0.000000000000")
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
    echo "$(date '+%Y-%m-%d %H:%M:%S') $total_balance" >> "$XMR_BALANCE_HISTORY_FILE"
    tail -n 100 "$XMR_BALANCE_HISTORY_FILE" > "${XMR_BALANCE_HISTORY_FILE}.tmp" && mv "${XMR_BALANCE_HISTORY_FILE}.tmp" "$XMR_BALANCE_HISTORY_FILE"

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
    local previous_balance="0.000000"
    if [[ -f "$XTM_BALANCE_HISTORY_FILE" ]]; then
        previous_balance=$(tail -n 1 "$XTM_BALANCE_HISTORY_FILE" 2>/dev/null | awk '{print $NF}' || echo "0.000000")
        [[ -z "$previous_balance" ]] && previous_balance="0.000000"
    fi

    # 计算收益增长
    local balance_growth
    balance_growth=$(echo "scale=6; $total_balance - $previous_balance" | bc)

    # Save current balance to history
    echo "$(date '+%Y-%m-%d %H:%M:%S') $total_balance" >> "$XTM_BALANCE_HISTORY_FILE"
    tail -n 100 "$XTM_BALANCE_HISTORY_FILE" > "${XTM_BALANCE_HISTORY_FILE}.tmp" && mv "${XTM_BALANCE_HISTORY_FILE}.tmp" "$XTM_BALANCE_HISTORY_FILE"

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
        # Clean price format, ensure only numbers and decimal point
        xmr_price_formatted=$(printf "%.2f" "$XMR_PRICE" 2>/dev/null || echo "获取失败")
        xmr_value_formatted="$XMR_TOTAL_VALUE_USD"
    else
        xmr_price_formatted="获取失败"
        xmr_value_formatted="计算失败"
    fi

    if [[ -n "$XTM_PRICE" && "$XTM_PRICE" != "0" ]]; then
        # Clean price format, ensure only numbers and decimal point
        xtm_price_formatted=$(printf "%.6f" "$XTM_PRICE" 2>/dev/null || echo "获取失败")
        xtm_value_formatted="$XTM_TOTAL_VALUE_USD"
    else
        xtm_price_formatted="获取失败"
        xtm_value_formatted="计算失败"
    fi

    if [[ -n "$TOTAL_VALUE_USD" ]]; then
        total_value_formatted="$TOTAL_VALUE_USD"
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

# Main function
main() {
    log_message "INFO" "Starting Mining Balance Monitor (XMR + XTM)..."

    # Check dependencies
    check_dependencies

    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$XMR_BALANCE_HISTORY_FILE")"
    mkdir -p "$(dirname "$XTM_BALANCE_HISTORY_FILE")"

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

Mining Balance Monitor Script (XMR + XTM)

Options:
    -h, --help      Show this help message
    -v, --version   Show version information

Environment Variables:
    WECHAT_WEBHOOK_URL    WeChat webhook URL for sending alerts

Examples:
    # Run with console output only
    $0

    # Run with WeChat alerts
    WECHAT_WEBHOOK_URL="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=your-key" $0

    # Run as cron job (every 30 minutes)
    */30 * * * * /path/to/mining_balance_monitor.sh >> /var/log/cron.log 2>&1
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
            echo "Mining Balance Monitor v2.1.0"
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