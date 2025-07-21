#!/bin/bash

# Mining Balance Monitor - 后台守护进程启动脚本
# 在后台运行定时监控，支持启动、停止、状态查看等操作

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_SCRIPT="$SCRIPT_DIR/start_monitor.sh"
PID_FILE="/tmp/mining_monitor.pid"
LOG_FILE="/tmp/mining_monitor_daemon.log"

# 检查是否以root身份运行，如果不是，调整路径
if [[ $EUID -ne 0 ]]; then
    PID_FILE="$HOME/mining_monitor.pid"
    LOG_FILE="$HOME/mining_monitor_daemon.log"
fi

usage() {
    cat << EOF
Usage: $0 {start|stop|restart|status}

Mining Balance Monitor Daemon Control Script

Commands:
    start    - 启动后台定时监控
    stop     - 停止后台定时监控
    restart  - 重启后台定时监控
    status   - 查看监控状态

Examples:
    $0 start    # 启动后台监控
    $0 stop     # 停止后台监控
    $0 status   # 查看状态
EOF
}

# 启动监控
start_monitor() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "❌ 监控已经在运行中 (PID: $pid)"
            return 1
        else
            echo "🧹 清理过期的PID文件..."
            rm -f "$PID_FILE"
        fi
    fi
    
    echo "🚀 启动挖矿余额定时监控..."
    echo "📝 日志文件: $LOG_FILE"
    echo "🔧 PID文件: $PID_FILE"
    
    # 在后台启动监控脚本
    nohup "$MONITOR_SCRIPT" > "$LOG_FILE" 2>&1 &
    local pid=$!
    
    # 保存PID
    echo "$pid" > "$PID_FILE"
    
    # 等待一下确保进程启动
    sleep 2
    
    if kill -0 "$pid" 2>/dev/null; then
        echo "✅ 定时监控已启动 (PID: $pid)"
        echo "💡 使用 '$0 stop' 停止监控"
        echo "💡 使用 '$0 status' 查看状态"
        echo "💡 使用 'tail -f $LOG_FILE' 查看实时日志"
    else
        echo "❌ 监控启动失败"
        rm -f "$PID_FILE"
        return 1
    fi
}

# 停止监控
stop_monitor() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo "❌ 监控未运行（找不到PID文件）"
        return 1
    fi
    
    local pid=$(cat "$PID_FILE")
    
    if kill -0 "$pid" 2>/dev/null; then
        echo "🛑 正在停止监控 (PID: $pid)..."
        kill "$pid"
        
        # 等待进程结束
        local count=0
        while kill -0 "$pid" 2>/dev/null && [[ $count -lt 10 ]]; do
            sleep 1
            ((count++))
        done
        
        if kill -0 "$pid" 2>/dev/null; then
            echo "⚠️  进程未正常结束，强制终止..."
            kill -9 "$pid"
        fi
        
        rm -f "$PID_FILE"
        echo "✅ 监控已停止"
    else
        echo "❌ 进程已不存在，清理PID文件..."
        rm -f "$PID_FILE"
    fi
}

# 查看状态
show_status() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo "📊 监控状态: 未运行"
        return 0
    fi
    
    local pid=$(cat "$PID_FILE")
    
    if kill -0 "$pid" 2>/dev/null; then
        echo "📊 监控状态: 运行中"
        echo "🔧 进程ID: $pid"
        echo "📝 日志文件: $LOG_FILE"
        echo "⏰ 运行时间: $(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ')"
        echo ""
        echo "💡 查看实时日志: tail -f $LOG_FILE"
        echo "💡 停止监控: $0 stop"
    else
        echo "📊 监控状态: 进程已停止（PID文件存在但进程不存在）"
        echo "🧹 建议执行: $0 stop （清理PID文件）"
    fi
}

# 重启监控
restart_monitor() {
    echo "🔄 重启监控..."
    stop_monitor
    sleep 2
    start_monitor
}

# 主逻辑
case "${1:-}" in
    start)
        start_monitor
        ;;
    stop)
        stop_monitor
        ;;
    restart)
        restart_monitor
        ;;
    status)
        show_status
        ;;
    *)
        usage
        exit 1
        ;;
esac