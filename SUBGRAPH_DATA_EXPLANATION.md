# Subgraph 数据索引说明

## 📊 索引的数据范围

### ✅ 完整覆盖

Subgraph 会索引 **PancakeSwap 上所有的流动性池**，包括：

1. **V2 所有交易对**
   - ✅ USDT/代币
   - ✅ WBNB/代币
   - ✅ 代币A/代币B
   - ✅ **任意两个代币的组合**

2. **V3 所有费率池**
   - ✅ 0.01% 费率
   - ✅ 0.05% 费率
   - ✅ 0.25% 费率
   - ✅ 1% 费率

### 🎯 关键点

> **是的，代币里面所有的流动性底池都会统计到数据库！**

无论是：
- USDT → 代币
- WBNB → 代币
- 代币A → 代币B
- 任何其他组合

只要在 PancakeSwap 上有流动性池，Subgraph 都会索引。

## 📝 索引的数据类型

### 1. 代币数据 (Token)

```javascript
{
  id: "0x代币地址",
  symbol: "TA",
  name: "Token A",
  decimals: 18,
  totalLiquidity: "1000000",      // 该代币在所有池子的总流动性
  derivedUSD: "1.23",             // 价格 (USD)
  derivedBNB: "0.0045",           // 价格 (BNB)
  tradeVolumeUSD: "5000000",      // 总交易量
  txCount: 12345                  // 交易次数
}
```

### 2. V2 流动性池 (Pair)

```javascript
{
  id: "0x池子地址",
  token0: { symbol: "USDT" },
  token1: { symbol: "TA" },
  reserve0: "500000",             // USDT 储备
  reserve1: "1000000",            // TA 储备
  reserveUSD: "1000000",          // 总流动性 (USD)
  token0Price: "2.0",             // 1 USDT = 2 TA
  token1Price: "0.5",             // 1 TA = 0.5 USDT
  volumeUSD: "100000",            // 交易量
  txCount: 500                    // 交易次数
}
```

### 3. V3 流动性池 (PoolV3)

```javascript
{
  id: "0x池子地址",
  token0: { symbol: "USDT" },
  token1: { symbol: "TA" },
  feeTier: 500,                   // 0.05% 费率
  liquidity: "1000000000000",     // 流动性
  totalValueLockedUSD: "2000000", // TVL
  token0Price: "2.0",
  token1Price: "0.5",
  volumeUSD: "200000",
  txCount: 800
}
```

### 4. 交易记录 (Swap)

```javascript
{
  id: "0xtxhash-0",
  timestamp: 1705680000,
  pair: { token0: "USDT", token1: "TA" },
  amount0In: "100",               // 输入 100 USDT
  amount1Out: "200",              // 输出 200 TA
  amountUSD: "100",               // 交易金额 $100
  sender: "0x用户地址"
}
```

### 5. 历史数据

- **小时数据** (PairHourData): 每小时的价格、流动性、交易量
- **日数据** (PairDayData): 每天的价格、流动性、交易量
- **代币日数据** (TokenDayData): 每个代币每天的统计

## 🔍 实际查询示例

### 示例 1: 查询 TA 代币的所有流动性池

```graphql
query {
  token(id: "0xTA代币地址") {
    symbol
    totalLiquidity
    derivedUSD
    
    # 所有 V2 池子
    pairs {
      token1 { symbol }
      reserveUSD
    }
  }
  
  # 所有 V3 池子
  poolsV3(where: { token0: "0xTA代币地址" }) {
    token1 { symbol }
    feeTier
    totalValueLockedUSD
  }
}
```

**返回结果示例**:
```json
{
  "token": {
    "symbol": "TA",
    "totalLiquidity": "5000000",
    "derivedUSD": "1.23",
    "pairs": [
      { "token1": { "symbol": "USDT" }, "reserveUSD": "2000000" },
      { "token1": { "symbol": "WBNB" }, "reserveUSD": "1500000" },
      { "token1": { "symbol": "BUSD" }, "reserveUSD": "500000" }
    ]
  },
  "poolsV3": [
    { "token1": { "symbol": "USDT" }, "feeTier": 500, "totalValueLockedUSD": "3000000" },
    { "token1": { "symbol": "WBNB" }, "feeTier": 2500, "totalValueLockedUSD": "2000000" }
  ]
}
```

### 示例 2: 查询最大流动性池

```graphql
query {
  # V2 最大流动性池
  pairs(
    first: 10
    orderBy: reserveUSD
    orderDirection: desc
  ) {
    token0 { symbol }
    token1 { symbol }
    reserveUSD
  }
  
  # V3 最大流动性池
  poolsV3(
    first: 10
    orderBy: totalValueLockedUSD
    orderDirection: desc
  ) {
    token0 { symbol }
    token1 { symbol }
    feeTier
    totalValueLockedUSD
  }
}
```

### 示例 3: 查询特定交易对的所有池子

```graphql
query {
  # USDT/TA 的所有 V2 池子
  pairs(where: {
    token0: "0xUSDT地址",
    token1: "0xTA地址"
  }) {
    reserveUSD
    token0Price
    volumeUSD
  }
  
  # USDT/TA 的所有 V3 池子（不同费率）
  poolsV3(where: {
    token0: "0xUSDT地址",
    token1: "0xTA地址"
  }) {
    feeTier
    totalValueLockedUSD
    token0Price
  }
}
```

## 🏗️ 数据流程

```
BSC Archive 节点 (localhost:8545)
    ↓ 监听事件
Graph Node
    ↓ 处理数据
PostgreSQL 数据库
    ↓ 提供查询
GraphQL API (localhost:8100)
    ↓ 集成
Eagle Swap Backend
    ↓ 使用
前端报价服务
```

## 📈 监听的事件

### V2 Factory
```solidity
event PairCreated(
    address indexed token0,
    address indexed token1,
    address pair,
    uint256
);
```
**作用**: 新池子创建时触发，Subgraph 开始跟踪这个池子

### V2 Pair
```solidity
event Sync(uint112 reserve0, uint112 reserve1);
```
**作用**: 储备更新时触发，更新流动性和价格

```solidity
event Swap(
    address indexed sender,
    uint256 amount0In,
    uint256 amount1In,
    uint256 amount0Out,
    uint256 amount1Out,
    address indexed to
);
```
**作用**: 交易发生时触发，记录交易数据

### V3 Factory
```solidity
event PoolCreated(
    address indexed token0,
    address indexed token1,
    uint24 indexed fee,
    int24 tickSpacing,
    address pool
);
```
**作用**: 新 V3 池子创建

### V3 Pool
```solidity
event Swap(
    address indexed sender,
    address indexed recipient,
    int256 amount0,
    int256 amount1,
    uint160 sqrtPriceX96,
    uint128 liquidity,
    int24 tick
);
```
**作用**: V3 交易发生

## 🎯 与你的系统集成

### 当前配置

你的 BSC Archive 节点:
- **地址**: localhost:8545
- **当前区块**: 76,184,704
- **同步速度**: 5.50 块/秒

Subgraph 配置:
- **RPC**: http://host.docker.internal:8545/
- **起始区块**: 71,552,000 (PancakeSwap V2/V3 部署区块)
- **GraphQL API**: http://localhost:8100

### 数据更新频率

- **新区块**: 每 3 秒（BSC 出块时间）
- **事件处理**: 实时（Graph Node 监听）
- **数据库更新**: 实时（事件处理后立即写入）
- **GraphQL 查询**: 实时（直接查询数据库）

### 性能优化

1. **Archive 节点**: 支持历史状态查询
2. **起始区块**: 从 71,552,000 开始，跳过早期无关区块
3. **批量处理**: Graph Node 批量处理事件
4. **索引优化**: PostgreSQL 索引加速查询

## 🧪 测试脚本

使用提供的测试脚本验证数据:

```bash
# 运行测试
node test-query.js
```

测试内容:
1. ✅ Subgraph 连接状态
2. ✅ 当前索引区块
3. ✅ WBNB 所有流动性池
4. ✅ USDT 所有流动性池
5. ✅ 最新交易记录

## 📊 数据统计示例

假设 TA 代币有以下池子:

### V2 池子
| 交易对 | 流动性 (USD) | 储备 |
|--------|-------------|------|
| TA/USDT | $2,000,000 | 1M TA / 2M USDT |
| TA/WBNB | $1,500,000 | 1M TA / 500 WBNB |
| TA/BUSD | $500,000 | 250K TA / 500K BUSD |

### V3 池子
| 交易对 | 费率 | TVL (USD) |
|--------|------|-----------|
| TA/USDT | 0.05% | $3,000,000 |
| TA/USDT | 0.25% | $1,000,000 |
| TA/WBNB | 0.25% | $2,000,000 |

### 总计
- **V2 总流动性**: $4,000,000
- **V3 总流动性**: $6,000,000
- **总流动性**: $10,000,000
- **池子数量**: 6 个

**所有这些数据都会被 Subgraph 索引到数据库！**

## 🚀 下一步

1. ✅ 等待 BSC 节点完全同步
2. ✅ 启动 Subgraph (docker-compose up -d)
3. ✅ 等待索引完成（从 71,552,000 到当前区块）
4. ✅ 运行测试脚本验证数据
5. 🔄 集成到 Eagle Swap Backend
6. 🔄 前端使用 GraphQL 查询流动性

## 📚 相关文档

- [README.md](./README.md) - 项目文档
- [RPC_LOCAL_CONFIG.md](./RPC_LOCAL_CONFIG.md) - RPC 配置
- [QUICK_START_LOCAL.md](./QUICK_START_LOCAL.md) - 快速启动
- [schema.graphql](./schema.graphql) - 数据结构
- [test-query.js](./test-query.js) - 测试脚本

## ❓ 常见问题

### Q1: Subgraph 会索引所有代币吗？
**A**: 是的，只要代币在 PancakeSwap 上有流动性池，就会被索引。

### Q2: 包括小币种吗？
**A**: 是的，无论市值大小，只要有池子就会索引。

### Q3: 历史数据会保留吗？
**A**: 是的，所有交易历史、价格历史都会保留。

### Q4: 多久更新一次？
**A**: 实时更新，每个新区块（约 3 秒）都会处理。

### Q5: 数据库会很大吗？
**A**: 是的，建议至少 500GB SSD 存储空间。

### Q6: 可以查询历史价格吗？
**A**: 可以，通过 PairHourData 和 PairDayData 查询。

### Q7: 支持自定义代币吗？
**A**: 支持，只要在 PancakeSwap 上创建了池子。

### Q8: V2 和 V3 数据分开吗？
**A**: 是的，但可以通过 GraphQL 一起查询。
