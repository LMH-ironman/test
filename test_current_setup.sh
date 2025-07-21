#!/bin/bash

# 测试当前挖矿监控设置
# Test current mining monitor setup

set -euo pipefail

echo "=== 测试挖矿监控脚本配置 ==="
echo ""

# 检查脚本文件
if [[ -f "mining_balance_monitor.sh" ]]; then
    echo "✅ 主脚本存在: mining_balance_monitor.sh"
    chmod +x mining_balance_monitor.sh
else
    echo "❌ 主脚本不存在: mining_balance_monitor.sh"
    exit 1
fi

# 检查配置文件
if [[ -f "mining_config.env" ]]; then
    echo "✅ 配置文件存在: mining_config.env"
else
    echo "⚠️  配置文件不存在: mining_config.env"
fi

echo ""
echo "📋 当前配置信息:"

# 显示API配置
echo "  🔗 XMR API: SupportXMR"
echo "  🔗 XTM API: LuckyPool"

# 检查配置文件内容
if [[ -f "mining_config.env" ]]; then
    echo ""
    echo "📄 配置文件内容:"
    cat mining_config.env
fi

echo ""
echo "🔍 测试脚本运行..."

# 使用临时目录测试，避免权限问题
TEST_LOG="/tmp/mining_test_$(date +%s).log"
TEST_XMR_HISTORY="/tmp/xmr_history_test.txt"
TEST_XTM_HISTORY="/tmp/xtm_history_test.txt"

echo "  日志文件: $TEST_LOG"
echo "  XMR历史: $TEST_XMR_HISTORY"
echo "  XTM历史: $TEST_XTM_HISTORY"

# 运行测试（30秒超时）
echo ""
echo "⏱️  开始测试运行（30秒超时）..."

if timeout 30 LOG_FILE_PATH="$TEST_LOG" \
   XMR_BALANCE_HISTORY_PATH="$TEST_XMR_HISTORY" \
   XTM_BALANCE_HISTORY_PATH="$TEST_XTM_HISTORY" \
   ./mining_balance_monitor.sh > /dev/null 2>&1; then
    
    echo "✅ 脚本运行成功！"
    
    # 显示日志最后几行
    if [[ -f "$TEST_LOG" ]]; then
        echo ""
        echo "📊 运行日志（最后10行）:"
        tail -10 "$TEST_LOG" | sed 's/^/  /'
    fi
    
else
    echo "❌ 脚本运行失败或超时"
    if [[ -f "$TEST_LOG" ]]; then
        echo ""
        echo "📊 错误日志:"
        tail -10 "$TEST_LOG" | sed 's/^/  /'
    fi
fi

# 清理测试文件
rm -f "$TEST_LOG" "$TEST_XMR_HISTORY" "$TEST_XTM_HISTORY"

echo ""
echo "🎯 下一步:"
echo "   如果测试通过，运行以下命令设置5分钟定时任务:"
echo "   ./setup_cron_simple.sh"
echo ""
echo "💡 手动设置定时任务:"
echo "   crontab -e"
echo "   添加行: */5 * * * * $(pwd)/mining_balance_monitor.sh >> \$HOME/mining_logs/mining_monitor.log 2>&1"