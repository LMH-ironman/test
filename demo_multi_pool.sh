#!/bin/bash

# 多池XTM挖矿监控演示脚本
# Demo script for Multi-Pool XTM Mining Monitor

set -euo pipefail

echo "=== XTM 多池挖矿监控演示 ==="
echo ""

# 检查脚本是否存在
if [[ ! -f "mining_balance_monitor.sh" ]]; then
    echo "❌ 错误: 找不到 mining_balance_monitor.sh 脚本"
    exit 1
fi

# 确保脚本有执行权限
chmod +x mining_balance_monitor.sh

echo "📋 可用的XTM矿池配置选项:"
echo "  1. BOTH       - 同时监控两个池 (推荐)"
echo "  2. LUCKYPOOL  - 仅监控 LuckyPool"
echo "  3. SUPPORTXMR - 仅监控 SupportXMR"
echo ""

echo "🔍 演示 1: 仅监控 SupportXMR 池"
echo "命令: XTM_POOL=\"SUPPORTXMR\" ./mining_balance_monitor.sh"
echo "特点: 显示已支付/待支付两层余额结构"
echo ""
read -p "按 Enter 键开始演示 1..." -r
XTM_POOL="SUPPORTXMR" ./mining_balance_monitor.sh
echo ""
echo "✅ 演示 1 完成"
echo ""

echo "🔍 演示 2: 仅监控 LuckyPool 池"
echo "命令: XTM_POOL=\"LUCKYPOOL\" ./mining_balance_monitor.sh"
echo "特点: 显示已付款/未锁定/已锁定三层余额结构"
echo ""
read -p "按 Enter 键开始演示 2..." -r
XTM_POOL="LUCKYPOOL" ./mining_balance_monitor.sh
echo ""
echo "✅ 演示 2 完成"
echo ""

echo "🔍 演示 3: 同时监控两个池 (推荐)"
echo "命令: XTM_POOL=\"BOTH\" ./mining_balance_monitor.sh"
echo "特点: 显示两个池的详细信息 + 总合计"
echo ""
read -p "按 Enter 键开始演示 3..." -r
XTM_POOL="BOTH" ./mining_balance_monitor.sh
echo ""
echo "✅ 演示 3 完成"
echo ""

echo "🎉 所有演示完成！"
echo ""
echo "💡 使用建议:"
echo "  - 生产环境推荐使用 XTM_POOL=\"BOTH\" 获得完整收益视图"
echo "  - 配置定时任务: */30 * * * * /path/to/mining_balance_monitor.sh"
echo "  - 配置微信机器人获得实时推送通知"
echo ""
echo "📖 更多信息请查看 README.md"