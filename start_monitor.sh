#!/bin/bash

# Mining Balance Monitor - 定时启动脚本
# 每5分钟自动执行一次监控
# 自动处理目录创建和权限问题

echo "🚀 启动挖矿余额定时监控脚本..."
echo "⏰ 监控间隔: 5分钟"
echo "🛑 按 Ctrl+C 停止监控"
echo "================================"

# 信号处理函数
cleanup() {
    echo ""
    echo "================================"
    echo "🛑 收到停止信号，正在退出..."
    echo "✅ 定时监控已停止！"
    exit 0
}

# 捕获 SIGINT (Ctrl+C) 和 SIGTERM 信号
trap cleanup SIGINT SIGTERM

# 定时监控循环
run_monitor_loop() {
    local monitor_script="$(dirname "$0")/mining_balance_monitor.sh"
    local iteration=1
    
    while true; do
        echo "📊 执行第 $iteration 次监控 [$(date '+%Y-%m-%d %H:%M:%S')]"
        echo "--------------------------------"
        
        # 运行监控脚本
        if [[ $EUID -eq 0 ]]; then
            # root 用户
            "$monitor_script"
        else
            # 非 root 用户，使用环境变量覆盖路径
            USER_DIR="$HOME/mining_monitor"
            LOG_FILE_PATH="$USER_DIR/mining.log" \
            XMR_BALANCE_HISTORY_PATH="$USER_DIR/xmr_history.txt" \
            XTM_BALANCE_HISTORY_PATH="$USER_DIR/xtm_history.txt" \
            "$monitor_script"
        fi
        
        echo "--------------------------------"
        echo "✅ 第 $iteration 次监控完成"
        echo "⏰ 等待 5 分钟后进行下次监控..."
        echo "💡 按 Ctrl+C 停止定时监控"
        echo ""
        
        # 等待5分钟（300秒）
        sleep 300
        
        ((iteration++))
    done
}

# 检查是否以 root 身份运行
if [[ $EUID -eq 0 ]]; then
    echo "✅ 检测到 root 权限"
    
    # 创建默认目录
    mkdir -p /root/MINING
    chmod 755 /root/MINING
    
    echo "✅ 目录准备完成"
    
else
    echo "⚠️  检测到非 root 用户，使用临时目录..."
    
    # 使用用户目录
    USER_DIR="$HOME/mining_monitor"
    mkdir -p "$USER_DIR"
    
    echo "✅ 使用目录: $USER_DIR"
fi

echo ""
echo "🔄 开始定时监控循环..."
echo "================================"

# 开始定时监控
run_monitor_loop