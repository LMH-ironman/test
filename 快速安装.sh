#!/bin/bash

# =============================================================================
# 统一挖矿监控脚本 - 快速安装脚本
# =============================================================================
# 这个脚本演示了如何快速设置和启动挖矿监控
# =============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 打印函数
print_success() { echo -e "${GREEN}✅ $*${NC}"; }
print_error() { echo -e "${RED}❌ $*${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $*${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
print_header() { echo -e "${PURPLE}🚀 $*${NC}"; }

# 主安装函数
main() {
    clear
    print_header "==============================================="
    print_header "     统一挖矿监控脚本 - 快速安装向导"
    print_header "==============================================="
    echo ""
    
    print_info "这个脚本将帮助您快速设置挖矿监控系统"
    echo ""
    
    # 1. 检查统一脚本是否存在
    print_info "步骤 1: 检查脚本文件..."
    if [[ ! -f "unified_mining_monitor.sh" ]]; then
        print_error "unified_mining_monitor.sh 文件不存在"
        print_info "请确保 unified_mining_monitor.sh 文件在当前目录中"
        exit 1
    fi
    print_success "找到 unified_mining_monitor.sh 文件"
    
    # 2. 设置执行权限
    print_info "步骤 2: 设置执行权限..."
    chmod +x unified_mining_monitor.sh
    print_success "执行权限设置完成"
    
    # 3. 检查配置文件
    print_info "步骤 3: 检查配置文件..."
    if [[ ! -f "mining_config.env" ]]; then
        print_warning "配置文件不存在，创建默认配置..."
        cat > mining_config.env << 'EOF'
# Mining Balance Monitor Configuration File
# 配置文件优先级：环境变量 > 配置文件 > 脚本默认值

# 微信机器人 Webhook URL
WECHAT_WEBHOOK_URL="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=3fc21e51-d7b7-46ca-9b86-f68deab4fd61"

# 日志文件路径
LOG_FILE_PATH="/root/MINING/mining_monitor.log"

# XMR 余额历史文件路径
XMR_BALANCE_HISTORY_PATH="/root/MINING/xmr_balance_history.txt"

# XTM 余额历史文件路径
XTM_BALANCE_HISTORY_PATH="/root/MINING/xtm_balance_history.txt"
EOF
        print_success "创建默认配置文件 mining_config.env"
    else
        print_success "配置文件已存在"
    fi
    
    # 4. 测试脚本功能
    print_info "步骤 4: 测试脚本功能..."
    echo ""
    print_info "运行配置测试..."
    if ./unified_mining_monitor.sh test; then
        print_success "脚本测试通过"
    else
        print_warning "脚本测试遇到问题，但可以继续"
    fi
    echo ""
    
    # 5. 选择部署方式
    print_info "步骤 5: 选择部署方式"
    echo ""
    echo "请选择您想要的部署方式："
    echo "1) 守护进程模式 (推荐) - 每5分钟自动运行"
    echo "2) 定时任务模式 - 每30分钟运行一次"
    echo "3) 手动运行模式 - 仅运行一次测试"
    echo "4) 退出安装"
    echo ""
    
    while true; do
        read -p "请输入选择 (1-4): " choice
        case $choice in
            1)
                print_header "选择：守护进程模式"
                setup_daemon
                break
                ;;
            2)
                print_header "选择：定时任务模式"
                setup_cron
                break
                ;;
            3)
                print_header "选择：手动运行模式"
                run_manual
                break
                ;;
            4)
                print_info "退出安装"
                exit 0
                ;;
            *)
                print_error "无效选择，请输入 1-4"
                ;;
        esac
    done
    
    # 6. 完成安装
    print_success "安装完成！"
    echo ""
    print_info "常用命令："
    echo "  查看状态: ./unified_mining_monitor.sh status"
    echo "  查看日志: ./unified_mining_monitor.sh logs" 
    echo "  停止运行: ./unified_mining_monitor.sh stop"
    echo "  重启服务: ./unified_mining_monitor.sh restart"
    echo "  查看帮助: ./unified_mining_monitor.sh --help"
    echo ""
    print_success "祝您挖矿愉快！💎⛏️"
}

# 守护进程设置
setup_daemon() {
    print_info "正在设置守护进程模式..."
    
    # 停止可能存在的旧进程
    ./unified_mining_monitor.sh stop 2>/dev/null || true
    
    # 启动守护进程
    if ./unified_mining_monitor.sh start; then
        print_success "守护进程启动成功"
        echo ""
        print_info "守护进程状态："
        ./unified_mining_monitor.sh status
    else
        print_error "守护进程启动失败"
        return 1
    fi
}

# 定时任务设置
setup_cron() {
    print_info "正在设置定时任务模式..."
    
    # 设置30分钟定时任务
    if ./unified_mining_monitor.sh cron 30; then
        print_success "定时任务设置成功"
        echo ""
        print_info "当前定时任务："
        crontab -l | grep unified_mining_monitor || print_warning "未找到相关定时任务"
    else
        print_error "定时任务设置失败"
        return 1
    fi
}

# 手动运行
run_manual() {
    print_info "运行单次监控测试..."
    echo ""
    
    if ./unified_mining_monitor.sh monitor; then
        print_success "监控测试完成"
        echo ""
        print_info "您可以随时运行以下命令进行监控："
        echo "  ./unified_mining_monitor.sh monitor"
    else
        print_error "监控测试失败"
        return 1
    fi
}

# 运行主函数
main "$@"