#!/bin/bash

# =============================================================================
# 简洁挖矿监控脚本 - Simple Mining Monitor
# =============================================================================
# 功能：XMR + XTM 挖矿产出、币价、收益计算，记录近三小时收益
# =============================================================================

set -euo pipefail

# 配置
readonly XMR_API_URL="https://www.supportxmr.com/api/miner/45GkAa8FmTMWjeM1jCnH1r8psZWMBCi3vdmdrPqPCdDHRS4RZqb2Tnc55BqkUmuhd9KwvvhcoAVRqZMJVWe6wT3V32ZbN5W/stats"
readonly XTM_WALLET_ADDRESS="16meX2eiPWFAAU94fRF8u2DejfpQaV21a8bqYQviMDaSKfwuCgQJNAEauk9PTnx3jmKkTVuLXrgcbmXtAvtVUvn6K3BpkDjZeVnSuv1qMKY"
readonly XTM_API_URL="https://api-tari.luckypool.io/stats_address?address=${XTM_WALLET_ADDRESS}"
readonly XMR_PRICE_API_URL="https://www.xt.com/sapi/v4/market/public/ticker/24h?symbol=xmr_usdt"
readonly XTM_PRICE_API_URL="https://www.xt.com/sapi/v4/market/public/ticker/24h?symbol=xtm_usdt"

# 文件路径
readonly DATA_DIR="$HOME/mining_data"
readonly REVENUE_LOG="$DATA_DIR/revenue_log.txt"
readonly XMR_HISTORY="$DATA_DIR/xmr_history.txt"
readonly XTM_HISTORY="$DATA_DIR/xtm_history.txt"

# 创建数据目录
mkdir -p "$DATA_DIR"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 获取价格函数
get_price() {
    local api_url="$1"
    local price_field="$2"
    
    local response
    response=$(curl -s "$api_url" 2>/dev/null || echo "")
    
    if [[ -n "$response" ]]; then
        echo "$response" | grep -o "\"$price_field\":\"[^\"]*\"" | cut -d'"' -f4 | head -1
    else
        echo "0"
    fi
}

# 获取XMR数据
get_xmr_data() {
    local response
    response=$(curl -s "$XMR_API_URL" 2>/dev/null || echo "")
    
    if [[ -n "$response" ]]; then
        local balance_raw=$(echo "$response" | grep -o '"balance":[0-9]*' | cut -d':' -f2)
        local paid_raw=$(echo "$response" | grep -o '"paid":[0-9]*' | cut -d':' -f2)
        
        if [[ -n "$balance_raw" && -n "$paid_raw" ]]; then
            local balance=$(echo "scale=12; $balance_raw / 1000000000000" | bc -l)
            local paid=$(echo "scale=12; $paid_raw / 1000000000000" | bc -l)
            local total=$(echo "scale=12; $balance + $paid" | bc -l)
            
            echo "$balance,$paid,$total"
        else
            echo "0,0,0"
        fi
    else
        echo "0,0,0"
    fi
}

# 获取XTM数据
get_xtm_data() {
    local response
    response=$(curl -s "$XTM_API_URL" 2>/dev/null || echo "")
    
    if [[ -n "$response" ]]; then
        local balance_raw=$(echo "$response" | grep -o '"balance":[0-9.]*' | cut -d':' -f2)
        local paid_raw=$(echo "$response" | grep -o '"paid":[0-9.]*' | cut -d':' -f2)
        
        if [[ -n "$balance_raw" && -n "$paid_raw" ]]; then
            local balance=$(printf "%.8f" "$balance_raw")
            local paid=$(printf "%.8f" "$paid_raw")
            local total=$(echo "scale=8; $balance + $paid" | bc -l)
            
            echo "$balance,$paid,$total"
        else
            echo "0,0,0"
        fi
    else
        echo "0,0,0"
    fi
}

# 计算收益变化
calculate_revenue() {
    local current_total="$1"
    local history_file="$2"
    local hours_ago="$3"
    
    if [[ ! -f "$history_file" ]]; then
        echo "0"
        return
    fi
    
    local target_time=$(date -d "$hours_ago hours ago" +%s)
    local closest_record=""
    local min_diff=999999999
    
    while IFS=',' read -r timestamp total _; do
        local diff=$((target_time - timestamp))
        diff=${diff#-}  # 取绝对值
        
        if [[ $diff -lt $min_diff ]]; then
            min_diff=$diff
            closest_record="$total"
        fi
    done < "$history_file"
    
    if [[ -n "$closest_record" ]]; then
        echo "scale=8; $current_total - $closest_record" | bc -l
    else
        echo "0"
    fi
}

# 记录历史数据
record_history() {
    local timestamp=$(date +%s)
    local xmr_data="$1"
    local xtm_data="$2"
    
    local xmr_total=$(echo "$xmr_data" | cut -d',' -f3)
    local xtm_total=$(echo "$xtm_data" | cut -d',' -f3)
    
    echo "$timestamp,$xmr_total,$(date '+%Y-%m-%d %H:%M:%S')" >> "$XMR_HISTORY"
    echo "$timestamp,$xtm_total,$(date '+%Y-%m-%d %H:%M:%S')" >> "$XTM_HISTORY"
    
    # 保留最近7天的记录
    local cutoff_time=$(date -d "7 days ago" +%s)
    
    for file in "$XMR_HISTORY" "$XTM_HISTORY"; do
        if [[ -f "$file" ]]; then
            awk -F',' -v cutoff="$cutoff_time" '$1 >= cutoff' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
        fi
    done
}

# 主监控函数
main_monitor() {
    log "开始挖矿数据监控..."
    
    # 获取当前数据
    local xmr_data=$(get_xmr_data)
    local xtm_data=$(get_xtm_data)
    
    # 获取价格
    local xmr_price=$(get_price "$XMR_PRICE_API_URL" "c")
    local xtm_price=$(get_price "$XTM_PRICE_API_URL" "c")
    
    # 解析数据
    IFS=',' read -r xmr_balance xmr_paid xmr_total <<< "$xmr_data"
    IFS=',' read -r xtm_balance xtm_paid xtm_total <<< "$xtm_data"
    
    # 记录历史数据
    record_history "$xmr_data" "$xtm_data"
    
    # 计算收益变化
    local xmr_revenue_1h=$(calculate_revenue "$xmr_total" "$XMR_HISTORY" "-1")
    local xmr_revenue_3h=$(calculate_revenue "$xmr_total" "$XMR_HISTORY" "-3")
    local xtm_revenue_1h=$(calculate_revenue "$xtm_total" "$XTM_HISTORY" "-1")
    local xtm_revenue_3h=$(calculate_revenue "$xtm_total" "$XTM_HISTORY" "-3")
    
    # 计算USD价值
    local xmr_value_usd=""
    local xtm_value_usd=""
    local total_revenue_1h_usd=""
    local total_revenue_3h_usd=""
    
    if [[ "$xmr_price" != "0" ]] && command -v bc >/dev/null 2>&1; then
        xmr_value_usd=$(echo "scale=2; $xmr_total * $xmr_price" | bc -l)
    else
        xmr_value_usd="计算失败"
    fi
    
    if [[ "$xtm_price" != "0" ]] && command -v bc >/dev/null 2>&1; then
        xtm_value_usd=$(echo "scale=2; $xtm_total * $xtm_price" | bc -l)
        total_revenue_1h_usd=$(echo "scale=2; ($xmr_revenue_1h * $xmr_price) + ($xtm_revenue_1h * $xtm_price)" | bc -l)
        total_revenue_3h_usd=$(echo "scale=2; ($xmr_revenue_3h * $xmr_price) + ($xtm_revenue_3h * $xtm_price)" | bc -l)
    else
        xtm_value_usd="计算失败"
        total_revenue_1h_usd="计算失败"
        total_revenue_3h_usd="计算失败"
    fi
    
    # 生成报告
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report=""
    
    report+="🚀 挖矿监控报告 - $timestamp\n"
    report+="\n📊 XMR (门罗币):\n"
    report+="  • 未支付: ${xmr_balance} XMR\n"
    report+="  • 已支付: ${xmr_paid} XMR\n"
    report+="  • 总计: ${xmr_total} XMR\n"
    report+="  • 价格: \$${xmr_price}\n"
    report+="  • 价值: \$${xmr_value_usd}\n"
    report+="  • 1小时产出: ${xmr_revenue_1h} XMR\n"
    report+="  • 3小时产出: ${xmr_revenue_3h} XMR\n"
    
    report+="\n🎯 XTM (Tarium):\n"
    report+="  • 未支付: ${xtm_balance} XTM\n"
    report+="  • 已支付: ${xtm_paid} XTM\n"
    report+="  • 总计: ${xtm_total} XTM\n"
    report+="  • 价格: \$${xtm_price}\n"
    report+="  • 价值: \$${xtm_value_usd}\n"
    report+="  • 1小时产出: ${xtm_revenue_1h} XTM\n"
    report+="  • 3小时产出: ${xtm_revenue_3h} XTM\n"
    
    report+="\n💰 收益汇总:\n"
    report+="  • 1小时总收益: \$${total_revenue_1h_usd}\n"
    report+="  • 3小时总收益: \$${total_revenue_3h_usd}\n"
    
    # 输出报告
    echo -e "$report"
    
    # 记录收益日志
    echo "$timestamp,$xmr_revenue_1h,$xmr_revenue_3h,$xtm_revenue_1h,$xtm_revenue_3h,$total_revenue_1h_usd,$total_revenue_3h_usd" >> "$REVENUE_LOG"
    
    log "监控完成"
}

# 显示近期收益
show_recent_revenue() {
    if [[ ! -f "$REVENUE_LOG" ]]; then
        echo "暂无收益记录"
        return
    fi
    
    echo "📈 近期收益记录（最近10次）:"
    echo "时间                  | 1H-XMR  | 3H-XMR  | 1H-XTM  | 3H-XTM  | 1H-USD | 3H-USD"
    echo "--------------------------------------------------------------------------------"
    
    tail -10 "$REVENUE_LOG" | while IFS=',' read -r timestamp xmr_1h xmr_3h xtm_1h xtm_3h usd_1h usd_3h; do
        printf "%-20s | %-7s | %-7s | %-7s | %-7s | %-6s | %-6s\n" \
               "$timestamp" "$xmr_1h" "$xmr_3h" "$xtm_1h" "$xtm_3h" "$usd_1h" "$usd_3h"
    done
}

# 清理旧数据
cleanup_old_data() {
    local cutoff_date=$(date -d "7 days ago" '+%Y-%m-%d')
    
    for file in "$REVENUE_LOG" "$XMR_HISTORY" "$XTM_HISTORY"; do
        if [[ -f "$file" ]]; then
            grep -v "^$cutoff_date" "$file" > "${file}.tmp" 2>/dev/null && mv "${file}.tmp" "$file" || rm -f "${file}.tmp"
        fi
    done
    
    log "清理完成：删除7天前的旧数据"
}

# 安装依赖
install_dependencies() {
    log "检查并安装依赖..."
    
    if ! command -v bc >/dev/null 2>&1; then
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y bc
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y bc
        else
            log "警告: 无法安装bc计算器，USD价值计算可能失败"
        fi
    fi
    
    log "依赖检查完成"
}

# 设置定时任务
setup_cron() {
    local cron_expr="0 * * * *"  # 每小时执行一次
    local script_path="$(realpath "$0")"
    local cron_command="$script_path monitor"
    
    # 检查是否已存在
    if crontab -l 2>/dev/null | grep -q "$script_path"; then
        log "定时任务已存在"
        return
    fi
    
    # 添加定时任务
    (crontab -l 2>/dev/null; echo "$cron_expr $cron_command") | crontab -
    log "定时任务已设置：每小时执行监控"
}

# 主函数
main() {
    case "${1:-monitor}" in
        "monitor")
            main_monitor
            ;;
        "history")
            show_recent_revenue
            ;;
        "cleanup")
            cleanup_old_data
            ;;
        "install")
            install_dependencies
            ;;
        "setup-cron")
            setup_cron
            ;;
        "help")
            echo "用法: $0 [monitor|history|cleanup|install|setup-cron|help]"
            echo "  monitor    - 执行监控（默认）"
            echo "  history    - 显示近期收益"
            echo "  cleanup    - 清理旧数据"
            echo "  install    - 安装依赖"
            echo "  setup-cron - 设置定时任务"
            echo "  help       - 显示帮助"
            ;;
        *)
            echo "未知参数: $1"
            echo "使用 '$0 help' 查看帮助"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"