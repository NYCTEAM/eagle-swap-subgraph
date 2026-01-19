# Eagle Swap Subgraph - 本地 RPC 配置

## 修改内容

已将 RPC 配置从远程 QuickNode 节点修改为本地 8545 端口。

### 修改文件

1. **docker-compose.yml** (第 33-34 行)
   ```yaml
   # 修改前
   ethereum: 'bsc:https://orbital-patient-dawn.bsc.quiknode.pro/e8d16ae592052dff62c8864fdffca477ccc7eb8e/'
   
   # 修改后
   ethereum: 'bsc:http://host.docker.internal:8545/'
   ```

2. **README.md**
   - 更新了 RPC 节点配置说明
   - 添加了本地 RPC 测试命令
   - 说明了 `host.docker.internal` 的作用

## 使用说明

### 前提条件

确保你的本地 BSC 节点运行在 8545 端口：

```bash
# 检查本地 RPC 是否可用
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### 启动 Subgraph

```bash
# 1. 启动 Docker 服务
docker-compose up -d

# 2. 查看日志（确认连接成功）
docker-compose logs -f graph-node

# 3. 安装依赖
npm install

# 4. 生成代码
npm run codegen

# 5. 构建
npm run build

# 6. 创建 subgraph
npm run create:local

# 7. 部署
npm run deploy:local
```

### 验证连接

Graph Node 日志中应该显示成功连接到本地 RPC：

```
INFO Connecting to Ethereum node at http://host.docker.internal:8545/
INFO Connected to Ethereum node, chain: bsc
```

## 技术说明

### host.docker.internal

- **作用**: 允许 Docker 容器访问宿主机的网络端口
- **支持**: Docker Desktop (Windows/Mac) 自动支持
- **Linux**: 需要添加 `--add-host=host.docker.internal:host-gateway` 参数

### 端口映射

| 服务 | 容器端口 | 宿主机端口 | 说明 |
|------|---------|-----------|------|
| Graph Node HTTP | 8000 | 8100 | GraphQL API |
| Graph Node WS | 8001 | 8101 | WebSocket |
| Graph Node Admin | 8020 | 8120 | 管理接口 |
| IPFS API | 5001 | 5011 | IPFS API |
| PostgreSQL | 5432 | 5433 | 数据库 |

### 切换回远程 RPC

如果需要切换回远程 RPC，修改 `docker-compose.yml`:

```yaml
# 使用远程 RPC
ethereum: 'bsc:https://rpc1.eagleswaps.com/bsc/'

# 或使用其他公共 RPC
# ethereum: 'bsc:https://bsc-dataseed.binance.org/'
```

## 故障排除

### 1. Graph Node 无法连接本地 RPC

**症状**: 日志显示 `Connection refused` 或 `timeout`

**解决方案**:
```bash
# 检查本地 RPC 是否运行
netstat -an | grep 8545

# 检查防火墙是否阻止
# Windows: 允许 Docker 访问本地网络

# Linux: 使用 host 网络模式
# 在 docker-compose.yml 中添加:
# network_mode: "host"
```

### 2. Docker 不支持 host.docker.internal

**症状**: Linux 系统上无法解析 `host.docker.internal`

**解决方案**:
```yaml
# 方案 1: 使用宿主机 IP
ethereum: 'bsc:http://192.168.1.100:8545/'

# 方案 2: 添加 extra_hosts
extra_hosts:
  - "host.docker.internal:host-gateway"
```

### 3. 本地 RPC 同步慢

**症状**: Graph Node 索引速度慢

**解决方案**:
- 确保本地节点完全同步
- 使用 Archive 节点（支持历史状态查询）
- 调整 `startBlock` 到更近的区块

## 性能优化

### 本地 RPC 优化

```yaml
# 在 docker-compose.yml 中调整参数
GRAPH_ETHEREUM_MAX_BLOCK_RANGE_SIZE: 1000  # 增加区块范围
GRAPH_ETHEREUM_TARGET_TRIGGERS_PER_BLOCK_RANGE: 200  # 增加触发器
```

### 数据库优化

```yaml
# PostgreSQL 配置
max_connections: 200
work_mem: 64MB
maintenance_work_mem: 256MB
shared_buffers: 2GB  # 根据内存调整
```

## 监控

### 查看索引进度

```bash
# 查看 Graph Node 日志
docker-compose logs -f graph-node

# 查看数据库状态
docker exec -it eagle-postgres psql -U graph-node -d graph-node -c "SELECT * FROM subgraphs.subgraph_deployment;"
```

### GraphQL 查询

访问 http://localhost:8100/subgraphs/name/eagle-swap/pancakeswap

```graphql
query {
  _meta {
    block {
      number
      hash
    }
    deployment
    hasIndexingErrors
  }
}
```

## 更新日期

2026-01-19

## 相关文档

- [Graph Node 文档](https://github.com/graphprotocol/graph-node)
- [Docker 网络文档](https://docs.docker.com/network/)
- [BSC 节点搭建](https://docs.bnbchain.org/docs/validator/fullnode)
