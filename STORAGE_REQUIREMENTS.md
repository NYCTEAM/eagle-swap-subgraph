# Subgraph 存储需求详细分析

## 📊 完整存储估算

### 第一年存储需求

```
┌─────────────────────────────────────────────────────────────┐
│                    PostgreSQL 数据库                         │
├─────────────────────────────────────────────────────────────┤
│ 基础数据:                                                    │
│  • tokens (代币)              10 MB                         │
│  • pairs (V2 池子)            50 MB                         │
│  • pools_v3 (V3 池子)         30 MB                         │
│                                                              │
│ 交易数据 (持续增长):                                         │
│  • swaps (V2 交易)            10 GB                         │
│  • swaps_v3 (V3 交易)         5 GB                          │
│  • sync_events (储备更新)     25 GB                         │
│                                                              │
│ 历史数据:                                                    │
│  • pair_hour_data             20 GB                         │
│  • pair_day_data              5 GB                          │
│  • token_day_data             2 GB                          │
│                                                              │
│ 索引和其他:                                                  │
│  • 数据库索引                 8 GB                          │
│  • WAL 日志                   2 GB                          │
│                                                              │
│ 小计: ~77 GB                                                │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    IPFS 存储                                 │
├─────────────────────────────────────────────────────────────┤
│  • Subgraph 元数据            100 MB                        │
│  • 部署历史                   500 MB                        │
│  • 区块数据缓存               1 GB                          │
│                                                              │
│ 小计: ~2 GB                                                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    Graph Node                                │
├─────────────────────────────────────────────────────────────┤
│  • 区块缓存                   5 GB                          │
│  • 日志文件                   2 GB                          │
│  • 临时文件                   1 GB                          │
│                                                              │
│ 小计: ~8 GB                                                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    Docker                                    │
├─────────────────────────────────────────────────────────────┤
│  • 镜像文件                   3 GB                          │
│  • 容器层                     1 GB                          │
│                                                              │
│ 小计: ~4 GB                                                 │
└─────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════
第一年总计: ~91 GB
═══════════════════════════════════════════════════════════════
```

### 每日增长速度

```
BSC 区块链统计:
├─ 每天区块数: 28,800 (3秒/块)
├─ 每区块平均 Swap: 50 笔
├─ PancakeSwap 占比: 30%
└─ 每天 PancakeSwap Swap: ~432,000 笔

存储增长:
├─ 交易记录: 432,000 × 1 KB = 432 MB/天
├─ Sync 事件: 432,000 × 0.5 KB = 216 MB/天
├─ 小时数据: 80,000 池子 × 24 × 0.5 KB = 960 MB/天
├─ 日数据: 80,000 池子 × 0.5 KB = 40 MB/天
└─ 索引更新: 100 MB/天
─────────────────────────────────────
总计: ~1.7 GB/天 = ~51 GB/月 = ~620 GB/年
```

### 长期增长预测

```
年份    基础数据    增长数据    总计
────────────────────────────────────
Year 0  91 GB       0 GB        91 GB
Year 1  91 GB       620 GB      711 GB
Year 2  91 GB       1,240 GB    1.3 TB
Year 3  91 GB       1,860 GB    1.9 TB
Year 4  91 GB       2,480 GB    2.5 TB
Year 5  91 GB       3,100 GB    3.1 TB
```

## 💾 推荐配置方案

### 方案 1: 最小配置（测试环境）

```
硬盘: 200 GB SSD
─────────────────────────────────────
分配:
├─ PostgreSQL:     120 GB
├─ IPFS:           10 GB
├─ Graph Node:     10 GB
├─ Docker:         5 GB
├─ 日志:           5 GB
└─ 系统预留:       50 GB

使用期限: 6-8 个月

优点:
✅ 成本低
✅ 适合测试

缺点:
❌ 需要定期清理历史数据
❌ 不适合生产环境
❌ 性能受限
❌ 无备份空间
```

### 方案 2: 推荐配置（生产环境）⭐

```
硬盘: 1 TB NVMe SSD
─────────────────────────────────────
分配:
├─ PostgreSQL:     700 GB
├─ IPFS:           50 GB
├─ Graph Node:     50 GB
├─ Docker:         20 GB
├─ 日志:           30 GB
├─ 备份:           100 GB
└─ 系统预留:       50 GB

使用期限: 12-18 个月

优点:
✅ 性能优秀 (NVMe)
✅ 足够运行 1-2 年
✅ 有备份空间
✅ 适合生产环境

成本: ~$100-150 (1TB NVMe SSD)
```

### 方案 3: 理想配置（长期运行）

```
硬盘: 2 TB NVMe SSD
─────────────────────────────────────
分配:
├─ PostgreSQL:     1.5 TB
├─ IPFS:           100 GB
├─ Graph Node:     100 GB
├─ Docker:         50 GB
├─ 日志:           50 GB
├─ 备份:           150 GB
└─ 系统预留:       50 GB

使用期限: 3+ 年

优点:
✅ 长期无忧
✅ 完整历史数据
✅ 充足备份空间
✅ 最佳性能

成本: ~$200-300 (2TB NVMe SSD)
```

### 方案 4: 企业级配置

```
硬盘: 4 TB NVMe SSD
─────────────────────────────────────
分配:
├─ PostgreSQL:     3 TB
├─ IPFS:           200 GB
├─ Graph Node:     200 GB
├─ Docker:         100 GB
├─ 日志:           100 GB
├─ 备份:           300 GB
└─ 系统预留:       100 GB

使用期限: 5+ 年

优点:
✅ 永久解决方案
✅ 支持多个 Subgraph
✅ 完整历史数据
✅ 企业级性能

成本: ~$400-600 (4TB NVMe SSD)
```

## 🎯 针对你的服务器配置

根据你的服务器状态:

```
当前配置:
├─ Chaindata (nvme3n1): 8TB (已用 1.5T / 22%)
├─ Ancient (md0):       16TB (已用 3.8T / 28%)
├─ 内存:                503GB (已用 174GB)
└─ CPU:                 高性能

建议:
✅ 在 Chaindata (nvme3n1) 上分配 1TB 给 Subgraph
   理由: NVMe 性能最佳，剩余 5.5TB 足够 BSC 节点增长
```

### 推荐部署方案

```
路径规划:
/mnt/chaindata/subgraph/
├─ postgres/          (700 GB)
├─ ipfs/              (50 GB)
├─ graph-node/        (50 GB)
├─ docker/            (20 GB)
├─ logs/              (30 GB)
├─ backups/           (100 GB)
└─ reserved/          (50 GB)
─────────────────────────────────────
总计: 1 TB

修改 docker-compose.yml:
volumes:
  postgres_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/chaindata/subgraph/postgres
  
  ipfs_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/chaindata/subgraph/ipfs
```

## 📈 空间管理策略

### 1. 数据保留策略

```yaml
# 完整保留（推荐）
retention:
  swaps: forever          # 所有交易记录
  hourData: forever       # 所有小时数据
  dayData: forever        # 所有日数据

# 有限保留（空间紧张时）
retention:
  swaps: 1 year           # 只保留 1 年交易
  hourData: 6 months      # 只保留 6 个月小时数据
  dayData: forever        # 保留所有日数据
```

### 2. 定期清理

```bash
# 清理旧日志
find /mnt/chaindata/subgraph/logs -name "*.log" -mtime +30 -delete

# 清理旧备份
find /mnt/chaindata/subgraph/backups -name "*.sql.gz" -mtime +7 -delete

# PostgreSQL VACUUM
docker exec eagle-postgres psql -U graph-node -d graph-node -c "VACUUM FULL;"
```

### 3. 压缩备份

```bash
# 每周备份
pg_dump -U graph-node graph-node | gzip > backup-$(date +%Y%m%d).sql.gz

# 保留最近 4 个备份（约 1 个月）
ls -t backup-*.sql.gz | tail -n +5 | xargs rm -f
```

## 🔍 监控空间使用

### 创建监控脚本

```bash
#!/bin/bash
# /mnt/chaindata/subgraph/monitor-space.sh

echo "=== Subgraph 存储监控 ==="
echo ""

# 总体使用
df -h /mnt/chaindata | grep chaindata

echo ""
echo "=== 各组件使用 ==="

# PostgreSQL
POSTGRES_SIZE=$(du -sh /mnt/chaindata/subgraph/postgres 2>/dev/null | cut -f1)
echo "PostgreSQL: $POSTGRES_SIZE"

# IPFS
IPFS_SIZE=$(du -sh /mnt/chaindata/subgraph/ipfs 2>/dev/null | cut -f1)
echo "IPFS: $IPFS_SIZE"

# Graph Node
GRAPH_SIZE=$(du -sh /mnt/chaindata/subgraph/graph-node 2>/dev/null | cut -f1)
echo "Graph Node: $GRAPH_SIZE"

# 日志
LOGS_SIZE=$(du -sh /mnt/chaindata/subgraph/logs 2>/dev/null | cut -f1)
echo "Logs: $LOGS_SIZE"

# 备份
BACKUP_SIZE=$(du -sh /mnt/chaindata/subgraph/backups 2>/dev/null | cut -f1)
echo "Backups: $BACKUP_SIZE"

echo ""
echo "=== 数据库详情 ==="
docker exec eagle-postgres psql -U graph-node -d graph-node -c "
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'sgd1'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
"
```

### 设置告警

```bash
# 添加到 crontab
# 每天检查，空间使用超过 80% 发送告警
0 0 * * * /mnt/chaindata/subgraph/monitor-space.sh | mail -s "Subgraph Storage Report" admin@example.com
```

## 💡 优化建议

### 1. 使用分区表

```sql
-- PostgreSQL 分区可以提高查询性能并方便数据清理
CREATE TABLE swaps_2024 PARTITION OF swaps
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

-- 删除旧分区
DROP TABLE swaps_2023;
```

### 2. 定期 VACUUM

```bash
# 每周执行
docker exec eagle-postgres psql -U graph-node -d graph-node -c "VACUUM ANALYZE;"
```

### 3. 压缩旧数据

```sql
-- 使用 PostgreSQL 表压缩
ALTER TABLE pair_hour_data SET (toast_compression = lz4);
```

## 📊 成本对比

```
方案          硬盘成本    电费/年    总成本(3年)
────────────────────────────────────────────────
200GB SSD     $30        $10        $60
1TB NVMe      $120       $15        $165
2TB NVMe      $250       $20        $310
4TB NVMe      $500       $30        $590

推荐: 1TB NVMe (性价比最高)
```

## 🎯 最终建议

### 针对你的服务器

```
✅ 推荐配置: 1TB NVMe (在现有 Chaindata 盘上分配)

理由:
1. 你的 nvme3n1 有 5.5TB 可用空间
2. 1TB 足够运行 12-18 个月
3. NVMe 性能最佳
4. 不需要额外购买硬盘
5. 与 BSC 节点共享高速存储

路径: /mnt/chaindata/subgraph/
预计使用: 1TB
剩余空间: 4.5TB (足够 BSC 节点增长)
```

### 扩展计划

```
6 个月后: 检查使用情况
12 个月后: 评估是否需要扩容
18 个月后: 
  选项 1: 清理旧数据（保留 1 年）
  选项 2: 扩容到 2TB
  选项 3: 迁移到独立 2TB NVMe
```

## 📝 总结

| 配置 | 容量 | 使用期限 | 适用场景 | 推荐度 |
|------|------|---------|---------|--------|
| 最小 | 200GB | 6-8月 | 测试 | ⭐⭐ |
| 推荐 | 1TB | 12-18月 | 生产 | ⭐⭐⭐⭐⭐ |
| 理想 | 2TB | 3+年 | 长期 | ⭐⭐⭐⭐ |
| 企业 | 4TB | 5+年 | 企业 | ⭐⭐⭐ |

**对于你的服务器，推荐在现有 NVMe 盘上分配 1TB 空间！**
