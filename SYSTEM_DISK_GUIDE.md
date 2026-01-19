# 系统盘部署指南 (1.5TB)

## 📊 系统盘配置方案

你的系统盘 1.5TB 完全可以用于 Subgraph！

### 空间分配

```
系统盘 1.5TB 分配方案:
├─ 系统 + 软件:        150 GB
├─ Subgraph:           800 GB  ⭐
│  ├─ PostgreSQL:      600 GB
│  ├─ IPFS:            50 GB
│  ├─ Graph Node:      50 GB
│  ├─ Docker:          20 GB
│  ├─ Logs:            30 GB
│  └─ Backups:         50 GB
├─ 其他服务:           200 GB
└─ 预留空间:           350 GB
─────────────────────────────
总计:                  1.5 TB

✅ Subgraph 800GB 可用 10-12 个月
```

## 🚀 快速部署

### 1. 运行设置脚本

```bash
# 在服务器上执行
chmod +x setup-storage-system-disk.sh
./setup-storage-system-disk.sh
```

这个脚本会：
- ✅ 检查系统盘空间
- ✅ 创建 `/opt/subgraph` 目录结构
- ✅ 设置正确的权限
- ✅ 创建监控、清理、备份脚本
- ✅ 生成定时任务配置

### 2. 使用系统盘版 docker-compose

```bash
# 复制系统盘版配置
cp docker-compose-system-disk.yml docker-compose.yml

# 或者直接使用
docker-compose -f docker-compose-system-disk.yml up -d
```

### 3. 安装定时任务

```bash
# 安装定时任务（自动清理和备份）
crontab /opt/subgraph/crontab.txt

# 查看已安装的定时任务
crontab -l
```

### 4. 启动 Subgraph

```bash
# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f graph-node

# 检查服务状态
docker-compose ps
```

## 📁 目录结构

```
/opt/subgraph/
├── postgres/           # PostgreSQL 数据 (600GB)
├── ipfs/              # IPFS 数据 (50GB)
├── graph-node/        # Graph Node 数据 (50GB)
├── docker/            # Docker 数据 (20GB)
├── logs/              # 日志文件 (30GB)
│   ├── cleanup.log
│   ├── backup.log
│   └── monitor.log
├── backups/           # 数据库备份 (50GB)
│   └── subgraph-*.sql.gz
├── monitor-space.sh   # 监控脚本
├── cleanup.sh         # 清理脚本
├── backup.sh          # 备份脚本
└── crontab.txt        # 定时任务配置
```

## 🔧 日常维护

### 监控空间使用

```bash
# 查看 Subgraph 空间使用
/opt/subgraph/monitor-space.sh

# 实时监控
watch -n 60 /opt/subgraph/monitor-space.sh
```

### 手动清理

```bash
# 清理旧日志和备份
/opt/subgraph/cleanup.sh

# 查看清理效果
df -h /
```

### 手动备份

```bash
# 执行备份
/opt/subgraph/backup.sh

# 查看备份文件
ls -lh /opt/subgraph/backups/
```

## ⚠️ 重要注意事项

### 1. 磁盘使用率监控

```bash
# 检查磁盘使用率
df -h /

# 建议保持在 80% 以下
# 超过 80% 需要清理或扩容
```

### 2. 定期清理策略

```
自动清理（定时任务）:
├─ 日志文件: 保留 30 天
├─ 备份文件: 保留 7 天（最近 4 个）
└─ Docker 缓存: 每天清理

手动清理（空间紧张时）:
├─ 删除旧交易记录（1年前）
├─ 删除旧小时数据（6个月前）
└─ 压缩历史数据
```

### 3. 备份策略

```
本地备份:
├─ 位置: /opt/subgraph/backups/
├─ 频率: 每天凌晨 3 点
├─ 保留: 最近 4 个备份
└─ 大小: 每个约 5-10GB

建议额外备份:
├─ 远程备份到其他服务器
├─ 或备份到 BSC 节点的数据盘
└─ 使用 rsync 或 rclone
```

## 📊 性能优化

### PostgreSQL 配置

系统盘版本已针对性能优化：

```yaml
# docker-compose-system-disk.yml
command:
  - "-cshared_buffers=1GB"          # 共享缓冲区
  - "-ceffective_cache_size=2GB"    # 有效缓存
  - "-cwork_mem=64MB"               # 工作内存
  - "-cmaintenance_work_mem=256MB"  # 维护内存
```

### 磁盘 I/O 优化

```bash
# 如果系统盘是 SSD，启用 TRIM
sudo fstrim -v /

# 添加到定时任务（每周执行）
echo "0 0 * * 0 /sbin/fstrim -v /" | sudo tee -a /etc/crontab
```

## 🔍 故障排除

### 问题 1: 磁盘空间不足

```bash
# 1. 检查空间使用
df -h /
du -sh /opt/subgraph/*

# 2. 清理旧数据
/opt/subgraph/cleanup.sh

# 3. 删除旧备份
rm /opt/subgraph/backups/subgraph-*.sql.gz

# 4. Docker 清理
docker system prune -a -f
```

### 问题 2: 性能下降

```bash
# 1. 检查磁盘使用率
df -h /

# 2. 执行 PostgreSQL VACUUM
docker exec eagle-postgres psql -U graph-node -d graph-node -c "VACUUM FULL;"

# 3. 重启服务
docker-compose restart
```

### 问题 3: 备份失败

```bash
# 1. 检查磁盘空间
df -h /opt/subgraph/backups

# 2. 手动清理旧备份
ls -t /opt/subgraph/backups/*.sql.gz | tail -n +2 | xargs rm -f

# 3. 重新备份
/opt/subgraph/backup.sh
```

## 📈 扩容方案

### 当空间不足时

#### 方案 1: 清理历史数据

```sql
-- 连接到数据库
docker exec -it eagle-postgres psql -U graph-node -d graph-node

-- 删除 1 年前的交易记录
DELETE FROM sgd1.swap WHERE timestamp < extract(epoch from now() - interval '1 year');

-- 删除 6 个月前的小时数据
DELETE FROM sgd1.pair_hour_data WHERE hour_start_unix < extract(epoch from now() - interval '6 months');

-- VACUUM 回收空间
VACUUM FULL;
```

#### 方案 2: 迁移到其他盘

```bash
# 1. 停止服务
docker-compose down

# 2. 迁移数据
rsync -av /opt/subgraph/ /mnt/newdisk/subgraph/

# 3. 更新 docker-compose.yml 路径

# 4. 重启服务
docker-compose up -d
```

#### 方案 3: 添加新硬盘

```bash
# 1. 挂载新硬盘到 /mnt/subgraph-data

# 2. 迁移 PostgreSQL 数据（最大的部分）
docker-compose stop postgres
rsync -av /opt/subgraph/postgres/ /mnt/subgraph-data/postgres/

# 3. 更新 docker-compose.yml
# volumes:
#   - /mnt/subgraph-data/postgres:/var/lib/postgresql/data

# 4. 重启
docker-compose up -d
```

## 🎯 最佳实践

### 1. 定期监控

```bash
# 每天检查一次
/opt/subgraph/monitor-space.sh

# 设置告警（使用率 > 80%）
if [ $(df / | tail -1 | awk '{print $5}' | sed 's/%//') -gt 80 ]; then
    echo "警告: 磁盘使用率超过 80%" | mail -s "Disk Alert" admin@example.com
fi
```

### 2. 定期备份

```bash
# 自动备份（已配置定时任务）
# 每天凌晨 3 点执行

# 手动备份到远程
rsync -av /opt/subgraph/backups/ user@backup-server:/backups/subgraph/
```

### 3. 定期清理

```bash
# 自动清理（已配置定时任务）
# 每天凌晨 2 点执行

# 手动深度清理
docker system prune -a -f --volumes
```

## 📊 成本对比

### 使用系统盘 vs 新购硬盘

```
方案 A: 使用系统盘 (1.5TB)
├─ 硬盘成本: $0 (已有)
├─ 电费: $0 (共用)
├─ 管理成本: 低
└─ 总成本: $0 ✅

方案 B: 新购 1TB SSD
├─ 硬盘成本: $120
├─ 电费: $15/年
├─ 管理成本: 中
└─ 总成本: $165 (3年)

推荐: 使用系统盘（成本为零）
```

## ✅ 总结

### 系统盘部署优势

1. ✅ **零成本** - 使用现有硬盘
2. ✅ **简单** - 无需配置额外挂载
3. ✅ **统一管理** - 所有服务在一起
4. ✅ **足够空间** - 800GB 可用 10-12 个月

### 关键要点

- 📊 **监控**: 定期检查磁盘使用率
- 🧹 **清理**: 自动清理旧数据
- 💾 **备份**: 每天自动备份
- ⚠️ **告警**: 使用率 > 80% 需处理

### 下一步

1. ✅ 运行 `setup-storage-system-disk.sh`
2. ✅ 使用 `docker-compose-system-disk.yml`
3. ✅ 安装定时任务
4. ✅ 启动 Subgraph
5. ✅ 监控空间使用

**你的 1.5TB 系统盘完全够用！** 🎉
