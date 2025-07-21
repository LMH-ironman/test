#!/bin/bash

# 挖矿收益监控守护进程
# Mining Balance Monitor Daemon - runs every 5 minutes

set -euo pipefail

echo "=== 挖矿收益监控守护进程启动 ==="
echo "开始时间: $(date)"
echo "执行频率: 每5分钟"
echo "脚本路径: $(pwd)/mining_balance_monitor.sh"

# 创建日志目录
LOG_DIR="$HOME/mining_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/mining_monitor.log"

echo "日志文件: $LOG_FILE"
echo ""

# 检查主脚本是否存在
if [[ ! -f "mining_balance_monitor.sh" ]]; then
    echo "❌ 错误: 找不到 mining_balance_monitor.sh"
    exit 1
fi

# 确保脚本有执行权限
chmod +x mining_balance_monitor.sh

# 记录启动信息到日志
echo "$(date '+%Y-%m-%d %H:%M:%S') [DAEMON] 挖矿监控守护进程启动" >> "$LOG_FILE"

# 运行计数器
run_count=0

# 主循环
while true; do
    run_count=$((run_count + 1))
    
    echo "🔄 执行第 $run_count 次监控 - $(date '+%H:%M:%S')"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DAEMON] 开始第 $run_count 次执行" >> "$LOG_FILE"
    
    # 运行挖矿监控脚本
    if ./mining_balance_monitor.sh >> "$LOG_FILE" 2>&1; then
        echo "✅ 第 $run_count 次执行成功"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [DAEMON] 第 $run_count 次执行成功" >> "$LOG_FILE"
    else
        echo "❌ 第 $run_count 次执行失败"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [DAEMON] 第 $run_count 次执行失败" >> "$LOG_FILE"
    fi
    
    # 显示下次执行时间
    next_time=$(date -d '+5 minutes' '+%H:%M:%S')
    echo "⏰ 下次执行时间: $next_time"
    echo ""
    
    # 等待5分钟 (300秒)
    sleep 300
done