#!/bin/bash

# 简化版5分钟定时任务设置脚本
# Simple 5-minute cron job setup script

set -euo pipefail

echo "=== 设置挖矿收益监控定时任务（每5分钟） ==="

# 获取当前脚本的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_SCRIPT="$SCRIPT_DIR/mining_balance_monitor.sh"
LOG_DIR="$HOME/mining_logs"

# 检查脚本是否存在
if [[ ! -f "$MONITOR_SCRIPT" ]]; then
    echo "❌ 错误: 找不到 mining_balance_monitor.sh 脚本"
    echo "   当前目录: $SCRIPT_DIR"
    exit 1
fi

# 确保脚本有执行权限
chmod +x "$MONITOR_SCRIPT"

# 创建日志目录（用户目录，无需sudo）
echo "📁 创建日志目录: $LOG_DIR"
mkdir -p "$LOG_DIR"

# 备份现有的crontab
echo "💾 备份现有的crontab..."
crontab -l > "/tmp/crontab_backup_$(date +%Y%m%d_%H%M%S).txt" 2>/dev/null || echo "   (当前无crontab任务)"

# 生成新的cron任务
CRON_JOB="*/5 * * * * $MONITOR_SCRIPT >> $LOG_DIR/mining_monitor.log 2>&1"

echo ""
echo "📅 将添加的定时任务:"
echo "   $CRON_JOB"
echo ""

# 检查是否已存在相同的任务
if crontab -l 2>/dev/null | grep -F "mining_balance_monitor.sh" > /dev/null; then
    echo "⚠️  检测到已存在的挖矿监控定时任务:"
    crontab -l | grep -F "mining_balance_monitor.sh"
    echo ""
    read -p "是否要替换现有任务? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 用户取消操作"
        exit 0
    fi
    
    # 移除现有相关任务
    echo "🗑️  移除现有任务..."
    (crontab -l 2>/dev/null | grep -v "mining_balance_monitor.sh" || true) | crontab -
fi

# 添加新任务
echo "➕ 添加新的定时任务..."
(crontab -l 2>/dev/null || true; echo "$CRON_JOB") | crontab -

# 验证任务是否添加成功
echo ""
echo "✅ 定时任务设置完成！"
echo ""
echo "📋 当前的crontab任务:"
crontab -l | grep -E "mining" || echo "   (未找到挖矿相关任务)"

echo ""
echo "📊 任务详情:"
echo "   执行频率: 每5分钟"
echo "   脚本路径: $MONITOR_SCRIPT"
echo "   日志文件: $LOG_DIR/mining_monitor.log"
echo "   配置文件: $SCRIPT_DIR/mining_config.env"
echo ""
echo "🔍 常用命令:"
echo "   查看日志: tail -f $LOG_DIR/mining_monitor.log"
echo "   查看定时: crontab -l"
echo "   移除定时: crontab -e (手动删除对应行)"
echo ""
echo "⏱️  下次执行时间: 下一个5分钟整点"

# 显示当前时间和下次执行时间
current_minute=$(date +%M)
current_second=$(date +%S)
next_minute=$(( (current_minute / 5 + 1) * 5 ))
if [ $next_minute -ge 60 ]; then
    next_minute=$(( next_minute - 60 ))
    next_hour=$(( $(date +%H) + 1 ))
    if [ $next_hour -ge 24 ]; then
        next_hour=0
    fi
else
    next_hour=$(date +%H)
fi

echo "   当前时间: $(date '+%H:%M:%S')"
printf "   下次执行: %02d:%02d:00\n" $next_hour $next_minute

echo ""
echo "🎉 设置完成！"
echo ""
echo "💡 提示:"
echo "   - 请确保配置文件 mining_config.env 中的微信Webhook地址正确"
echo "   - 脚本会自动检查依赖并安装 bc 和 jq"
echo "   - 首次运行可能需要一些时间来安装依赖"