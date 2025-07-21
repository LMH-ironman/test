# 更新日志 / Changelog

## v2.2.0 (2025-01-21) - Multi-Pool Support

### 🎉 新功能 / New Features
- **XTM 多池支持**: 新增对 SupportXMR Tari API 的支持
- **灵活的池选择**: 可通过 `XTM_POOL` 环境变量选择单个或多个池
- **聚合余额计算**: 自动合并多个池的余额并计算总收益增长
- **增强的消息格式**: 显示各个池的详细信息和总计

### 🔧 技术改进 / Technical Improvements
- 重构了 XTM 余额获取和解析逻辑
- 添加了新的 API 获取函数:
  - `fetch_xtm_luckypool_balance_data()`
  - `fetch_xtm_supportxmr_balance_data()`
- 添加了新的余额解析函数:
  - `parse_xtm_luckypool_balance_data()`
  - `parse_xtm_supportxmr_balance_data()`
  - `aggregate_xtm_balance_data()`
- 更新了消息生成逻辑以支持多池显示

### 📋 配置选项 / Configuration Options
- `XTM_POOL="BOTH"` - 同时监控两个池（默认，推荐）
- `XTM_POOL="LUCKYPOOL"` - 仅监控 LuckyPool
- `XTM_POOL="SUPPORTXMR"` - 仅监控 SupportXMR

### 🌐 支持的矿池 / Supported Pools
- **LuckyPool**: `api-tari.luckypool.io`
  - 余额结构: 已付款/未锁定/已锁定
- **SupportXMR**: `www.supportxmr.com/api/tari/balance`
  - 余额结构: 已支付/待支付

### 📖 使用示例 / Usage Examples
```bash
# 监控两个池（推荐）
XTM_POOL="BOTH" ./mining_balance_monitor.sh

# 仅监控 SupportXMR
XTM_POOL="SUPPORTXMR" ./mining_balance_monitor.sh

# 仅监控 LuckyPool
XTM_POOL="LUCKYPOOL" ./mining_balance_monitor.sh
```

### 🔄 向后兼容性 / Backward Compatibility
- 完全向后兼容现有配置
- 默认行为不变（仍然监控两个池）
- 现有的配置文件和环境变量继续有效

---

## v2.1.0 - 历史版本

### 功能
- XMR + XTM 双币种监控
- 价格获取和USD价值计算
- 企业微信机器人推送
- 历史数据跟踪