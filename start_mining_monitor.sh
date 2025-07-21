#!/bin/bash

# 挖矿监控启动管理脚本
# Mining Monitor Start Management Script

set -euo pipefail

LOG_DIR="$HOME/mining_logs"
PID_FILE="$LOG_DIR/mining_daemon.pid"
LOG_FILE="$LOG_DIR/mining_monitor.log"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 显示使用说明
usage() {
    echo "用法: $0 {start|stop|status|restart|logs}"
    echo ""
    echo "命令说明:"
    echo "  start   - 启动挖矿监控守护进程（每5分钟运行一次）"
    echo "  stop    - 停止挖矿监控守护进程"
    echo "  status  - 查看守护进程状态"
    echo "  restart - 重启守护进程"
    echo "  logs    - 查看实时日志"
    echo ""
    echo "配置信息:"
    echo "  XMR池: SupportXMR"
    echo "  XTM池: LuckyPool"
    echo "  频率: 每5分钟"
    echo "  日志: $LOG_FILE"
}

# 启动守护进程
start_daemon() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "⚠️  挖矿监控守护进程已在运行 (PID: $(cat "$PID_FILE"))"
        return 1
    fi
    
    echo "🚀 启动挖矿监控守护进程..."
    
    # 检查脚本文件
    if [[ ! -f "mining_daemon.sh" ]]; then
        echo "❌ 错误: 找不到 mining_daemon.sh"
        return 1
    fi
    
    # 后台启动守护进程
    nohup ./mining_daemon.sh > "$LOG_DIR/daemon_output.log" 2>&1 &
    daemon_pid=$!
    
    # 保存PID
    echo "$daemon_pid" > "$PID_FILE"
    
    echo "✅ 守护进程已启动 (PID: $daemon_pid)"
    echo "📊 日志文件: $LOG_FILE"
    echo "🔍 查看日志: $0 logs"
    echo ""
    echo "💡 守护进程将每5分钟执行一次挖矿收益监控"
}

# 停止守护进程
stop_daemon() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo "⚠️  没有找到PID文件，守护进程可能未运行"
        return 1
    fi
    
    local pid=$(cat "$PID_FILE")
    
    if kill -0 "$pid" 2>/dev/null; then
        echo "🛑 停止挖矿监控守护进程 (PID: $pid)..."
        kill "$pid"
        
        # 等待进程结束
        sleep 2
        
        if kill -0 "$pid" 2>/dev/null; then
            echo "⚠️  进程未能正常结束，强制终止..."
            kill -9 "$pid"
        fi
        
        rm -f "$PID_FILE"
        echo "✅ 守护进程已停止"
    else
        echo "⚠️  进程 $pid 不存在，清理PID文件"
        rm -f "$PID_FILE"
    fi
}

# 查看状态
show_status() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        local pid=$(cat "$PID_FILE")
        echo "✅ 挖矿监控守护进程正在运行"
        echo "   PID: $pid"
        echo "   启动时间: $(ps -o lstart= -p "$pid" 2>/dev/null || echo '未知')"
        echo "   日志文件: $LOG_FILE"
        
        if [[ -f "$LOG_FILE" ]]; then
            local last_run=$(tail -1 "$LOG_FILE" | grep -o '^[0-9-]* [0-9:]*' || echo '未知')
            echo "   最后执行: $last_run"
        fi
    else
        echo "❌ 挖矿监控守护进程未运行"
        if [[ -f "$PID_FILE" ]]; then
            rm -f "$PID_FILE"
        fi
    fi
}

# 查看日志
show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        echo "📊 实时日志 (按 Ctrl+C 退出):"
        echo "----------------------------------------"
        tail -f "$LOG_FILE"
    else
        echo "❌ 日志文件不存在: $LOG_FILE"
    fi
}

# 重启守护进程
restart_daemon() {
    echo "🔄 重启挖矿监控守护进程..."
    stop_daemon 2>/dev/null || true
    sleep 2
    start_daemon
}

# 主逻辑
case "${1:-}" in
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    status)
        show_status
        ;;
    restart)
        restart_daemon
        ;;
    logs)
        show_logs
        ;;
    *)
        usage
        exit 1
        ;;
esac