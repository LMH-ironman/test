#!/bin/bash

# 设置5分钟定时任务脚本
# Setup 5-minute cron job script

set -euo pipefail

echo "=== 设置挖矿收益监控定时任务（每5分钟） ==="

# 获取当前脚本的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_SCRIPT="$SCRIPT_DIR/mining_balance_monitor.sh"
LOG_DIR="/root/MINING"

# 检查脚本是否存在
if [[ ! -f "$MONITOR_SCRIPT" ]]; then
    echo "❌ 错误: 找不到 mining_balance_monitor.sh 脚本"
    echo "   请确保脚本在当前目录: $SCRIPT_DIR"
    exit 1
fi

# 确保脚本有执行权限
chmod +x "$MONITOR_SCRIPT"

# 创建日志目录
echo "📁 创建日志目录: $LOG_DIR"
sudo mkdir -p "$LOG_DIR"

# 备份现有的crontab
echo "💾 备份现有的crontab..."
crontab -l > /tmp/crontab_backup_$(date +%Y%m%d_%H%M%S).txt 2>/dev/null || true

# 生成新的cron任务
CRON_JOB="*/5 * * * * $MONITOR_SCRIPT >> $LOG_DIR/cron_mining.log 2>&1"

echo "📅 添加定时任务:"
echo "   $CRON_JOB"

# 检查是否已存在相同的任务
if crontab -l 2>/dev/null | grep -F "$MONITOR_SCRIPT" > /dev/null; then
    echo "⚠️  检测到已存在的挖矿监控定时任务"
    read -p "是否要替换现有任务? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 用户取消操作"
        exit 0
    fi
    
    # 移除现有相关任务
    echo "🗑️  移除现有任务..."
    (crontab -l 2>/dev/null | grep -v "$MONITOR_SCRIPT" || true) | crontab -
fi

# 添加新任务
echo "➕ 添加新的定时任务..."
(crontab -l 2>/dev/null || true; echo "$CRON_JOB") | crontab -

# 验证任务是否添加成功
echo ""
echo "✅ 定时任务设置完成！"
echo ""
echo "📋 当前的crontab任务:"
crontab -l | grep -E "(mining|MINING)" || echo "   (未找到挖矿相关任务)"

echo ""
echo "📊 任务详情:"
echo "   执行频率: 每5分钟"
echo "   脚本路径: $MONITOR_SCRIPT"
echo "   日志文件: $LOG_DIR/cron_mining.log"
echo ""
echo "🔍 查看日志命令:"
echo "   tail -f $LOG_DIR/cron_mining.log"
echo ""
echo "⏱️  下次执行时间: $(date -d '+5 minutes' '+%H:%M')"

echo ""
echo "🎉 设置完成！脚本将每5分钟自动运行一次。"