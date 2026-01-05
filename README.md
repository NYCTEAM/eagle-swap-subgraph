# Eagle Swap Subgraph

PancakeSwap V2/V3 流动性索引器，为 Eagle Swap 提供实时价格和流动性数据。

## 架构

```
BSC 节点 → Graph Node → PostgreSQL → GraphQL API → Eagle Swap Backend
```

## 快速开始

### 1. 启动 Docker 服务

```bash
# 启动 Graph Node + PostgreSQL + IPFS
docker-compose up -d

# 查看日志
docker-compose logs -f graph-node
```

### 2. 安装依赖并生成代码

```bash
npm install
npm run codegen
npm run build
```

### 3. 部署 Subgraph

```bash
# 创建 subgraph
npm run create:local

# 部署
npm run deploy:local
```

## 配置

### RPC 节点

在 `docker-compose.yml` 中配置你的 BSC 节点：

```yaml
ethereum: 'bsc:https://RPC1.eagleswaps.com/BSC'
```

### 起始区块

在 `subgraph.yaml` 中配置起始区块：

```yaml
startBlock: 6809737  # PancakeSwap V2 Factory 部署区块
```

## GraphQL 查询示例

### 获取代币价格

```graphql
query {
  tokens(first: 10, orderBy: tradeVolumeUSD, orderDirection: desc) {
    id
    symbol
    name
    derivedUSD
    tradeVolumeUSD
  }
}
```

### 获取交易对流动性

```graphql
query {
  pairs(first: 10, orderBy: reserveUSD, orderDirection: desc) {
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

### 获取最新 Swap

```graphql
query {
  swaps(first: 20, orderBy: timestamp, orderDirection: desc) {
    id
    timestamp
    pair { token0 { symbol } token1 { symbol } }
    amount0In
    amount1In
    amount0Out
    amount1Out
    amountUSD
  }
}
```

## API 端点

| 端点 | 说明 |
|------|------|
| http://localhost:8000/subgraphs/name/eagle-swap/pancakeswap | GraphQL API |
| http://localhost:8000/subgraphs/name/eagle-swap/pancakeswap/graphql | GraphQL Playground |
| http://localhost:8020 | Admin API |
| http://localhost:8030 | Index Node |
| http://localhost:8040 | Metrics |

## 数据实体

| 实体 | 说明 |
|------|------|
| `Token` | 代币信息和价格 |
| `Pair` | 交易对和流动性 |
| `Swap` | Swap 交易记录 |
| `Sync` | 储备更新事件 |
| `PairHourData` | 小时级数据 |
| `PairDayData` | 日级数据 |

## 服务器要求

| 资源 | 最低要求 | 推荐配置 |
|------|----------|----------|
| CPU | 4 核 | 8+ 核 |
| 内存 | 16GB | 32GB+ |
| 存储 | 200GB SSD | 500GB+ NVMe |
| 网络 | 100Mbps | 1Gbps |

## 故障排除

### Graph Node 无法连接 RPC

```bash
# 检查 RPC 是否可用
curl -X POST https://RPC1.eagleswaps.com/BSC \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### 重置索引

```bash
docker-compose down -v
rm -rf data/
docker-compose up -d
```

## License

MIT
