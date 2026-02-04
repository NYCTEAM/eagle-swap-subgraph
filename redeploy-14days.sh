#!/bin/bash

echo "🔥 重新部署 Subgraph（从 14 天前开始）"
echo "================================================"

cd ~/eagle-swap-subgraph

# 1. 计算 14 天前的区块号
echo "📊 计算起始区块..."
CURRENT_BLOCK=$(curl -s -X POST http://127.0.0.1:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  | jq -r '.result' | xargs printf "%d")

# BSC 每 3 秒一个区块，14 天 = 403,200 个区块
BLOCKS_14_DAYS=403200
START_BLOCK=$((CURRENT_BLOCK - BLOCKS_14_DAYS))

echo "当前区块: $CURRENT_BLOCK"
echo "起始区块: $START_BLOCK (14 天前)"

# 2. 更新 subgraph.yaml
echo "📝 更新 subgraph.yaml..."
sed -i "s/startBlock: [0-9]*/startBlock: $START_BLOCK/g" subgraph.yaml

echo "✅ 已更新 startBlock 为: $START_BLOCK"

# 3. 重新构建
echo "🔨 重新构建 Subgraph..."
npm run codegen
npm run build

# 4. 停止并清理容器数据
echo "🗑️  清理旧数据..."
docker-compose down
rm -rf data/postgres/*
rm -rf data/ipfs/*

# 5. 重启服务
echo "🚀 启动服务..."
docker-compose up -d

# 等待服务启动
echo "⏳ 等待服务启动（30秒）..."
sleep 30

# 6. 删除旧的 Subgraph
echo "🗑️  删除旧的 Subgraph..."
npx graph remove --node http://localhost:8120/ eagle-swap/pancakeswap 2>/dev/null || true

# 7. 创建新的 Subgraph
echo "📦 创建新的 Subgraph..."
npx graph create --node http://localhost:8120/ eagle-swap/pancakeswap

# 8. 部署
echo "🚀 部署 Subgraph..."
npx graph deploy --node http://localhost:8120/ --ipfs http://localhost:5011 eagle-swap/pancakeswap

echo ""
echo "✅ 部署完成！"
echo ""
echo "📊 监控进度："
echo "   ./monitor-progress.sh"
echo ""
echo "📝 查看日志："
echo "   docker logs -f eagle-graph-node"
