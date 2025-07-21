# 挖矿余额监控脚本 - 完整操作说明

## 📋 功能介绍

这是一个全自动的挖矿余额监控脚本，支持监控 XMR 和 XTM 两种加密货币的挖矿收益，并通过微信机器人实时推送收益报告。

### 🎯 主要功能

- **双币种监控**: 同时监控 XMR (Monero) 和 XTM (Tari) 挖矿收益
- **多池支持**: XTM 支持多个矿池 (LuckyPool + SupportXMR)
- **实时价格获取**: 从 XT 交易所获取最新币价
- **USD 价值计算**: 自动计算挖矿收益的美元价值
- **增长跟踪**: 记录和显示收益增长情况
- **微信推送**: 通过企业微信机器人发送格式化报告
- **历史记录**: 自动保存历史数据用于增长分析
- **错误处理**: 完善的错误处理和日志记录
- **灵活配置**: 支持配置文件和环境变量

## ⚡ 快速开始

如果您想立即开始使用，请按照以下步骤：

```bash
# 1. 下载脚本文件
# 确保您有 mining_balance_monitor.sh 和 start_monitor.sh

# 2. 赋予执行权限
chmod +x mining_balance_monitor.sh
chmod +x start_monitor.sh

# 3. 创建配置文件（替换为您的微信机器人 Webhook URL）
echo 'WECHAT_WEBHOOK_URL="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY_HERE"' > mining_config.env

# 4. 运行脚本
./start_monitor.sh
```

就这么简单！脚本会自动处理依赖检查、目录创建和权限问题。

---

## 🔧 安装准备

### 1. 系统要求

```bash
# 支持的操作系统
- Linux (推荐 Ubuntu 18.04+)
- 需要 bash 4.0+

# 必需的工具
- curl (网络请求)
- jq (JSON 解析)
- bc (数学计算)
```

### 2. 检查和安装依赖

```bash
# 检查依赖是否已安装
which curl jq bc

# Ubuntu/Debian 安装依赖
sudo apt update
sudo apt install curl jq bc

# CentOS/RHEL 安装依赖
sudo yum install curl jq bc

# 或者脚本会自动检测并提示安装
```

### 3. 下载脚本

```bash
# 方法1: 直接下载 (如果有下载链接)
wget https://your-repo/mining_balance_monitor.sh
chmod +x mining_balance_monitor.sh

# 方法2: 手动创建文件并复制内容
# 将脚本内容保存为 mining_balance_monitor.sh
chmod +x mining_balance_monitor.sh
```

## ⚙️ 配置说明

### 1. 配置文件方式 (推荐)

创建配置文件 `mining_config.env`:

```bash
# 创建配置文件
nano mining_config.env
```

配置文件内容示例:

```bash
# Mining Balance Monitor Configuration File
# 配置文件优先级：环境变量 > 配置文件 > 脚本默认值

# 微信机器人 Webhook URL (必需)
# 获取方式: 企业微信 > 群聊 > 群机器人 > 添加机器人 > 获取 Webhook 地址
WECHAT_WEBHOOK_URL="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY_HERE"

# 日志文件路径 (可选)
LOG_FILE_PATH="/root/MINING/mining_balance_monitor.log"

# XMR 余额历史文件路径 (可选)
XMR_BALANCE_HISTORY_PATH="/root/MINING/xmr_balance_history.txt"

# XTM 余额历史文件路径 (可选)
XTM_BALANCE_HISTORY_PATH="/root/MINING/xtm_balance_history.txt"

# XTM 矿池选择 (可选): LUCKYPOOL, SUPPORTXMR, BOTH
XTM_POOL="BOTH"
```

### 2. 环境变量方式

```bash
# 设置环境变量
export WECHAT_WEBHOOK_URL="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY_HERE"
export LOG_FILE_PATH="/your/custom/path/mining.log"
export XMR_BALANCE_HISTORY_PATH="/your/custom/path/xmr_history.txt"
export XTM_BALANCE_HISTORY_PATH="/your/custom/path/xtm_history.txt"
export XTM_POOL="BOTH"  # 选择XTM矿池: LUCKYPOOL, SUPPORTXMR, BOTH
```

### 3. XTM 多池配置

脚本支持同时监控多个 XTM 矿池，您可以选择以下配置：

```bash
# 方式1: 同时监控两个池 (推荐)
XTM_POOL="BOTH"

# 方式2: 仅监控 LuckyPool
XTM_POOL="LUCKYPOOL"

# 方式3: 仅监控 SupportXMR
XTM_POOL="SUPPORTXMR"
```

**支持的矿池:**
- **LuckyPool**: api-tari.luckypool.io (3层余额: 已付款/未锁定/已锁定)
- **SupportXMR**: www.supportxmr.com/api/tari/balance (2层余额: 已支付/待支付)

**输出格式差异:**
- `BOTH`: 显示两个池的详细信息 + 总合计
- `LUCKYPOOL`: 仅显示 LuckyPool 的 3 层余额
- `SUPPORTXMR`: 仅显示 SupportXMR 的 2 层余额

### 4. 获取微信机器人 Webhook URL

1. 打开企业微信，进入需要接收通知的群聊
2. 点击群聊右上角的 "..." 
3. 选择 "群机器人" > "添加机器人"
4. 设置机器人名称和头像
5. 复制生成的 Webhook URL
6. 将 URL 中的 key 参数替换到配置中

示例 URL 格式:
```
https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=693axxx6-7aoc-4bc4-97a0-0ec2sifa5aaa
```

## 🚀 运行方式

### 🎯 推荐方式：使用快速启动脚本

```bash
# 赋予执行权限
chmod +x start_monitor.sh
chmod +x mining_balance_monitor.sh

# 运行快速启动脚本（自动处理权限问题）
./start_monitor.sh
```

### 1. 直接运行 (使用配置文件)

```bash
# 确保配置文件 mining_config.env 在同一目录
./mining_balance_monitor.sh
```

### 2. 使用环境变量运行

```bash
# 单次运行 (默认监控两个XTM池)
WECHAT_WEBHOOK_URL="your_webhook_url" ./mining_balance_monitor.sh

# 仅监控 SupportXMR XTM 池
XTM_POOL="SUPPORTXMR" WECHAT_WEBHOOK_URL="your_webhook_url" ./mining_balance_monitor.sh

# 仅监控 LuckyPool XTM 池
XTM_POOL="LUCKYPOOL" WECHAT_WEBHOOK_URL="your_webhook_url" ./mining_balance_monitor.sh

# 使用自定义路径
LOG_FILE_PATH="/tmp/mining.log" \
XMR_BALANCE_HISTORY_PATH="/tmp/xmr_history.txt" \
XTM_BALANCE_HISTORY_PATH="/tmp/xtm_history.txt" \
XTM_POOL="BOTH" \
WECHAT_WEBHOOK_URL="your_webhook_url" \
./mining_balance_monitor.sh
```

### 3. 静默模式 (不发送微信通知)

```bash
# 设置空的 Webhook URL 将禁用微信推送
WECHAT_WEBHOOK_URL="" ./mining_balance_monitor.sh
```

### 4. 查看帮助信息

```bash
./mining_balance_monitor.sh --help
./mining_balance_monitor.sh --version
```

## ⏰ 定时任务设置

### 1. 设置 Cron 定时任务

```bash
# 编辑 crontab
crontab -e

# 添加定时任务 (每30分钟执行一次)
*/30 * * * * /root/mining_balance_monitor.sh >> /var/log/mining_cron.log 2>&1

# 每小时执行一次
0 * * * * /root/mining_balance_monitor.sh >> /var/log/mining_cron.log 2>&1

# 每天早上8点执行
0 8 * * * /root/mining_balance_monitor.sh >> /var/log/mining_cron.log 2>&1
```

### 2. 创建服务文件 (systemd)

创建服务文件 `/etc/systemd/system/mining-monitor.service`:

```ini
[Unit]
Description=Mining Balance Monitor
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=/root/mining_balance_monitor.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

创建定时器文件 `/etc/systemd/system/mining-monitor.timer`:

```ini
[Unit]
Description=Run Mining Balance Monitor every 30 minutes
Requires=mining-monitor.service

[Timer]
OnCalendar=*:0/30
Persistent=true

[Install]
WantedBy=timers.target
```

启用服务:

```bash
sudo systemctl daemon-reload
sudo systemctl enable mining-monitor.timer
sudo systemctl start mining-monitor.timer

# 查看状态
sudo systemctl status mining-monitor.timer
```

## 📊 输出示例

### 控制台输出示例

```
2025-07-20 15:42:44 [INFO] Starting Mining Balance Monitor (XMR + XTM)...
2025-07-20 15:42:45 [INFO] XMR解析结果 - paid: 180210089557473, due: 145367049966
2025-07-20 15:42:45 [INFO] Parsed XMR balance - Paid: 180.210089557473 XMR, Due: 0.145367049966 XMR, Total: 180.355456607439 XMR
2025-07-20 15:42:45 [INFO] XMR data processing completed successfully
2025-07-20 15:42:45 [INFO] XTM原始数据 - Paid: 41514104995, Unlocked: 121390720, Locked: 0
2025-07-20 15:42:45 [INFO] Parsed XTM balance - Paid: 41514.104995 XTM, Unlocked: 121.390720 XTM, Locked: 0.000000 XTM, Total: 41635.495715 XTM
2025-07-20 15:42:45 [INFO] XTM data processing completed successfully
2025-07-20 15:42:45 [INFO] Fetching cryptocurrency prices...
2025-07-20 15:42:46 [DEBUG] Fetched XMR_PRICE: '327.00'
2025-07-20 15:42:46 [DEBUG] Fetched XTM_PRICE: '0.007490'
2025-07-20 15:42:46 [INFO] Calculating USD values...
2025-07-20 15:42:46 [INFO] XMR calculation: 180.355456607439 XMR * 327.00 USD = 58976.234310632553 USD
2025-07-20 15:42:46 [INFO] XTM calculation: 41635.495715 XTM * 0.007490 USD = 311.849862 USD
2025-07-20 15:42:46 [INFO] Total portfolio value: 58976.234310632553 + 311.849862 = 59288.084172632553 USD

================================
💰 挖矿收益报告

🪙 XMR 收益详情：
💰 已支付：180.210089557473 XMR
⏳ 待支付：0.145367049966 XMR
💎 总收益：180.355456607439 XMR
📈 收益增长：➡️ 0 XMR
💵 当前价格：327.00 USDT
💲 总价值：58976.23 USD

🔶 XTM 收益详情：
💰 已付款：41514.104995 XTM
🔓 未锁定：121.39072 XTM
🔒 已锁定：0 XTM
💎 总收益：41635.495715 XTM
📈 收益增长：➡️ 0 XTM
💵 当前价格：0.007490 USDT
💲 总价值：311.85 USD

🏦 投资组合总览：
💲 总价值：59288.08 USD

📅 更新时间：2025-07-20 15:42:46
🔗 数据来源：SupportXMR Pool & XTM LuckyPool & XT Exchange
================================

2025-07-20 15:42:46 [INFO] Sending alert to WeChat...
2025-07-20 15:42:47 [INFO] WeChat alert sent successfully
2025-07-20 15:42:47 [INFO] Mining balance monitor completed successfully
```

### 微信通知示例

微信群会收到格式化的消息，包含：
- 💰 XMR 和 XTM 的详细收益信息
- 📈 收益增长情况
- 💵 实时价格信息  
- 💲 USD 价值计算
- 🏦 总投资组合价值
- 📅 更新时间和数据来源

## 🔍 故障排除

### 常见错误及解决方案

#### 1. "unbound variable" 错误

```bash
# 错误信息
./mining_balance_monitor.sh: line 10: LOG_FILE_PATH: unbound variable

# 解决方案1：使用快速启动脚本（推荐）
./start_monitor.sh

# 解决方案2：确保有配置文件或设置环境变量
echo 'WECHAT_WEBHOOK_URL="your_webhook_url"' > mining_config.env
# 或者
export WECHAT_WEBHOOK_URL="your_webhook_url"
```

#### 2. 权限问题

```bash
# 错误信息
Permission denied: /root/MINING/mining_balance_monitor.log

# 解决方案1：使用快速启动脚本（推荐，自动处理）
./start_monitor.sh

# 解决方案2: 手动创建目录并设置权限
sudo mkdir -p /root/MINING
sudo chmod 755 /root/MINING

# 解决方案3: 使用自定义路径
export LOG_FILE_PATH="/tmp/mining.log"
export XMR_BALANCE_HISTORY_PATH="/tmp/xmr_history.txt"
export XTM_BALANCE_HISTORY_PATH="/tmp/xtm_history.txt"
```

#### 3. 依赖缺失

```bash
# 错误信息
command not found: jq/curl/bc

# 解决方案
sudo apt update && sudo apt install curl jq bc
```

#### 4. 网络连接问题

```bash
# 错误信息
Failed to fetch XMR/XTM data from API

# 解决方案
# 检查网络连接
ping supportxmr.com
ping api-tari.luckypool.io
ping www.xt.com

# 检查防火墙设置
sudo ufw status
```

#### 5. 微信推送失败

```bash
# 错误信息
WeChat alert sending failed

# 解决方案
# 1. 检查 Webhook URL 是否正确
# 2. 测试 Webhook URL
curl -X POST "YOUR_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"msgtype":"text","text":{"content":"测试消息"}}'

# 3. 检查机器人是否被禁用
# 4. 确认群聊中机器人仍然存在
```

### 调试模式

```bash
# 启用详细日志输出
set -x  # 在脚本开头添加此行

# 或者手动运行各个步骤
curl -s "https://supportxmr.com/api/miner/YOUR_ADDRESS/stats"
curl -s "https://www.xt.com/sapi/v4/market/public/ticker/24h?symbol=xmr_usdt"
```

## 📂 文件结构

```
/root/
├── mining_balance_monitor.sh      # 主脚本文件
├── mining_config.env              # 配置文件 (可选)
└── MINING/                        # 默认数据目录
    ├── mining_balance_monitor.log # 日志文件
    ├── xmr_balance_history.txt    # XMR 历史记录
    └── xtm_balance_history.txt    # XTM 历史记录
```

## 🔧 自定义配置

### 修改矿池地址

如需监控不同的钱包地址，需要修改脚本中的以下变量：

```bash
# 在脚本中找到并修改这些 URL
readonly XMR_API_URL="https://www.supportxmr.com/api/miner/YOUR_XMR_ADDRESS/stats"
readonly XTM_WALLET_ADDRESS="YOUR_XTM_ADDRESS"
```

### 修改价格数据源

如需使用其他交易所的价格数据，修改以下 URL：

```bash
readonly XMR_PRICE_API_URL="https://your-exchange.com/api/xmr_usdt"
readonly XTM_PRICE_API_URL="https://your-exchange.com/api/xtm_usdt"
```

## 📈 日志管理

### 查看日志

```bash
# 查看实时日志
tail -f /root/MINING/mining_balance_monitor.log

# 查看最近的日志
tail -n 100 /root/MINING/mining_balance_monitor.log

# 搜索错误
grep "ERROR" /root/MINING/mining_balance_monitor.log
```

### 日志轮转

创建 logrotate 配置：

```bash
# 创建配置文件
sudo nano /etc/logrotate.d/mining-monitor

# 配置内容
/root/MINING/mining_balance_monitor.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
```

## 🔒 安全建议

1. **保护 Webhook URL**: 不要在公共场所泄露微信机器人的 Webhook URL
2. **文件权限**: 确保配置文件和日志文件的权限设置合理
3. **网络安全**: 在防火墙中只开放必要的端口
4. **定期更新**: 保持系统和依赖包的更新

## 💡 高级用法

### 多矿池监控

可以复制脚本并修改配置来监控多个矿池：

```bash
cp mining_balance_monitor.sh mining_pool2_monitor.sh
# 修改 mining_pool2_monitor.sh 中的 API URL
```

### 集成到监控系统

脚本可以与 Prometheus、Grafana 等监控系统集成：

```bash
# 输出指标格式
echo "mining_xmr_balance $XMR_TOTAL_BALANCE" > /var/lib/node_exporter/mining.prom
echo "mining_xtm_balance $XTM_TOTAL_BALANCE" >> /var/lib/node_exporter/mining.prom
```

## 📞 技术支持

如果遇到问题，请检查：

1. ✅ 所有依赖是否安装完整
2. ✅ 配置文件格式是否正确  
3. ✅ 网络连接是否正常
4. ✅ 权限设置是否合适
5. ✅ 日志文件中的错误信息

按照本文档操作，您应该能够成功运行挖矿余额监控脚本。如有问题，请仔细查看错误信息并对照故障排除部分进行解决。