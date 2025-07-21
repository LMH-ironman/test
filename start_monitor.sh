#!/bin/bash

# Mining Balance Monitor - 快速启动脚本
# 自动处理目录创建和权限问题

echo "🚀 启动挖矿余额监控脚本..."

# 检查是否以 root 身份运行
if [[ $EUID -eq 0 ]]; then
    echo "✅ 检测到 root 权限"
    
    # 创建默认目录
    mkdir -p /root/MINING
    chmod 755 /root/MINING
    
    echo "✅ 目录准备完成"
    echo "📊 开始监控..."
    echo "================================"
    
    # 以 5 分钟间隔循环运行监控脚本
    while true; do
        "$(dirname "$0")/mining_balance_monitor.sh"
        echo "🔄 下一次监控将在 5 分钟后运行..."
        sleep 300
    done
    
else
    echo "⚠️  检测到非 root 用户，使用临时目录..."
    
    # 使用用户目录
    USER_DIR="$HOME/mining_monitor"
    mkdir -p "$USER_DIR"
    
    echo "✅ 使用目录: $USER_DIR"
    echo "📊 开始监控..."
    echo "================================"
    
    # 以 5 分钟间隔循环运行监控脚本（非 root 用户）
    while true; do
        LOG_FILE_PATH="$USER_DIR/mining.log" \
        XMR_BALANCE_HISTORY_PATH="$USER_DIR/xmr_history.txt" \
        XTM_BALANCE_HISTORY_PATH="$USER_DIR/xtm_history.txt" \
        "$(dirname "$0")/mining_balance_monitor.sh"
        echo "🔄 下一次监控将在 5 分钟后运行..."
        sleep 300
    done
fi

echo "================================"
echo "✅ 监控完成！"