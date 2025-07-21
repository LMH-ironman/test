#!/bin/bash

# Test script for Multi-Pool XTM support
# 测试多池XTM支持的脚本

echo "=== Testing Multi-Pool XTM Support ==="

# Test 1: Both pools
echo "Test 1: Testing both pools (default)"
XTM_POOL="BOTH" ./mining_balance_monitor.sh

echo ""
echo "=== Test 1 Complete ==="
echo ""

# Test 2: SupportXMR only
echo "Test 2: Testing SupportXMR pool only"
XTM_POOL="SUPPORTXMR" ./mining_balance_monitor.sh

echo ""
echo "=== Test 2 Complete ==="
echo ""

# Test 3: LuckyPool only
echo "Test 3: Testing LuckyPool pool only"
XTM_POOL="LUCKYPOOL" ./mining_balance_monitor.sh

echo ""
echo "=== Test 3 Complete ==="
echo ""

echo "=== All tests completed ==="