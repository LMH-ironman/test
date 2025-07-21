# 挖矿监控定时功能使用指南

## 📌 快速开始

项目已升级为支持每5分钟自动监控的定时版本！

### 🚀 基本使用

```bash
# 1. 给脚本添加执行权限
chmod +x *.sh

# 2. 配置微信机器人（可选）
echo 'WECHAT_WEBHOOK_URL="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY"' > mining_config.env

# 3. 选择运行模式
```

## 🔄 运行模式

### 模式1: 前台定时监控
```bash
./start_monitor.sh
```
- ✅ 每5分钟自动执行一次监控
- ✅ 显示详细的执行信息和时间戳
- ✅ 按 Ctrl+C 停止监控
- ⚠️ 终端关闭后监控停止

### 模式2: 后台守护进程（推荐）
```bash
# 启动后台监控
./start_daemon.sh start

# 查看运行状态
./start_daemon.sh status

# 查看实时日志
tail -f ~/mining_monitor_daemon.log

# 停止监控
./start_daemon.sh stop

# 重启监控
./start_daemon.sh restart
```

## 📊 监控特性

- **自动间隔**: 每5分钟执行一次
- **持续运行**: 7x24小时不间断监控
- **错误重试**: 单次失败不影响后续监控
- **日志记录**: 所有执行记录保存到日志文件
- **优雅停止**: 支持信号中断和命令停止

## 💡 使用建议

### 初次使用
1. 先使用前台模式测试几次，确保配置正确
2. 观察输出信息，确认数据获取正常
3. 如果有微信推送，检查消息是否正常发送

### 生产部署
1. 使用后台守护进程模式 (`./start_daemon.sh start`)
2. 定期查看日志文件确认运行状态
3. 可以添加到开机自启动脚本中

### 故障排查
```bash
# 查看运行状态
./start_daemon.sh status

# 查看最新日志
tail -20 ~/mining_monitor_daemon.log

# 查看实时日志
tail -f ~/mining_monitor_daemon.log

# 重启监控
./start_daemon.sh restart
```

## 📁 文件说明

- `start_monitor.sh` - 前台定时监控脚本
- `start_daemon.sh` - 后台守护进程管理脚本
- `mining_balance_monitor.sh` - 核心监控脚本（单次执行）
- `mining_config.env` - 配置文件
- `~/mining_monitor_daemon.log` - 后台运行日志
- `~/mining_monitor.pid` - 进程ID文件

## 🔧 自定义配置

如果需要修改监控间隔（默认5分钟），可以编辑 `start_monitor.sh`：

```bash
# 找到这一行
sleep 300

# 修改为其他秒数，例如10分钟 (600秒)
sleep 600
```

## ⚠️ 注意事项

1. 确保系统有足够的网络连接访问API
2. 如果长时间运行，建议定期重启以清理资源
3. 日志文件会持续增长，可以定期清理旧日志
4. 在服务器重启后需要手动重新启动监控