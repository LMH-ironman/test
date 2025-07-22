# 统一挖矿监控脚本 - 项目整合完成

## 🎉 项目概述

本项目已成功完成整合，将原来的多个分散脚本合并为一个功能完整的统一解决方案。现在您只需要一个脚本即可完成所有挖矿监控任务！

## ⚡ 快速开始

### 方法1: 一键安装（推荐）
```bash
# 使用快速安装向导
chmod +x 快速安装.sh
./快速安装.sh
```

### 方法2: 直接使用
```bash
# 赋予执行权限
chmod +x unified_mining_monitor.sh

# 立即运行
./unified_mining_monitor.sh

# 或者设置守护进程
./unified_mining_monitor.sh start
```

## 📚 主要文件说明

### 🚀 核心文件
- **`unified_mining_monitor.sh`** - 主要脚本，包含所有功能
- **`mining_config.env`** - 配置文件
- **`快速安装.sh`** - 一键安装向导

### 📖 文档文件
- **`统一挖矿监控操作文档.md`** - 详细使用文档
- **`项目整合完成总结.md`** - 整合成果总结

### 📦 历史文件（保留）
- `mining_manager.sh` - 旧版管理脚本（已整合到新脚本）
- `mining_balance_monitor.sh` - 旧版监控脚本（已整合到新脚本）
- 其他旧文件 - 保留作为参考

## 🎯 主要特性

- ✅ **XMR + XTM 双币种监控** - 同时监控两种加密货币
- ✅ **实时价格获取** - 从 XT 交易所获取最新价格
- ✅ **USD 价值计算** - 自动计算收益的美元价值
- ✅ **微信机器人推送** - 企业微信机器人通知
- ✅ **守护进程管理** - 后台自动运行
- ✅ **定时任务设置** - 灵活的计划任务
- ✅ **彩色输出界面** - 美观的用户体验
- ✅ **一键安装部署** - 简化的安装过程

## 📋 可用命令

```bash
# 基本命令
./unified_mining_monitor.sh                    # 运行监控（默认）
./unified_mining_monitor.sh monitor            # 运行一次监控
./unified_mining_monitor.sh --help             # 查看帮助
./unified_mining_monitor.sh --version          # 查看版本

# 守护进程管理
./unified_mining_monitor.sh start              # 启动守护进程
./unified_mining_monitor.sh stop               # 停止守护进程
./unified_mining_monitor.sh status             # 查看状态
./unified_mining_monitor.sh restart            # 重启守护进程
./unified_mining_monitor.sh logs               # 查看日志

# 定时任务
./unified_mining_monitor.sh cron 5             # 设置每5分钟运行
./unified_mining_monitor.sh cron 30            # 设置每30分钟运行

# 测试和演示
./unified_mining_monitor.sh test               # 测试配置
./unified_mining_monitor.sh demo               # 功能演示
```

## 🔧 配置说明

### 配置文件 (`mining_config.env`)
```bash
# 微信机器人 Webhook URL
WECHAT_WEBHOOK_URL="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY"

# 自定义日志路径（可选）
LOG_FILE_PATH="/root/MINING/mining_monitor.log"

# 历史数据路径（可选）
XMR_BALANCE_HISTORY_PATH="/root/MINING/xmr_balance_history.txt"
XTM_BALANCE_HISTORY_PATH="/root/MINING/xtm_balance_history.txt"
```

### 环境变量设置
```bash
# 临时设置
export WECHAT_WEBHOOK_URL="your_webhook_url"
./unified_mining_monitor.sh monitor

# 永久设置
echo 'export WECHAT_WEBHOOK_URL="your_webhook_url"' >> ~/.bashrc
source ~/.bashrc
```

## 🚀 部署建议

### 生产环境（推荐）
```bash
# 使用守护进程模式
./unified_mining_monitor.sh start
```

### 定时任务模式
```bash
# 设置每30分钟运行
./unified_mining_monitor.sh cron 30
```

### 开发测试
```bash
# 手动运行测试
./unified_mining_monitor.sh test
./unified_mining_monitor.sh monitor
```

## 📊 输出示例

```
🚀 Unified Mining Monitor v4.0.0 启动中...
ℹ️  检查依赖项...
✅ 所有依赖项检查完成
================================================================
💰 挖矿收益报告

🪙 XMR 收益详情：
💰 已支付：0.005123456789 XMR
⏳ 待支付：0.000987654321 XMR
💎 总收益：0.006111111110 XMR
📈 收益增长：📈 +0.000012345678 XMR
💵 当前价格：158.23 USDT
💲 总价值：0.97 USD

🔶 XTM 收益详情：
💰 已付款：12.345678 XTM
🔓 未锁定：5.432100 XTM
🔒 已锁定：8.765432 XTM
💎 总收益：26.543210 XTM
📈 收益增长：📈 +0.123456 XTM
💵 当前价格：0.008234 USDT
💲 总价值：0.22 USD

🏦 投资组合总览：
💲 总价值：1.19 USD

📅 更新时间：2024-01-20 15:30:45
🔗 数据来源：SupportXMR Pool & XTM LuckyPool & XT Exchange
================================================================
✅ 微信通知发送成功
```

## 🔍 故障排查

### 常见问题
1. **权限问题**: `chmod +x unified_mining_monitor.sh`
2. **依赖缺失**: 脚本会自动安装 `curl`, `bc`, `jq`
3. **网络问题**: 检查防火墙和代理设置
4. **配置问题**: 运行 `./unified_mining_monitor.sh test`

### 获取帮助
```bash
# 查看详细帮助
./unified_mining_monitor.sh --help

# 查看完整文档
cat 统一挖矿监控操作文档.md

# 运行诊断测试
./unified_mining_monitor.sh test
```

## 📈 项目优势

### 相比旧版本
- ✅ **从多个脚本简化为一个** - 更容易管理
- ✅ **功能更加完整** - 包含所有原有功能plus新增功能
- ✅ **用户体验更好** - 彩色输出、智能提示
- ✅ **安装更加简单** - 一键安装向导
- ✅ **维护更加容易** - 统一的代码库和文档

### 技术改进
- 🔧 **模块化设计** - 更好的代码组织
- 🛡️ **错误处理** - 完善的异常处理机制
- 📊 **日志系统** - 详细的操作记录
- ⚙️ **配置管理** - 灵活的配置选项
- 🔄 **进程管理** - 可靠的守护进程

## 🤝 技术支持

- 📚 **详细文档**: 查看 `统一挖矿监控操作文档.md`
- 🔧 **内置帮助**: `./unified_mining_monitor.sh --help`
- 🧪 **测试工具**: `./unified_mining_monitor.sh test`
- 📋 **整合总结**: 查看 `项目整合完成总结.md`

## ✨ 开始使用

选择您喜欢的方式开始：

```bash
# 方式1: 快速安装向导（最简单）
./快速安装.sh

# 方式2: 直接使用
./unified_mining_monitor.sh test
./unified_mining_monitor.sh start

# 方式3: 定时任务
./unified_mining_monitor.sh cron 30
```

---

**🎊 祝您挖矿愉快！💎⛏️**

> 提示：建议首先运行 `./快速安装.sh` 来体验最简单的安装过程！