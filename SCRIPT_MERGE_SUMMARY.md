# 脚本合并总结 / Script Merge Summary

## 概述 / Overview

原先的多个脚本已经合并为一个统一的 `mining_manager.sh` 脚本，提供了所有挖矿监控功能。

The multiple scripts have been merged into a single unified `mining_manager.sh` script that provides all mining monitoring functionality.

## 已合并的脚本 / Merged Scripts

### 已删除的脚本 / Deleted Scripts
以下脚本的功能已经集成到 `mining_manager.sh` 中：

The following scripts have been integrated into `mining_manager.sh`:

1. **start_mining_monitor.sh** → `mining_manager.sh start`
2. **start_monitor.sh** → `mining_manager.sh monitor`
3. **mining_daemon.sh** → `mining_manager.sh start` (守护进程功能)
4. **setup_cron_simple.sh** → `mining_manager.sh cron`
5. **setup_cron_5min.sh** → `mining_manager.sh cron 5`
6. **test_current_setup.sh** → `mining_manager.sh test`
7. **test_multi_pool.sh** → `mining_manager.sh demo`
8. **demo_multi_pool.sh** → `mining_manager.sh demo`

### 保留的文件 / Retained Files
以下文件保持不变：

The following files remain unchanged:

- **mining_balance_monitor.sh** - 原始监控脚本（保留作为备用）
- **mining_balance_monitor_backup.sh** - 备份脚本
- **mining_config.env** - 配置文件
- **README.md** - 文档
- **CHANGELOG.md** - 变更日志
- 其他文档文件

## 新的统一脚本使用方法 / New Unified Script Usage

### 基本命令 / Basic Commands

```bash
# 显示帮助
./mining_manager.sh --help

# 显示版本
./mining_manager.sh --version

# 运行一次监控（默认命令）
./mining_manager.sh monitor
./mining_manager.sh  # 等同于上面的命令

# 测试配置
./mining_manager.sh test

# 演示多池功能
./mining_manager.sh demo
```

### 守护进程管理 / Daemon Management

```bash
# 启动守护进程（每5分钟运行一次）
./mining_manager.sh start

# 查看守护进程状态
./mining_manager.sh status

# 停止守护进程
./mining_manager.sh stop

# 重启守护进程
./mining_manager.sh restart

# 查看实时日志
./mining_manager.sh logs
```

### 定时任务设置 / Cron Job Setup

```bash
# 设置每5分钟的定时任务（默认）
./mining_manager.sh cron 5

# 设置每30分钟的定时任务
./mining_manager.sh cron 30

# 设置每1分钟的定时任务
./mining_manager.sh cron 1
```

## 优势 / Benefits

### 简化管理 / Simplified Management
- **从9个脚本减少到1个** → 更容易管理和维护
- **统一的命令接口** → 不需要记住多个脚本名称
- **集中的帮助系统** → 所有功能的使用方法都在一个地方

### 功能完整性 / Complete Functionality
- **保留所有原有功能** → 没有功能丢失
- **改进的错误处理** → 更好的错误信息和恢复机制
- **统一的配置管理** → 所有配置都通过相同的方式处理

### 易用性提升 / Improved Usability
- **清晰的命令结构** → `mining_manager.sh [COMMAND] [OPTIONS]`
- **详细的帮助信息** → 每个命令都有说明和示例
- **一致的日志格式** → 所有功能使用相同的日志系统

## 迁移指南 / Migration Guide

如果您之前使用的是旧脚本，请按以下方式更新：

If you were using the old scripts, please update as follows:

| 旧命令 / Old Command | 新命令 / New Command |
|---------------------|---------------------|
| `./start_mining_monitor.sh start` | `./mining_manager.sh start` |
| `./start_monitor.sh` | `./mining_manager.sh monitor` |
| `./setup_cron_simple.sh` | `./mining_manager.sh cron 5` |
| `./setup_cron_5min.sh` | `./mining_manager.sh cron 5` |
| `./test_current_setup.sh` | `./mining_manager.sh test` |
| `./demo_multi_pool.sh` | `./mining_manager.sh demo` |

## 配置文件 / Configuration

配置文件 `mining_config.env` 保持不变，新脚本会自动读取所有现有配置。

The configuration file `mining_config.env` remains unchanged, and the new script will automatically read all existing configurations.

## 兼容性 / Compatibility

- **向后兼容** → 所有环境变量和配置选项都保持相同
- **相同的API接口** → 继续使用相同的挖矿池API
- **相同的日志格式** → 日志结构保持一致

## 支持 / Support

如果遇到问题，请：

If you encounter issues, please:

1. 运行 `./mining_manager.sh test` 检查配置
2. 查看 `./mining_manager.sh --help` 获取帮助
3. 检查日志文件获取详细错误信息

---

**注意**: 旧的脚本文件已被删除。如果需要，可以从git历史中恢复。

**Note**: The old script files have been deleted. If needed, they can be restored from git history.