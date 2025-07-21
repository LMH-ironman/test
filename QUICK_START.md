# 🚀 快速开始 - 5分钟定时监控

## 📋 当前配置
- **XMR监控**: SupportXMR池
- **XTM监控**: LuckyPool池  
- **执行频率**: 每5分钟自动运行
- **微信推送**: 企业微信机器人

## ⚡ 一键启动

```bash
# 启动挖矿监控守护进程（每5分钟运行一次）
./start_mining_monitor.sh start
```

## 🎛️ 管理命令

```bash
# 查看运行状态
./start_mining_monitor.sh status

# 查看实时日志
./start_mining_monitor.sh logs

# 停止监控
./start_mining_monitor.sh stop

# 重启监控
./start_mining_monitor.sh restart
```

## 📊 监控内容

每5分钟自动监控并推送：

### XMR收益 (SupportXMR)
- 已支付余额
- 待支付余额
- 总收益和增长

### XTM收益 (LuckyPool)
- 已付款余额
- 未锁定余额
- 已锁定余额
- 总收益和增长

### 价格信息
- 实时XMR和XTM价格 (XT交易所)
- USD价值计算
- 投资组合总价值

## 🔍 查看结果

### 方法1: 查看实时日志
```bash
./start_mining_monitor.sh logs
```

### 方法2: 查看历史日志
```bash
tail -20 ~/mining_logs/mining_monitor.log
```

### 方法3: 微信群消息
- 企业微信群会每5分钟收到格式化的收益报告

## ⚙️ 配置修改

如需修改微信Webhook地址，编辑配置文件：
```bash
nano mining_config.env
```

修改这一行：
```
WECHAT_WEBHOOK_URL="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY"
```

## 🚨 故障排除

### 如果守护进程无法启动
```bash
# 检查脚本权限
chmod +x mining_balance_monitor.sh mining_daemon.sh

# 手动测试主脚本
./mining_balance_monitor.sh
```

### 如果微信消息未收到
1. 检查配置文件中的Webhook URL
2. 测试网络连接：`curl -I https://qyapi.weixin.qq.com`
3. 查看错误日志：`./start_mining_monitor.sh logs`

### 如果数据获取失败
- 检查网络连接
- 查看详细日志找出具体错误

## 📱 示例微信消息格式

```
💰 挖矿收益报告

🪙 XMR 收益详情：
💰 已支付：183.45 XMR
⏳ 待支付：0.031 XMR
💎 总收益：183.48 XMR
📈 收益增长：📈 +0.025 XMR
💵 当前价格：326.45 USDT
💲 总价值：59820.41 USD

🔶 XTM 收益详情：
💰 已付款：37086 XTM
🔓 未锁定：4549 XTM
🔒 已锁定：0 XTM
💎 总收益：41635 XTM
📈 收益增长：📈 +4549 XTM
💵 当前价格：0.006800 USDT
💲 总价值：283.12 USD

🏦 投资组合总览：
💲 总价值：60103.53 USD

📅 更新时间：2025-01-21 14:17:06
🔗 数据来源：SupportXMR Pool & XTM LuckyPool & XT Exchange
```

## 🎯 现在就开始！

1. **启动监控**: `./start_mining_monitor.sh start`
2. **查看状态**: `./start_mining_monitor.sh status`  
3. **查看日志**: `./start_mining_monitor.sh logs`

🎉 完成！你的挖矿收益将每5分钟自动监控并推送到微信！