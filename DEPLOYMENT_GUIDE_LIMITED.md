# Subgraph 部署指南 - 限制存储版本

## 📊 存储配置

**目标：控制存储在 150GB 以内**

### 数据保留策略

```
✅ 保留:
├─ 所有代币信息 (Token)
├─ 所有池子信息 (Pair/PoolV3)
├─ 最近 3 个月交易记录 (Swap/SwapV3)
├─ 所有日数据 (PairDayData/TokenDayData)
└─ 最近 3 个月小时数据 (PairHourData)

❌ 自动清理:
├─ 3 个月前的交易记录
├─ 3 个月前的小时数据
└─ 3 个月前的 Sync 事件
```

### 预期存储使用

```
初始部署:        ~91 GB
3 个月后:        ~140 GB
稳定后:          ~150 GB (不再增长)
```

---

## 🚀 部署步骤

### 1. 服务器准备

```bash
# SSH 到服务器
ssh root@your-server

# 创建工作目录
mkdir -p /root/eagle-swap-subgraph
cd /root/eagle-swap-subgraph

# 克隆仓库
git clone https://github.com/NYCTEAM/eagle-swap-subgraph.git .
```

### 2. 配置 RPC 连接

编辑 `docker-compose.yml`：

```bash
nano docker-compose.yml
```

**如果 RPC 在本地 8545 端口（默认配置）：**
```yaml
ethereum: 'bsc:http://host.docker.internal:8545/'
```

**如果 RPC 在其他端口或地址：**
```yaml
# 本地其他端口
ethereum: 'bsc:http://127.0.0.1:YOUR_PORT/'

# 或使用域名
ethereum: 'bsc:https://RPC1.eagleswaps.com/BSC'
```

### 3. 启动服务

```bash
# 启动 PostgreSQL + IPFS + Graph Node
docker-compose up -d

# 查看日志
docker-compose logs -f graph-node
```

**等待看到：**
```
✅ Successfully connected to Ethereum node
✅ Starting JSON-RPC admin server at: http://localhost:8020
```

### 4. 部署 Subgraph

```bash
# 安装依赖
npm install

# 生成代码
npm run codegen

# 构建
npm run build

# 创建 Subgraph
npm run create:local

# 部署
npm run deploy:local
```

**部署成功后会看到：**
```
✅ Deployed to http://localhost:8100/subgraphs/name/eagle-swap/pancakeswap
```

### 5. 监控同步进度

```bash
# 使用监控脚本
chmod +x monitor-progress.sh
./monitor-progress.sh
```

**输出示例：**
```
📊 Subgraph 同步进度
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
当前区块:     79,186,000
目标区块:     79,200,000
已同步:       14,000 / 14,000 (100%)
同步速度:     500 blocks/min
预计完成:     已完成
```

### 6. 测试 GraphQL API

```bash
# 测试查询
curl http://localhost:8100/subgraphs/name/eagle-swap/pancakeswap \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ pairs(first: 5, orderBy: reserveUSD, orderDirection: desc) { id token0 { symbol } token1 { symbol } reserveUSD } }"
  }'
```

**成功响应：**
```json
{
  "data": {
    "pairs": [
      {
        "id": "0x...",
        "token0": { "symbol": "WBNB" },
        "token1": { "symbol": "USDT" },
        "reserveUSD": "123456789.50"
      }
    ]
  }
}
```

---

## 🧹 设置自动清理

### 1. 配置清理脚本

```bash
# 赋予执行权限
chmod +x cleanup-old-data.sh

# 测试运行
./cleanup-old-data.sh
```

### 2. 添加到 Crontab（每周日凌晨 2 点执行）

```bash
crontab -e
```

添加：
```
0 2 * * 0 /root/eagle-swap-subgraph/cleanup-old-data.sh >> /var/log/subgraph-cleanup.log 2>&1
```

### 3. 查看清理日志

```bash
tail -f /var/log/subgraph-cleanup.log
```

---

## 📊 监控存储使用

### 创建监控脚本

```bash
cat > check-storage.sh << 'EOF'
#!/bin/bash
echo "=== Subgraph 存储使用 ==="
echo ""
echo "硬盘使用:"
df -h / | grep -v Filesystem
echo ""
echo "PostgreSQL 数据库大小:"
docker exec eagle-postgres psql -U graph-node -d graph-node -c "
SELECT pg_size_pretty(pg_database_size('graph-node')) as size;
"
echo ""
echo "IPFS 使用:"
du -sh /var/lib/docker/volumes/eagle-swap-subgraph_ipfs_data || echo "N/A"
echo ""
echo "Docker 使用:"
docker system df
EOF

chmod +x check-storage.sh
```

### 定期检查

```bash
# 手动检查
./check-storage.sh

# 或添加到 crontab 每天检查
0 0 * * * /root/eagle-swap-subgraph/check-storage.sh >> /var/log/subgraph-storage.log 2>&1
```

---

## 🎯 GraphQL 查询示例

### 获取代币价格

```graphql
query {
  tokens(
    first: 10
    orderBy: tradeVolumeUSD
    orderDirection: desc
  ) {
    id
    symbol
    name
    derivedUSD
    totalLiquidity
  }
}
```

### 获取流动性池

```graphql
query {
  pairs(
    first: 20
    orderBy: reserveUSD
    orderDirection: desc
  ) {
    id
    token0 { symbol }
    token1 { symbol }
    reserve0
    reserve1
    reserveUSD
    token0Price
    token1Price
  }
}
```

### 获取最近交易

```graphql
query {
  swaps(
    first: 50
    orderBy: timestamp
    orderDirection: desc
  ) {
    id
    timestamp
    pair {
      token0 { symbol }
      token1 { symbol }
    }
    amount0In
    amount1In
    amount0Out
    amount1Out
    amountUSD
  }
}
```

### 获取特定代币的价格历史

```graphql
query {
  tokenDayDatas(
    first: 30
    orderBy: date
    orderDirection: desc
    where: { token: "0x..." }
  ) {
    date
    priceUSD
    dailyVolumeUSD
    totalLiquidityUSD
  }
}
```

---

## 🔧 故障排除

### Graph Node 无法连接 RPC

```bash
# 检查 RPC 是否可用
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# 检查 Graph Node 日志
docker-compose logs graph-node | grep -i error
```

### 同步速度慢

```bash
# 检查 RPC 响应时间
time curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# 调整批处理大小（在 docker-compose.yml）
GRAPH_ETHEREUM_BLOCK_BATCH_SIZE: 20  # 增加到 20
```

### 数据库空间不足

```bash
# 立即清理旧数据
./cleanup-old-data.sh

# 检查是否有未使用的索引
docker exec eagle-postgres psql -U graph-node -d graph-node -c "
SELECT schemaname, tablename, indexname, pg_size_pretty(pg_relation_size(indexrelid))
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 10;
"
```

### 重新部署

```bash
# 停止服务
docker-compose down

# 清理数据（可选，会删除所有数据）
docker-compose down -v
rm -rf data/

# 重新启动
docker-compose up -d

# 重新部署 Subgraph
npm run deploy:local
```

---

## 📈 性能优化

### PostgreSQL 配置优化

编辑 `docker-compose.yml`，增加 PostgreSQL 性能参数：

```yaml
postgres:
  command:
    - "postgres"
    - "-cshared_preload_libraries=pg_stat_statements"
    - "-cmax_connections=200"
    - "-cwork_mem=64MB"
    - "-cmaintenance_work_mem=256MB"
    - "-ceffective_cache_size=4GB"      # 新增
    - "-cshared_buffers=1GB"            # 新增
    - "-cwal_buffers=16MB"              # 新增
```

### Graph Node 优化

```yaml
graph-node:
  environment:
    GRAPH_ETHEREUM_BLOCK_BATCH_SIZE: 20
    GRAPH_ETHEREUM_MAX_BLOCK_RANGE_SIZE: 20
    GRAPH_ALLOW_NON_DETERMINISTIC_IPFS: 'true'
```

---

## 📝 维护清单

### 每日
- [ ] 检查同步状态：`./monitor-progress.sh`
- [ ] 查看错误日志：`docker-compose logs --tail 100 graph-node | grep ERROR`

### 每周
- [ ] 自动清理旧数据（Crontab）
- [ ] 检查存储使用：`./check-storage.sh`
- [ ] 备份数据库（可选）

### 每月
- [ ] 检查同步完整性
- [ ] 评估存储使用趋势
- [ ] 更新 Graph Node 版本（可选）

---

## 🎉 部署完成

部署成功后，你的 Subgraph 将：

✅ 提供实时的 PancakeSwap V2/V3 数据
✅ 支持 GraphQL 查询
✅ 自动同步新区块
✅ 自动清理旧数据
✅ 存储控制在 150GB 以内

**API 端点：**
- GraphQL API: `http://localhost:8100/subgraphs/name/eagle-swap/pancakeswap`
- GraphQL Playground: `http://localhost:8100/subgraphs/name/eagle-swap/pancakeswap/graphql`

**下一步：**
将此 API 集成到你的 Eagle Swap Backend，用于获取实时价格和流动性数据！
