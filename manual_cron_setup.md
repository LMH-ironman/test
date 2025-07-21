# 手动设置5分钟定时任务

## 🎯 任务目标
设置挖矿收益监控脚本每5分钟自动运行一次

## 📋 当前配置
- **XMR**: SupportXMR池
- **XTM**: LuckyPool池
- **执行频率**: 每5分钟
- **脚本路径**: `/workspace/mining_balance_monitor.sh`

## 🔧 设置方法

### 方法1: 使用crontab命令

```bash
# 1. 编辑crontab
crontab -e

# 2. 添加以下行到文件末尾
*/5 * * * * /workspace/mining_balance_monitor.sh >> $HOME/mining_logs/mining_monitor.log 2>&1

# 3. 保存并退出 (通常是 Ctrl+X, 然后Y, 然后Enter)
```

### 方法2: 如果crontab不可用，使用systemd定时器

```bash
# 1. 创建服务文件
sudo nano /etc/systemd/system/mining-monitor.service
```

服务文件内容：
```ini
[Unit]
Description=Mining Balance Monitor
After=network.target

[Service]
Type=oneshot
User=ubuntu
WorkingDirectory=/workspace
ExecStart=/workspace/mining_balance_monitor.sh
StandardOutput=append:/home/ubuntu/mining_logs/mining_monitor.log
StandardError=append:/home/ubuntu/mining_logs/mining_monitor.log
```

```bash
# 2. 创建定时器文件
sudo nano /etc/systemd/system/mining-monitor.timer
```

定时器文件内容：
```ini
[Unit]
Description=Run Mining Monitor every 5 minutes
Requires=mining-monitor.service

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
# 3. 启用并启动定时器
sudo systemctl enable mining-monitor.timer
sudo systemctl start mining-monitor.timer

# 4. 检查状态
sudo systemctl status mining-monitor.timer
```

### 方法3: 使用nohup和while循环 (简单方法)

创建一个持续运行的脚本：

```bash
# 1. 创建守护进程脚本
nano mining_daemon.sh
```

守护进程脚本内容：
```bash
#!/bin/bash
while true; do
    /workspace/mining_balance_monitor.sh >> $HOME/mining_logs/mining_monitor.log 2>&1
    sleep 300  # 300秒 = 5分钟
done
```

```bash
# 2. 运行守护进程
chmod +x mining_daemon.sh
nohup ./mining_daemon.sh &

# 3. 查看进程
ps aux | grep mining_daemon
```

## 📊 验证设置

### 检查定时任务
```bash
# 方法1验证
crontab -l

# 方法2验证
sudo systemctl list-timers | grep mining

# 方法3验证
ps aux | grep mining_daemon
```

### 查看日志
```bash
# 创建日志目录
mkdir -p $HOME/mining_logs

# 实时查看日志
tail -f $HOME/mining_logs/mining_monitor.log

# 查看最近的执行记录
tail -20 $HOME/mining_logs/mining_monitor.log
```

## 🔍 故障排除

### 如果脚本不执行
1. 检查脚本权限：`chmod +x /workspace/mining_balance_monitor.sh`
2. 检查路径是否正确
3. 手动测试脚本：`/workspace/mining_balance_monitor.sh`

### 如果微信消息不发送
1. 检查配置文件中的Webhook URL
2. 测试网络连接：`curl -I https://qyapi.weixin.qq.com`

## ✅ 推荐使用方法1 (crontab)
如果系统支持crontab，建议使用方法1，因为它最简单可靠。