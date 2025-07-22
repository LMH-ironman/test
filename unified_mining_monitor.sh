#!/bin/bash

# =============================================================================
# 统一挖矿监控脚本 - Unified Mining Monitor Script
# =============================================================================
# Author: DevOps Engineer
# Version: 4.0.0
# Description: All-in-one mining monitor with comprehensive management capabilities
# 
# 功能特性 / Features:
# - XMR + XTM 双币种监控 / Dual cryptocurrency monitoring
# - 实时价格获取 / Real-time price fetching
# - USD 价值计算 / USD value calculation  
# - 微信机器人推送 / WeChat bot notifications
# - 守护进程管理 / Daemon process management
# - 定时任务设置 / Cron job setup
# - 历史数据记录 / Historical data tracking
# - 多池支持 / Multi-pool support
# =============================================================================

set -euo pipefail

# =============================================================================
# 版本和脚本信息 / Version and Script Info
# =============================================================================
readonly SCRIPT_VERSION="4.0.0"
readonly SCRIPT_NAME="Unified Mining Monitor"
readonly SCRIPT_DATE="2024-01-20"

# =============================================================================
# API 配置 / API Configuration
# =============================================================================
readonly XMR_API_URL="https://www.supportxmr.com/api/miner/45GkAa8FmTMWjeM1jCnH1r8psZWMBCi3vdmdrPqPCdDHRS4RZqb2Tnc55BqkUmuhd9KwvvhcoAVRqZMJVWe6wT3V32ZbN5W/stats"
readonly XTM_WALLET_ADDRESS="16meX2eiPWFAAU94fRF8u2DejfpQaV21a8bqYQviMDaSKfwuCgQJNAEauk9PTnx3jmKkTVuLXrgcbmXtAvtVUvn6K3BpkDjZeVnSuv1qMKY"
readonly XTM_API_URL="https://api-tari.luckypool.io/stats_address?address=${XTM_WALLET_ADDRESS}"
readonly XMR_PRICE_API_URL="https://www.xt.com/sapi/v4/market/public/ticker/24h?symbol=xmr_usdt"
readonly XTM_PRICE_API_URL="https://www.xt.com/sapi/v4/market/public/ticker/24h?symbol=xtm_usdt"

# =============================================================================
# 配置管理 / Configuration Management
# =============================================================================

# 保存环境变量（优先级最高）/ Save environment variables (highest priority)
_SAVED_LOG_FILE_PATH="${LOG_FILE_PATH:-}"
_SAVED_XMR_BALANCE_HISTORY_PATH="${XMR_BALANCE_HISTORY_PATH:-}"
_SAVED_XTM_BALANCE_HISTORY_PATH="${XTM_BALANCE_HISTORY_PATH:-}"
_SAVED_WECHAT_WEBHOOK_URL="${WECHAT_WEBHOOK_URL:-}"

# 获取脚本目录 / Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/mining_config.env"

# 加载配置文件 / Load configuration file
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# 恢复环境变量（环境变量优先级最高）/ Restore environment variables (highest priority)
[[ -n "$_SAVED_LOG_FILE_PATH" ]] && LOG_FILE_PATH="$_SAVED_LOG_FILE_PATH"
[[ -n "$_SAVED_XMR_BALANCE_HISTORY_PATH" ]] && XMR_BALANCE_HISTORY_PATH="$_SAVED_XMR_BALANCE_HISTORY_PATH"
[[ -n "$_SAVED_XTM_BALANCE_HISTORY_PATH" ]] && XTM_BALANCE_HISTORY_PATH="$_SAVED_XTM_BALANCE_HISTORY_PATH"
[[ -n "$_SAVED_WECHAT_WEBHOOK_URL" ]] && WECHAT_WEBHOOK_URL="$_SAVED_WECHAT_WEBHOOK_URL"

# 默认路径设置 / Default path settings
if [[ $EUID -eq 0 ]]; then
    # Root 用户默认路径 / Root user default paths
    DEFAULT_LOG_DIR="/root/MINING"
    DEFAULT_LOG_FILE="$DEFAULT_LOG_DIR/mining_monitor.log"
    DEFAULT_XMR_HISTORY="$DEFAULT_LOG_DIR/xmr_balance_history.txt"
    DEFAULT_XTM_HISTORY="$DEFAULT_LOG_DIR/xtm_balance_history.txt"
else
    # 非 Root 用户默认路径 / Non-root user default paths
    DEFAULT_LOG_DIR="$HOME/mining_logs"
    DEFAULT_LOG_FILE="$DEFAULT_LOG_DIR/mining_monitor.log"
    DEFAULT_XMR_HISTORY="$DEFAULT_LOG_DIR/xmr_balance_history.txt"
    DEFAULT_XTM_HISTORY="$DEFAULT_LOG_DIR/xtm_balance_history.txt"
fi

# 最终配置设置 / Final configuration settings
readonly WECHAT_WEBHOOK_URL="${WECHAT_WEBHOOK_URL:-https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=3fc21e51-d7b7-46ca-9b86-f68deab4fd61}"
readonly LOG_FILE="${LOG_FILE_PATH:-$DEFAULT_LOG_FILE}"
readonly XMR_BALANCE_HISTORY_FILE="${XMR_BALANCE_HISTORY_PATH:-$DEFAULT_XMR_HISTORY}"
readonly XTM_BALANCE_HISTORY_FILE="${XTM_BALANCE_HISTORY_PATH:-$DEFAULT_XTM_HISTORY}"
readonly PID_FILE="$DEFAULT_LOG_DIR/mining_daemon.pid"

# =============================================================================
# 颜色配置 / Color Configuration
# =============================================================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# =============================================================================
# 全局变量 / Global Variables
# =============================================================================

# XMR 余额数据 / XMR balance data
export XMR_PAID_BALANCE=""
export XMR_DUE_BALANCE=""
export XMR_TOTAL_BALANCE=""
export XMR_BALANCE_GROWTH=""
export XMR_GROWTH_INT=""

# XTM 余额数据 / XTM balance data
export XTM_PAID_BALANCE=""
export XTM_UNLOCKED_BALANCE=""
export XTM_LOCKED_BALANCE=""
export XTM_TOTAL_BALANCE=""
export XTM_BALANCE_GROWTH=""

# 价格数据 / Price data
export XMR_PRICE=""
export XTM_PRICE=""
export XMR_TOTAL_VALUE_USD=""
export XTM_TOTAL_VALUE_USD=""
export TOTAL_VALUE_USD=""

# =============================================================================
# 工具函数 / Utility Functions
# =============================================================================

# 彩色输出函数 / Colored output functions
print_success() { echo -e "${GREEN}✅ $*${NC}"; }
print_error() { echo -e "${RED}❌ $*${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $*${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
print_header() { echo -e "${PURPLE}🚀 $*${NC}"; }

# 日志记录函数 / Logging function
log_message() {
    local level="$1"
    shift
    local log_file="${LOG_FILE_PATH:-/tmp/mining_monitor.log}"
    local message="$(date '+%Y-%m-%d %H:%M:%S') [$level] $*"
    echo "$message"
    echo "$message" >> "$log_file" 2>/dev/null || true
}

# 错误处理函数 / Error handling function
error_exit() {
    log_message "ERROR" "$1"
    print_error "$1"
    exit 1
}

# 依赖检查函数 / Dependency check function
check_dependencies() {
    local dependencies=("curl" "bc" "jq")
    local missing_deps=()

    print_info "检查依赖项..."
    
    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_warning "缺少依赖项: ${missing_deps[*]}"
        print_info "正在尝试自动安装..."
        
        for cmd in "${missing_deps[@]}"; do
            if command -v apt-get &> /dev/null; then
                sudo apt-get update &>/dev/null && sudo apt-get install -y "$cmd" &>/dev/null
            elif command -v yum &> /dev/null; then
                sudo yum install -y "$cmd" &>/dev/null
            elif command -v brew &> /dev/null; then
                brew install "$cmd" &>/dev/null
            else
                error_exit "无法自动安装 $cmd，请手动安装"
            fi
            
            if command -v "$cmd" &> /dev/null; then
                print_success "$cmd 安装成功"
            else
                error_exit "$cmd 安装失败"
            fi
        done
    fi
    
    print_success "所有依赖项检查完成"
}

# 目录设置函数 / Directory setup function
setup_directories() {
    local dirs=(
        "$(dirname "$LOG_FILE")"
        "$(dirname "$XMR_BALANCE_HISTORY_FILE")"
        "$(dirname "$XTM_BALANCE_HISTORY_FILE")"
        "$(dirname "$PID_FILE")"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" 2>/dev/null || true
            if [[ -d "$dir" ]]; then
                log_message "INFO" "Created directory: $dir"
            else
                log_message "WARN" "Failed to create directory: $dir"
            fi
        fi
    done
}

# =============================================================================
# 挖矿数据获取函数 / Mining Data Fetching Functions  
# =============================================================================

# 获取 XMR 余额数据 / Fetch XMR balance data
fetch_xmr_balance_data() {
    log_message "INFO" "Fetching XMR mining stats from API..."

    local response
    response=$(curl -s --connect-timeout 10 --max-time 30 "$XMR_API_URL" 2>/dev/null) || {
        log_message "ERROR" "Failed to fetch XMR data from API, using default values"
        echo '{"amtPaid": 0, "amtDue": 0}'
        return
    }

    # 检查响应是否为空 / Check if response is empty
    if [[ -z "$response" ]]; then
        log_message "WARN" "Empty response from XMR API, using default values"
        echo '{"amtPaid": 0, "amtDue": 0}'
        return
    fi

    # 基本 JSON 验证 / Basic JSON validation
    if ! echo "$response" | jq empty 2>/dev/null; then
        log_message "WARN" "Invalid JSON response from XMR API: $response"
        echo '{"amtPaid": 0, "amtDue": 0}'
        return
    fi

    echo "$response"
}

# 获取 XTM 余额数据 / Fetch XTM balance data
fetch_xtm_balance_data() {
    log_message "INFO" "Fetching XTM mining stats from API..."

    local response
    response=$(curl -s --connect-timeout 15 --max-time 45 "$XTM_API_URL" 2>/dev/null) || {
        log_message "ERROR" "Failed to fetch XTM data from API"
        return 1
    }

    # 检查响应是否为空 / Check if response is empty
    if [[ -z "$response" ]]; then
        log_message "WARN" "Empty response from XTM API"
        return 1
    fi

    # 检查响应是否包含错误 / Check if response contains error
    if [[ "$response" == *"error"* ]] || [[ "$response" == *"Error"* ]]; then
        log_message "ERROR" "XTM API returned error: $response"
        return 1
    fi

    # 提取统计数据 / Extract stats data
    local stats
    stats=$(echo "$response" | jq '.stats' 2>/dev/null)
    if [[ "$stats" == "null" ]] || [[ -z "$stats" ]]; then
        log_message "ERROR" "Unable to get XTM stats data from response: $response"
        return 1
    fi

    echo "$stats"
}

# XMR 原始值转换为小数 / Convert XMR raw value to decimal
convert_xmr_to_decimal() {
    local raw_value="$1"

    # 处理零值或空值 / Handle zero or empty values
    if [[ -z "$raw_value" || "$raw_value" == "0" || "$raw_value" == "null" ]]; then
        echo "0.000000000000"
        return
    fi

    # 使用 bash 内置算术进行精确计算 (除以 10^12) / Use bash arithmetic for precise calculation
    local integer_part=$((raw_value / 1000000000000))
    local decimal_part=$((raw_value % 1000000000000))

    # 格式化输出，确保小数部分有12位数字 / Format output with 12 decimal places
    printf "%d.%012d" "$integer_part" "$decimal_part"
}

# XTM 原始值转换为小数 / Convert XTM raw value to decimal
convert_xtm_to_decimal() {
    local raw_value="$1"

    # 处理零值或空值 / Handle zero or empty values
    if [[ -z "$raw_value" || "$raw_value" == "0" || "$raw_value" == "null" ]]; then
        echo "0.000000"
        return
    fi

    # 使用 bc 进行精确计算 / Use bc for precise calculation
    echo "scale=6; $raw_value / 1000000" | bc
}

# =============================================================================
# 价格获取函数 / Price Fetching Functions
# =============================================================================

# 获取 XMR 价格 / Fetch XMR price
fetch_xmr_price() {
    local response
    response=$(curl -s --connect-timeout 10 --max-time 30 "$XMR_PRICE_API_URL" 2>/dev/null) || {
        log_message "ERROR" "Failed to fetch XMR price from API"
        echo "0"
        return
    }

    # 检查响应是否为空 / Check if response is empty
    if [[ -z "$response" ]]; then
        log_message "WARN" "Empty response from XMR price API"
        echo "0"
        return
    fi

    # 使用 jq 提取价格 / Extract price using jq
    local price
    price=$(echo "$response" | jq -r '.result[0].c // "0"' 2>/dev/null)
    
    # 如果 jq 失败，尝试正则提取 / If jq fails, try regex extraction
    if [[ "$price" == "null" || -z "$price" || "$price" == "0" ]]; then
        price=$(echo "$response" | grep -o '"c":"[^"]*"' | sed 's/"c":"//g' | sed 's/"//g' | head -1)
        [[ -z "$price" ]] && price="0"
    fi

    # 清理和验证价格格式 / Clean and validate price format
    price=$(echo "$price" | sed 's/[^0-9.]//g')
    if [[ ! "$price" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        log_message "WARN" "Invalid XMR price format: $price"
        price="0"
    fi

    echo "$price"
}

# 获取 XTM 价格 / Fetch XTM price
fetch_xtm_price() {
    local response
    response=$(curl -s --connect-timeout 10 --max-time 30 "$XTM_PRICE_API_URL" 2>/dev/null) || {
        log_message "ERROR" "Failed to fetch XTM price from API"
        echo "0"
        return
    }

    # 检查响应是否为空 / Check if response is empty
    if [[ -z "$response" ]]; then
        log_message "WARN" "Empty response from XTM price API"
        echo "0"
        return
    fi

    # 使用 jq 提取价格 / Extract price using jq
    local price
    price=$(echo "$response" | jq -r '.result[0].c // "0"' 2>/dev/null)
    
    # 如果 jq 失败，尝试正则提取 / If jq fails, try regex extraction
    if [[ "$price" == "null" || -z "$price" || "$price" == "0" ]]; then
        price=$(echo "$response" | grep -o '"c":"[^"]*"' | sed 's/"c":"//g' | sed 's/"//g' | head -1)
        [[ -z "$price" ]] && price="0"
    fi

    # 清理和验证价格格式 / Clean and validate price format
    price=$(echo "$price" | sed 's/[^0-9.]//g')
    if [[ ! "$price" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        log_message "WARN" "Invalid XTM price format: $price"
        price="0"
    fi

    echo "$price"
}

# =============================================================================
# 数据解析函数 / Data Parsing Functions
# =============================================================================

# 解析 XMR 余额数据 / Parse XMR balance data
parse_xmr_balance_data() {
    local json_data="$1"

    log_message "DEBUG" "Raw XMR JSON response: $json_data"

    local paid_raw
    local due_raw

    # 使用 jq 解析 / Parse using jq
    paid_raw=$(echo "$json_data" | jq -r '.amtPaid // 0' 2>/dev/null || echo "0")
    due_raw=$(echo "$json_data" | jq -r '.amtDue // 0' 2>/dev/null || echo "0")

    # 如果 jq 解析失败，使用正则表达式 / If jq fails, use regex
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

    # 清理和验证数值 / Clean and validate values
    paid_raw=$(echo "$paid_raw" | sed 's/[^0-9]//g' 2>/dev/null || echo "0")
    due_raw=$(echo "$due_raw" | sed 's/[^0-9]//g' 2>/dev/null || echo "0")

    # 设置默认值 / Set default values
    [[ -z "$paid_raw" ]] && paid_raw="0"
    [[ -z "$due_raw" ]] && due_raw="0"

    log_message "INFO" "XMR解析结果 - paid: $paid_raw, due: $due_raw"

    local paid_decimal
    local due_decimal
    local total_balance

    paid_decimal=$(convert_xmr_to_decimal "$paid_raw")
    due_decimal=$(convert_xmr_to_decimal "$due_raw")

    # 计算总余额 / Calculate total balance
    local total_raw=$((paid_raw + due_raw))
    total_balance=$(convert_xmr_to_decimal "$total_raw")

    # 计算增长 / Calculate growth
    local history_file="$XMR_BALANCE_HISTORY_FILE"
    local previous_balance="0.000000000000"
    if [[ -f "$history_file" ]]; then
        previous_balance=$(tail -n 1 "$history_file" 2>/dev/null | awk '{print $NF}' || echo "0.000000000000")
        [[ -z "$previous_balance" ]] && previous_balance="0.000000000000"
    fi

    # 计算增长 / Calculate growth
    local current_int=$(echo "$total_balance" | sed 's/\.//' | sed 's/^0*//')
    local previous_int=$(echo "$previous_balance" | sed 's/\.//' | sed 's/^0*//')

    [[ -z "$current_int" ]] && current_int="0"
    [[ -z "$previous_int" ]] && previous_int="0"

    local growth_int=$((current_int - previous_int))
    local balance_growth
    balance_growth=$(convert_xmr_to_decimal "$growth_int")

    # 保存当前余额到历史 / Save current balance to history
    mkdir -p "$(dirname "$history_file")" 2>/dev/null || true
    echo "$(date '+%Y-%m-%d %H:%M:%S') $total_balance" >> "$history_file" 2>/dev/null || true
    if [[ -f "$history_file" ]]; then
        tail -n 100 "$history_file" > "${history_file}.tmp" 2>/dev/null && mv "${history_file}.tmp" "$history_file" 2>/dev/null || true
    fi

    # 导出变量 / Export variables
    export XMR_PAID_BALANCE="$paid_decimal"
    export XMR_DUE_BALANCE="$due_decimal"
    export XMR_TOTAL_BALANCE="$total_balance"
    export XMR_BALANCE_GROWTH="$balance_growth"
    export XMR_GROWTH_INT="$growth_int"

    log_message "INFO" "Parsed XMR balance - Paid: $paid_decimal XMR, Due: $due_decimal XMR, Total: $total_balance XMR"
}

# 解析 XTM 余额数据 / Parse XTM balance data
parse_xtm_balance_data() {
    local json_data="$1"

    log_message "DEBUG" "Raw XTM JSON response: $json_data"

    # 提取三个关键值 / Extract three key values
    local paid_raw
    local unlocked_raw
    local locked_raw

    paid_raw=$(echo "$json_data" | jq -r '.paid // "0"' | sed 's/"//g')
    unlocked_raw=$(echo "$json_data" | jq -r '.unlocked // "0"' | sed 's/"//g')
    locked_raw=$(echo "$json_data" | jq -r '.locked // "0"' | sed 's/"//g')
    
    # 如果 jq 失败，使用正则表达式提取 / If jq fails, use regex
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

    # 验证数据有效性 / Validate data
    if [[ ! "$paid_raw" =~ ^[0-9]+$ ]] || [[ ! "$unlocked_raw" =~ ^[0-9]+$ ]] || [[ ! "$locked_raw" =~ ^[0-9]+$ ]]; then
        log_message "ERROR" "XTM数据格式无效"
        return 1
    fi

    # 转换为小数 / Convert to decimal
    local paid_decimal
    local unlocked_decimal
    local locked_decimal

    paid_decimal=$(convert_xtm_to_decimal "$paid_raw")
    unlocked_decimal=$(convert_xtm_to_decimal "$unlocked_raw")
    locked_decimal=$(convert_xtm_to_decimal "$locked_raw")

    # 计算总收益 / Calculate total balance
    local total_balance
    total_balance=$(echo "scale=6; $paid_decimal + $unlocked_decimal + $locked_decimal" | bc)

    # 获取上次收益 / Get previous balance
    local history_file="$XTM_BALANCE_HISTORY_FILE"
    local previous_balance="0.000000"
    if [[ -f "$history_file" ]]; then
        previous_balance=$(tail -n 1 "$history_file" 2>/dev/null | awk '{print $NF}' || echo "0.000000")
        [[ -z "$previous_balance" ]] && previous_balance="0.000000"
    fi

    # 计算收益增长 / Calculate balance growth
    local balance_growth
    balance_growth=$(echo "scale=6; $total_balance - $previous_balance" | bc)

    # 保存当前余额到历史 / Save current balance to history
    mkdir -p "$(dirname "$history_file")" 2>/dev/null || true
    echo "$(date '+%Y-%m-%d %H:%M:%S') $total_balance" >> "$history_file" 2>/dev/null || true
    if [[ -f "$history_file" ]]; then
        tail -n 100 "$history_file" > "${history_file}.tmp" 2>/dev/null && mv "${history_file}.tmp" "$history_file" 2>/dev/null || true
    fi

    # 导出变量 / Export variables
    export XTM_PAID_BALANCE="$paid_decimal"
    export XTM_UNLOCKED_BALANCE="$unlocked_decimal"
    export XTM_LOCKED_BALANCE="$locked_decimal"
    export XTM_TOTAL_BALANCE="$total_balance"
    export XTM_BALANCE_GROWTH="$balance_growth"

    log_message "INFO" "Parsed XTM balance - Paid: $paid_decimal XTM, Unlocked: $unlocked_decimal XTM, Locked: $locked_decimal XTM, Total: $total_balance XTM"
}

# =============================================================================
# 价值计算函数 / Value Calculation Functions
# =============================================================================

# 计算 USD 价值 / Calculate USD values
calculate_usd_values() {
    log_message "INFO" "Calculating USD values..."

    # 计算 XMR 的 USD 价值 / Calculate XMR value in USD
    if [[ -n "$XMR_TOTAL_BALANCE" && -n "$XMR_PRICE" && "$XMR_PRICE" != "0" ]]; then
        local clean_xmr_balance=$(echo "$XMR_TOTAL_BALANCE" | grep -o '^[0-9]*\.[0-9]*' | head -1)
        local clean_xmr_price=$(echo "$XMR_PRICE" | grep -o '^[0-9]*\.[0-9]*' | head -1)
        
        if [[ -n "$clean_xmr_balance" && -n "$clean_xmr_price" ]]; then
            XMR_TOTAL_VALUE_USD=$(echo "scale=2; $clean_xmr_balance * $clean_xmr_price" | bc 2>/dev/null || echo "0.00")
            log_message "INFO" "XMR calculation: $clean_xmr_balance XMR * $clean_xmr_price USD = $XMR_TOTAL_VALUE_USD USD"
        else
            XMR_TOTAL_VALUE_USD="0.00"
        fi
    else
        XMR_TOTAL_VALUE_USD="0.00"
    fi

    # 计算 XTM 的 USD 价值 / Calculate XTM value in USD
    if [[ -n "$XTM_TOTAL_BALANCE" && -n "$XTM_PRICE" && "$XTM_PRICE" != "0" ]]; then
        local clean_xtm_balance=$(echo "$XTM_TOTAL_BALANCE" | grep -o '^[0-9]*\.[0-9]*' | head -1)
        local clean_xtm_price=$(echo "$XTM_PRICE" | grep -o '^[0-9]*\.[0-9]*' | head -1)
        
        if [[ -n "$clean_xtm_balance" && -n "$clean_xtm_price" ]]; then
            XTM_TOTAL_VALUE_USD=$(echo "scale=2; $clean_xtm_balance * $clean_xtm_price" | bc 2>/dev/null || echo "0.00")
            log_message "INFO" "XTM calculation: $clean_xtm_balance XTM * $clean_xtm_price USD = $XTM_TOTAL_VALUE_USD USD"
        else
            XTM_TOTAL_VALUE_USD="0.00"
        fi
    else
        XTM_TOTAL_VALUE_USD="0.00"
    fi

    # 计算总 USD 价值 / Calculate total USD value
    local clean_xmr_value=$(echo "$XMR_TOTAL_VALUE_USD" | grep -o '^[0-9]*\.[0-9]*' | head -1)
    local clean_xtm_value=$(echo "$XTM_TOTAL_VALUE_USD" | grep -o '^[0-9]*\.[0-9]*' | head -1)
    
    [[ -z "$clean_xmr_value" ]] && clean_xmr_value="0.00"
    [[ -z "$clean_xtm_value" ]] && clean_xtm_value="0.00"
    
    TOTAL_VALUE_USD=$(echo "scale=2; $clean_xmr_value + $clean_xtm_value" | bc 2>/dev/null || echo "0.00")

    # 导出变量 / Export variables
    export XMR_TOTAL_VALUE_USD
    export XTM_TOTAL_VALUE_USD
    export TOTAL_VALUE_USD
}

# =============================================================================
# 格式化函数 / Formatting Functions
# =============================================================================

# 格式化余额显示 / Format balance for display
format_balance() {
    local balance="$1"

    # 移除尾随零 / Remove trailing zeros
    local formatted
    formatted=$(echo "$balance" | sed 's/\.000000000000$//' | sed 's/\.000000$//' | sed 's/0*$//' | sed 's/\.$//')

    # 如果结果为空，返回0 / If result is empty, return 0
    [[ -z "$formatted" ]] && formatted="0"

    echo "$formatted"
}

# 生成报告消息 / Generate alert message
generate_alert_message() {
    local current_time
    current_time=$(date '+%Y-%m-%d %H:%M:%S')

    # 格式化 XMR 余额 / Format XMR balances
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

    # 格式化 XTM 余额 / Format XTM balances
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

    # 确定增长指示器 / Determine growth indicators
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

    # 格式化价格和 USD 值 / Format price and USD values
    local xmr_price_formatted=""
    local xtm_price_formatted=""
    local xmr_value_formatted=""
    local xtm_value_formatted=""
    local total_value_formatted=""

    if [[ -n "$XMR_PRICE" && "$XMR_PRICE" != "0" ]]; then
        local clean_price=$(echo "$XMR_PRICE" | grep -o '^[0-9]*\.[0-9]*' | head -1)
        if [[ -n "$clean_price" ]]; then
            xmr_price_formatted=$(printf "%.2f" "$clean_price" 2>/dev/null || echo "获取失败")
        else
            xmr_price_formatted="获取失败"
        fi
        
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
        local clean_price=$(echo "$XTM_PRICE" | grep -o '^[0-9]*\.[0-9]*' | head -1)
        if [[ -n "$clean_price" ]]; then
            xtm_price_formatted=$(printf "%.6f" "$clean_price" 2>/dev/null || echo "获取失败")
        else
            xtm_price_formatted="获取失败"
        fi
        
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

# =============================================================================
# 通知函数 / Notification Functions
# =============================================================================

# 发送微信警报 / Send WeChat alert
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
        print_success "微信通知发送成功"
    else
        log_message "ERROR" "WeChat alert failed: $response"
        print_error "微信通知发送失败: $response"
        return 1
    fi
}

# 显示控制台输出 / Display console output
display_console_output() {
    local message_text
    message_text=$(generate_alert_message)

    echo -e "${BLUE}================================================================${NC}"
    echo -e "${GREEN}$message_text${NC}"
    echo -e "${BLUE}================================================================${NC}"
}

# =============================================================================
# 守护进程管理函数 / Daemon Management Functions
# =============================================================================

# 启动守护进程 / Start daemon process
start_daemon() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        print_warning "挖矿监控守护进程已在运行 (PID: $(cat "$PID_FILE"))"
        return 1
    fi
    
    print_header "启动挖矿监控守护进程..."
    
    # 启动后台守护进程 / Start daemon process in background
    nohup bash -c "
        echo \"=== 挖矿收益监控守护进程启动 ===\" >> \"$LOG_FILE\"
        echo \"开始时间: \$(date)\" >> \"$LOG_FILE\"
        echo \"执行频率: 每5分钟\" >> \"$LOG_FILE\"
        echo \"脚本路径: $SCRIPT_DIR/$(basename "$0")\" >> \"$LOG_FILE\"
        echo \"\" >> \"$LOG_FILE\"
        
        run_count=0
        while true; do
            run_count=\$((run_count + 1))
            echo \"\$(date '+%Y-%m-%d %H:%M:%S') [DAEMON] 开始第 \$run_count 次执行\" >> \"$LOG_FILE\"
            
            if \"$0\" monitor >> \"$LOG_FILE\" 2>&1; then
                echo \"\$(date '+%Y-%m-%d %H:%M:%S') [DAEMON] 第 \$run_count 次执行成功\" >> \"$LOG_FILE\"
            else
                echo \"\$(date '+%Y-%m-%d %H:%M:%S') [DAEMON] 第 \$run_count 次执行失败\" >> \"$LOG_FILE\"
            fi
            
            # 等待 5 分钟 / Wait 5 minutes
            sleep 300
        done
    " > "$(dirname "$LOG_FILE")/daemon_output.log" 2>&1 &
    
    local daemon_pid=$!
    
    # 保存 PID / Save PID
    echo "$daemon_pid" > "$PID_FILE"
    
    print_success "守护进程已启动 (PID: $daemon_pid)"
    print_info "📊 日志文件: $LOG_FILE"
    print_info "🔍 查看日志: $0 logs"
    echo ""
    print_info "💡 守护进程将每5分钟执行一次挖矿收益监控"
}

# 停止守护进程 / Stop daemon process
stop_daemon() {
    if [[ ! -f "$PID_FILE" ]]; then
        print_warning "没有找到PID文件，守护进程可能未运行"
        return 1
    fi
    
    local pid=$(cat "$PID_FILE")
    
    if kill -0 "$pid" 2>/dev/null; then
        print_info "停止挖矿监控守护进程 (PID: $pid)..."
        kill "$pid"
        
        # 等待进程结束 / Wait for process to end
        sleep 2
        
        if kill -0 "$pid" 2>/dev/null; then
            print_warning "进程未能正常结束，强制终止..."
            kill -9 "$pid"
        fi
        
        rm -f "$PID_FILE"
        print_success "守护进程已停止"
    else
        print_warning "进程 $pid 不存在，清理PID文件"
        rm -f "$PID_FILE"
    fi
}

# 显示守护进程状态 / Show daemon status
show_daemon_status() {
    echo -e "${CYAN}=== 守护进程状态 ===${NC}"
    
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        local pid=$(cat "$PID_FILE")
        print_success "挖矿监控守护进程正在运行"
        echo "   PID: $pid"
        echo "   启动时间: $(ps -o lstart= -p "$pid" 2>/dev/null || echo '未知')"
        echo "   日志文件: $LOG_FILE"
        
        if [[ -f "$LOG_FILE" ]]; then
            local last_run=$(tail -1 "$LOG_FILE" | grep -o '^[0-9-]* [0-9:]*' || echo '未知')
            echo "   最后执行: $last_run"
        fi
    else
        print_error "挖矿监控守护进程未运行"
        if [[ -f "$PID_FILE" ]]; then
            rm -f "$PID_FILE"
        fi
    fi
}

# 显示日志 / Show logs
show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        print_info "📊 实时日志 (按 Ctrl+C 退出):"
        echo "----------------------------------------"
        tail -f "$LOG_FILE"
    else
        print_error "日志文件不存在: $LOG_FILE"
    fi
}

# 重启守护进程 / Restart daemon
restart_daemon() {
    print_header "重启挖矿监控守护进程..."
    stop_daemon 2>/dev/null || true
    sleep 2
    start_daemon
}

# =============================================================================
# 定时任务设置函数 / Cron Setup Functions
# =============================================================================

# 设置定时任务 / Setup cron job
setup_cron() {
    local interval="${1:-5}"  # 默认 5 分钟 / Default 5 minutes
    
    print_header "设置挖矿收益监控定时任务（每${interval}分钟）"

    # 确保脚本有执行权限 / Ensure script has execute permissions
    chmod +x "$0"

    # 备份现有的 crontab / Backup existing crontab
    print_info "💾 备份现有的crontab..."
    crontab -l > "/tmp/crontab_backup_$(date +%Y%m%d_%H%M%S).txt" 2>/dev/null || echo "   (当前无crontab任务)"

    # 生成新的 cron 任务 / Generate new cron job
    local cron_job="*/${interval} * * * * $SCRIPT_DIR/$(basename "$0") monitor >> $(dirname "$LOG_FILE")/cron_mining.log 2>&1"

    echo ""
    print_info "📅 将添加的定时任务:"
    echo "   $cron_job"
    echo ""

    # 检查是否已存在相同的任务 / Check if similar task already exists
    if crontab -l 2>/dev/null | grep -F "$(basename "$0")" > /dev/null; then
        print_warning "检测到已存在的挖矿监控定时任务:"
        crontab -l | grep -F "$(basename "$0")"
        echo ""
        read -p "是否要替换现有任务? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "用户取消操作"
            exit 0
        fi
        
        # 移除现有相关任务 / Remove existing related tasks
        print_info "🗑️  移除现有任务..."
        (crontab -l 2>/dev/null | grep -v "$(basename "$0")" || true) | crontab -
    fi

    # 添加新任务 / Add new task
    print_info "➕ 添加新的定时任务..."
    (crontab -l 2>/dev/null || true; echo "$cron_job") | crontab -

    # 验证任务是否添加成功 / Verify task was added successfully
    echo ""
    print_success "定时任务设置完成！"
    echo ""
    print_info "📋 当前的crontab任务:"
    crontab -l | grep -E "$(basename "$0")" || echo "   (未找到相关任务)"

    echo ""
    print_info "📊 任务详情:"
    echo "   执行频率: 每${interval}分钟"
    echo "   脚本路径: $SCRIPT_DIR/$(basename "$0")"
    echo "   日志文件: $(dirname "$LOG_FILE")/cron_mining.log"
    echo "   配置文件: $CONFIG_FILE"
    echo ""
    print_info "🔍 常用命令:"
    echo "   查看日志: tail -f $(dirname "$LOG_FILE")/cron_mining.log"
    echo "   查看定时: crontab -l"
    echo "   移除定时: crontab -e (手动删除对应行)"
    echo ""
    
    # 显示下次执行时间 / Show next execution time
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
    print_success "🎉 设置完成！"
}

# =============================================================================
# 测试和演示函数 / Test and Demo Functions
# =============================================================================

# 测试当前设置 / Test current setup
test_setup() {
    print_header "测试挖矿监控脚本配置"
    echo ""

    # 检查配置文件 / Check configuration file
    if [[ -f "$CONFIG_FILE" ]]; then
        print_success "配置文件存在: $CONFIG_FILE"
        echo ""
        print_info "📄 配置文件内容:"
        cat "$CONFIG_FILE"
    else
        print_warning "配置文件不存在: $CONFIG_FILE"
    fi

    echo ""
    print_info "📋 当前配置信息:"

    # 显示 API 配置 / Show API configuration
    echo "  🔗 XMR API: SupportXMR"
    echo "  🔗 XTM API: LuckyPool"
    echo "  📁 日志目录: $(dirname "$LOG_FILE")"
    echo "  🔔 微信通知: $([ -n "$WECHAT_WEBHOOK_URL" ] && echo "已配置" || echo "未配置")"

    echo ""
    print_info "🔍 测试脚本运行..."

    # 使用临时目录进行测试 / Use temporary directory for testing
    local test_log="/tmp/mining_test_$(date +%s).log"
    local test_xmr_history="/tmp/xmr_history_test.txt"
    local test_xtm_history="/tmp/xtm_history_test.txt"

    echo "  日志文件: $test_log"
    echo "  XMR历史: $test_xmr_history"
    echo "  XTM历史: $test_xtm_history"

    # 运行测试（30秒超时）/ Run test with 30-second timeout
    echo ""
    print_info "⏱️  开始测试运行（30秒超时）..."

    if timeout 30 LOG_FILE_PATH="$test_log" \
       XMR_BALANCE_HISTORY_PATH="$test_xmr_history" \
       XTM_BALANCE_HISTORY_PATH="$test_xtm_history" \
       "$0" monitor > /dev/null 2>&1; then
        
        print_success "脚本运行成功！"
        
        # 显示日志的最后几行 / Show last few lines of log
        if [[ -f "$test_log" ]]; then
            echo ""
            print_info "📊 运行日志（最后10行）:"
            tail -10 "$test_log" | sed 's/^/  /'
        fi
        
    else
        print_error "脚本运行失败或超时"
        if [[ -f "$test_log" ]]; then
            echo ""
            print_error "📊 错误日志:"
            tail -10 "$test_log" | sed 's/^/  /'
        fi
    fi

    # 清理测试文件 / Clean up test files
    rm -f "$test_log" "$test_xmr_history" "$test_xtm_history"

    echo ""
    print_info "🎯 下一步:"
    echo "   如果测试通过，运行以下命令设置5分钟定时任务:"
    echo "   $0 cron 5"
    echo ""
    print_info "💡 手动设置定时任务:"
    echo "   crontab -e"
    echo "   添加行: */5 * * * * $SCRIPT_DIR/$(basename "$0") monitor >> $(dirname "$LOG_FILE")/cron_mining.log 2>&1"
}

# 演示功能 / Demo functionality
demo_functionality() {
    print_header "挖矿监控功能演示"
    echo ""

    print_info "📋 可用功能:"
    echo "  1. 实时监控 XMR + XTM 挖矿收益"
    echo "  2. 获取最新加密货币价格"
    echo "  3. 计算 USD 价值"
    echo "  4. 跟踪收益增长"
    echo "  5. 微信机器人推送"
    echo "  6. 历史数据记录"
    echo ""

    print_info "🔍 演示监控功能："
    read -p "按 Enter 键开始演示..." -r
    "$0" monitor
    echo ""
    print_success "演示完成！"
    
    echo ""
    print_info "💡 使用建议:"
    echo "  - 设置定时任务: $0 cron 30"
    echo "  - 启动守护进程: $0 start"
    echo "  - 配置微信机器人获得实时推送通知"
}

# =============================================================================
# 主要功能函数 / Main Functionality Functions
# =============================================================================

# 运行一次监控 / Run monitor once
run_monitor() {
    setup_directories
    
    log_message "INFO" "Starting Unified Mining Monitor (XMR + XTM)..."

    # 检查依赖 / Check dependencies
    check_dependencies

    # 初始化成功标志 / Initialize success flags
    local xmr_success=false
    local xtm_success=false

    # 获取和解析 XMR 余额数据 / Fetch and parse XMR balance data
    local xmr_balance_data
    xmr_balance_data=$(fetch_xmr_balance_data)
    if parse_xmr_balance_data "$xmr_balance_data"; then
        xmr_success=true
        log_message "INFO" "XMR data processing completed successfully"
    else
        log_message "ERROR" "XMR data processing failed"
    fi

    # 获取和解析 XTM 余额数据 / Fetch and parse XTM balance data
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

    # 从 XT 交易所获取价格数据 / Fetch price data from XT exchange
    log_message "INFO" "Fetching cryptocurrency prices..."
    XMR_PRICE=$(fetch_xmr_price)
    XTM_PRICE=$(fetch_xtm_price)
    
    # 调试价格获取结果 / Debug price fetching results
    log_message "DEBUG" "Fetched XMR_PRICE: '$XMR_PRICE'"
    log_message "DEBUG" "Fetched XTM_PRICE: '$XTM_PRICE'"
    
    # 导出价格变量 / Export price variables
    export XMR_PRICE
    export XTM_PRICE

    # 如果有余额数据则计算 USD 价值 / Calculate USD values if we have balance data
    if [[ "$xmr_success" == true ]] || [[ "$xtm_success" == true ]]; then
        calculate_usd_values
    fi

    # 只有在至少一种货币成功时才显示输出和发送警报 / Only display output and send alerts if at least one currency succeeded
    if [[ "$xmr_success" == true ]] || [[ "$xtm_success" == true ]]; then
        # 显示输出 / Display output
        display_console_output

        # 如果配置了微信警报则发送 / Send WeChat alert if configured
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

# =============================================================================
# 帮助和版本信息 / Help and Version Information
# =============================================================================

# 显示使用信息 / Show usage information
usage() {
    cat << EOF
${WHITE}
=============================================================================
${PURPLE}${SCRIPT_NAME} v${SCRIPT_VERSION}${WHITE}
=============================================================================

${CYAN}使用方法 / Usage:${NC}
    $0 [COMMAND] [OPTIONS]

${CYAN}命令 / Commands:${NC}
    ${GREEN}monitor${NC}              运行一次挖矿监控（默认命令）
    ${GREEN}start${NC}                启动守护进程（每5分钟运行一次）
    ${GREEN}stop${NC}                 停止守护进程
    ${GREEN}status${NC}               查看守护进程状态
    ${GREEN}restart${NC}              重启守护进程
    ${GREEN}logs${NC}                 查看实时日志
    ${GREEN}cron [INTERVAL]${NC}      设置定时任务 (默认5分钟)
    ${GREEN}test${NC}                 测试当前配置
    ${GREEN}demo${NC}                 演示功能
    ${GREEN}-h, --help${NC}           显示此帮助信息
    ${GREEN}-v, --version${NC}        显示版本信息

${CYAN}示例 / Examples:${NC}
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

    # 演示功能
    $0 demo

${CYAN}环境变量 / Environment Variables:${NC}
    ${YELLOW}WECHAT_WEBHOOK_URL${NC}           微信机器人Webhook地址
    ${YELLOW}LOG_FILE_PATH${NC}               日志文件路径
    ${YELLOW}XMR_BALANCE_HISTORY_PATH${NC}    XMR余额历史文件路径
    ${YELLOW}XTM_BALANCE_HISTORY_PATH${NC}    XTM余额历史文件路径

${CYAN}配置 / Configuration:${NC}
    配置文件: ${YELLOW}$CONFIG_FILE${NC}
    日志文件: ${YELLOW}$LOG_FILE${NC}
    数据源: SupportXMR Pool & XTM LuckyPool & XT Exchange

${CYAN}守护进程管理 / Daemon Management:${NC}
    PID文件: ${YELLOW}$PID_FILE${NC}
    日志目录: ${YELLOW}$(dirname "$LOG_FILE")${NC}

${GREEN}功能特性 / Features:${NC}
    ✅ XMR + XTM 双币种监控
    ✅ 实时价格获取和 USD 价值计算
    ✅ 微信机器人推送通知
    ✅ 收益增长跟踪
    ✅ 历史数据记录
    ✅ 守护进程和定时任务管理
    ✅ 完善的错误处理和日志记录

${WHITE}=============================================================================${NC}
EOF
}

# 显示版本信息 / Show version information
show_version() {
    cat << EOF
${PURPLE}${SCRIPT_NAME}${NC} v${GREEN}${SCRIPT_VERSION}${NC}
Author: DevOps Engineer
Date: ${SCRIPT_DATE}
Description: All-in-one mining monitor with comprehensive management capabilities

${CYAN}Features:${NC}
- Dual cryptocurrency monitoring (XMR + XTM)
- Real-time price fetching and USD value calculation
- WeChat bot notifications
- Mining reward growth tracking
- Historical data recording
- Daemon process and cron job management
- Comprehensive error handling and logging

${CYAN}Data Sources:${NC}
- XMR: SupportXMR Pool API
- XTM: LuckyPool API
- Prices: XT Exchange API
EOF
}

# =============================================================================
# 主执行逻辑 / Main Execution Logic
# =============================================================================

# 主函数 / Main function
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
            demo_functionality
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
            print_error "未知命令: $command"
            echo "使用 '$0 --help' 查看使用说明。"
            exit 1
            ;;
    esac
}

# 信号处理 / Signal handling
trap 'log_message "INFO" "Script interrupted"' INT TERM

# =============================================================================
# 脚本入口点 / Script Entry Point
# =============================================================================

# 显示启动信息 / Show startup info
if [[ "${1:-}" != "-h" && "${1:-}" != "--help" && "${1:-}" != "-v" && "${1:-}" != "--version" ]]; then
    echo -e "${CYAN}🚀 ${SCRIPT_NAME} v${SCRIPT_VERSION} 启动中...${NC}"
fi

# 运行主函数 / Run main function
main "$@"