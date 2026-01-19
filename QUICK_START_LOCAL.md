# 快速启动 - 本地 RPC 配置

## 一键启动脚本

### Windows (PowerShell)

创建 `start-local.ps1`:

```powershell
# 检查本地 RPC
Write-Host "检查本地 RPC (8545)..." -ForegroundColor Yellow
$response = Invoke-WebRequest -Uri "http://localhost:8545" -Method POST `
    -Headers @{"Content-Type"="application/json"} `
    -Body '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' `
    -ErrorAction SilentlyContinue

if ($response) {
    Write-Host "✅ 本地 RPC 运行正常" -ForegroundColor Green
} else {
    Write-Host "❌ 本地 RPC 未运行，请先启动 BSC 节点" -ForegroundColor Red
    exit 1
}

# 启动 Docker 服务
Write-Host "`n启动 Docker 服务..." -ForegroundColor Yellow
docker-compose up -d

# 等待服务启动
Write-Host "`n等待服务启动 (30秒)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# 安装依赖
Write-Host "`n安装依赖..." -ForegroundColor Yellow
npm install

# 生成代码
Write-Host "`n生成代码..." -ForegroundColor Yellow
npm run codegen

# 构建
Write-Host "`n构建 Subgraph..." -ForegroundColor Yellow
npm run build

# 创建
Write-Host "`n创建 Subgraph..." -ForegroundColor Yellow
npm run create:local

# 部署
Write-Host "`n部署 Subgraph..." -ForegroundColor Yellow
npm run deploy:local

Write-Host "`n✅ 部署完成！" -ForegroundColor Green
Write-Host "`nGraphQL API: http://localhost:8100/subgraphs/name/eagle-swap/pancakeswap" -ForegroundColor Cyan
Write-Host "查看日志: docker-compose logs -f graph-node" -ForegroundColor Cyan
```

运行:
```powershell
powershell -ExecutionPolicy Bypass -File start-local.ps1
```

### Linux/Mac (Bash)

创建 `start-local.sh`:

```bash
#!/bin/bash

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 检查本地 RPC
echo -e "${YELLOW}检查本地 RPC (8545)...${NC}"
if curl -s -X POST http://localhost:8545 \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' > /dev/null; then
    echo -e "${GREEN}✅ 本地 RPC 运行正常${NC}"
else
    echo -e "${RED}❌ 本地 RPC 未运行，请先启动 BSC 节点${NC}"
    exit 1
fi

# 启动 Docker 服务
echo -e "\n${YELLOW}启动 Docker 服务...${NC}"
docker-compose up -d

# 等待服务启动
echo -e "\n${YELLOW}等待服务启动 (30秒)...${NC}"
sleep 30

# 安装依赖
echo -e "\n${YELLOW}安装依赖...${NC}"
npm install

# 生成代码
echo -e "\n${YELLOW}生成代码...${NC}"
npm run codegen

# 构建
echo -e "\n${YELLOW}构建 Subgraph...${NC}"
npm run build

# 创建
echo -e "\n${YELLOW}创建 Subgraph...${NC}"
npm run create:local || true

# 部署
echo -e "\n${YELLOW}部署 Subgraph...${NC}"
npm run deploy:local

echo -e "\n${GREEN}✅ 部署完成！${NC}"
echo -e "\n${CYAN}GraphQL API: http://localhost:8100/subgraphs/name/eagle-swap/pancakeswap${NC}"
echo -e "${CYAN}查看日志: docker-compose logs -f graph-node${NC}"
```

运行:
```bash
chmod +x start-local.sh
./start-local.sh
```

## 手动步骤

### 1. 检查本地 RPC

```bash
# Windows (PowerShell)
Invoke-WebRequest -Uri "http://localhost:8545" -Method POST `
    -Headers @{"Content-Type"="application/json"} `
    -Body '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Linux/Mac
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### 2. 启动 Docker

```bash
docker-compose up -d
```

### 3. 查看日志

```bash
# 查看所有服务
docker-compose logs -f

# 只查看 Graph Node
docker-compose logs -f graph-node

# 只查看 PostgreSQL
docker-compose logs -f postgres
```

### 4. 部署 Subgraph

```bash
# 安装依赖
npm install

# 生成代码
npm run codegen

# 构建
npm run build

# 创建（首次部署）
npm run create:local

# 部署
npm run deploy:local
```

## 验证部署

### 检查服务状态

```bash
# 查看容器状态
docker-compose ps

# 应该看到 3 个容器运行中:
# - eagle-graph-node
# - eagle-postgres
# - eagle-ipfs
```

### 测试 GraphQL API

访问: http://localhost:8100/subgraphs/name/eagle-swap/pancakeswap

或使用 curl:

```bash
curl -X POST http://localhost:8100/subgraphs/name/eagle-swap/pancakeswap \
  -H "Content-Type: application/json" \
  -d '{"query":"{ _meta { block { number } } }"}'
```

### 查看索引进度

```graphql
query {
  _meta {
    block {
      number
      hash
      timestamp
    }
    deployment
    hasIndexingErrors
  }
}
```

## 常用命令

### 重启服务

```bash
# 重启所有服务
docker-compose restart

# 只重启 Graph Node
docker-compose restart graph-node
```

### 停止服务

```bash
# 停止但保留数据
docker-compose stop

# 停止并删除容器（保留数据卷）
docker-compose down

# 停止并删除所有数据
docker-compose down -v
```

### 更新 Subgraph

```bash
# 修改代码后重新部署
npm run codegen
npm run build
npm run deploy:local
```

### 重置索引

```bash
# 完全重置
docker-compose down -v
rm -rf data/
docker-compose up -d

# 等待 30 秒后重新部署
sleep 30
npm run create:local
npm run deploy:local
```

## 监控和调试

### 查看数据库

```bash
# 连接到 PostgreSQL
docker exec -it eagle-postgres psql -U graph-node -d graph-node

# 查看表
\dt

# 查看 subgraph 状态
SELECT * FROM subgraphs.subgraph_deployment;

# 退出
\q
```

### 查看 IPFS

访问: http://localhost:5012

### 查看 Metrics

访问: http://localhost:8140/metrics

## 故障排除

### Graph Node 无法连接 RPC

```bash
# 检查 Graph Node 日志
docker-compose logs graph-node | grep -i "error\|connection"

# 检查本地 RPC
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# 重启 Graph Node
docker-compose restart graph-node
```

### PostgreSQL 连接失败

```bash
# 检查 PostgreSQL 状态
docker-compose logs postgres

# 检查连接
docker exec -it eagle-postgres pg_isready -U graph-node

# 重启 PostgreSQL
docker-compose restart postgres
```

### IPFS 连接失败

```bash
# 检查 IPFS 状态
docker-compose logs ipfs

# 测试 IPFS API
curl http://localhost:5011/api/v0/version

# 重启 IPFS
docker-compose restart ipfs
```

### 索引速度慢

1. 检查本地 RPC 同步状态
2. 调整 `startBlock` 到更近的区块
3. 增加 Docker 资源限制
4. 优化 PostgreSQL 配置

## 性能调优

### 调整 Graph Node 参数

编辑 `docker-compose.yml`:

```yaml
environment:
  # 增加区块范围
  GRAPH_ETHEREUM_MAX_BLOCK_RANGE_SIZE: 1000
  
  # 增加触发器
  GRAPH_ETHEREUM_TARGET_TRIGGERS_PER_BLOCK_RANGE: 200
  
  # 启用并行处理
  GRAPH_ETHEREUM_PARALLEL_BLOCK_RANGES: 10
```

### 调整 PostgreSQL 参数

编辑 `docker-compose.yml`:

```yaml
command:
  - "postgres"
  - "-cshared_preload_libraries=pg_stat_statements"
  - "-cmax_connections=200"
  - "-cwork_mem=128MB"
  - "-cmaintenance_work_mem=512MB"
  - "-cshared_buffers=2GB"
  - "-ceffective_cache_size=4GB"
```

## 下一步

1. ✅ 本地 RPC 配置完成
2. ✅ Subgraph 部署成功
3. 🔄 集成到 Eagle Swap Backend
4. 🔄 配置定时同步
5. 🔄 添加监控告警

## 相关文档

- [RPC_LOCAL_CONFIG.md](./RPC_LOCAL_CONFIG.md) - 详细配置说明
- [README.md](./README.md) - 项目文档
- [deploy.sh](./deploy.sh) - 自动部署脚本
