# 挖矿余额监控脚本 (Mining Balance Monitor)

这是一个统一的挖矿余额监控脚本，可以同时监控 XMR 和 XTM 的挖矿收益，并将结果推送到微信机器人。

## 主要功能

- 🪙 **XMR 监控**: 监控 SupportXMR Pool 的挖矿收益
- 🔶 **XTM 监控**: 监控 XTM LuckyPool 的挖矿收益
- 💰 **实时币价**: 从 XT 交易所获取 XMR 和 XTM 实时价格
- 💲 **价值计算**: 自动计算收益的 USD 价值和投资组合总值
- 📱 **微信推送**: 通过企业微信机器人发送收益报告
- 📊 **增长统计**: 计算相比上次运行的收益增长
- 📝 **历史记录**: 保存收益历史数据
- 🎨 **美观输出**: 控制台彩色输出和格式化消息

## 文件结构

```
.
├── mining_balance_monitor.sh    # 主脚本文件
├── mining_config.env           # 配置文件
└── README.md                   # 使用说明
```

## 安装依赖

脚本会自动检查并安装必要的依赖：
- `curl` - API 请求
- `jq` - JSON 数据解析
- `bc` - 精确数值计算

对于 Ubuntu/Debian 系统，脚本会自动执行：
```bash
sudo apt-get update && sudo apt-get install -y jq bc
```

## 配置说明

### 方法 1: 使用配置文件 (推荐)

编辑 `mining_config.env` 文件：
```bash
# 微信机器人 Webhook URL
WECHAT_WEBHOOK_URL="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=你的机器人key"

# 日志文件路径
LOG_FILE_PATH="/root/MINING/mining_balance_monitor.log"

# XMR 余额历史文件路径
XMR_BALANCE_HISTORY_PATH="/root/MINING/xmr_balance_history.txt"

# XTM 余额历史文件路径
XTM_BALANCE_HISTORY_PATH="/root/MINING/xtm_balance_history.txt"
```

### 方法 2: 使用环境变量

```bash
export WECHAT_WEBHOOK_URL="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=你的机器人key"
```

## 使用方法

### 基本运行

```bash
# 赋予执行权限
chmod +x mining_balance_monitor.sh

# 运行脚本
./mining_balance_monitor.sh
```

### 查看帮助

```bash
./mining_balance_monitor.sh --help
```

### 查看版本

```bash
./mining_balance_monitor.sh --version
```

### 使用临时 Webhook URL

```bash
WECHAT_WEBHOOK_URL="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=临时key" ./mining_balance_monitor.sh
```

## 定时运行 (Cron)

### 每 30 分钟运行一次

```bash
# 编辑 crontab
crontab -e

# 添加以下行 (修改为实际路径)
*/30 * * * * /path/to/mining_balance_monitor.sh >> /var/log/mining_cron.log 2>&1
```

### 每小时运行一次

```bash
0 * * * * /path/to/mining_balance_monitor.sh >> /var/log/mining_cron.log 2>&1
```

## 输出示例

### 控制台输出

```
================================
💰 挖矿收益报告

🪙 XMR 收益详情：
💰 已支付：0.123456789012 XMR
⏳ 待支付：0.000000001234 XMR
💎 总收益：0.123456790246 XMR
📈 收益增长：📈 +0.000000001234 XMR
💵 当前价格：158.45 USDT
💲 总价值：19.57 USD

🔶 XTM 收益详情：
💰 已付款：123.456789 XTM
🔓 未锁定：45.678901 XTM
🔒 已锁定：67.890123 XTM
💎 总收益：237.025813 XTM
📈 收益增长：📈 +1.234567 XTM
💵 当前价格：2.456 USDT
💲 总价值：582.51 USD

🏦 投资组合总览：
💲 总价值：602.08 USD

📅 更新时间：2024-01-20 15:30:45
🔗 数据来源：SupportXMR Pool & XTM LuckyPool & XT Exchange
================================
```

### 微信推送消息

脚本会将相同的格式化消息发送到企业微信群。

## 日志文件

脚本会在以下位置生成日志文件：
- 默认位置: `/root/MINING/mining_balance_monitor.log`
- 可通过配置文件修改

日志包含：
- 脚本运行状态
- API 请求结果
- 数据解析过程
- 错误信息

## 历史数据

脚本会保存收益历史数据用于计算增长：
- XMR 历史: `/root/MINING/xmr_balance_history.txt`
- XTM 历史: `/root/MINING/xtm_balance_history.txt`

每个文件最多保留最近 100 条记录。

## 故障排除

### 常见问题

1. **依赖缺失**
   ```bash
   # 手动安装依赖
   sudo apt-get install curl jq bc
   ```

2. **权限问题**
   ```bash
   # 确保脚本有执行权限
   chmod +x mining_balance_monitor.sh
   
   # 确保日志目录可写
   sudo mkdir -p /root/MINING
   sudo chown $USER:$USER /root/MINING
   ```

3. **API 访问失败**
   - 检查网络连接
   - 查看日志文件获取详细错误信息

4. **微信推送失败**
   - 验证 Webhook URL 是否正确
   - 检查机器人是否已添加到群中
   - 查看日志中的错误响应

### 调试模式

查看详细日志：
```bash
tail -f /root/MINING/mining_balance_monitor.log
```

## 注意事项

1. **网络要求**: 脚本需要访问外部 API，确保网络连接正常
2. **权限要求**: 脚本需要在日志目录有写入权限
3. **数据精度**: XMR 使用 12 位小数，XTM 使用 6 位小数
4. **错误恢复**: 如果某个币种的数据获取失败，另一个币种仍会正常处理

## 版本信息

- **版本**: v2.1.0
- **作者**: DevOps Engineer
- **更新**: 2024-01-20

## 更新日志

### v2.1.0 (2024-01-20)
- 新增实时币价获取功能（XT 交易所）
- 新增 USD 价值计算和投资组合总览
- 优化错误处理和容错机制
- 改进输出格式，增加价格和价值信息

### v2.0.0 (2024-01-20)
- 合并 XMR 和 XTM 监控功能
- 改用企业微信机器人推送
- 优化错误处理和日志记录
- 增加自动依赖安装
- 改进数据格式化显示