#!/bin/bash

# 实时监控 Subgraph 索引进度

echo "=================================================================="
echo "Eagle Swap Subgraph - 索引进度监控"
echo "=================================================================="
echo ""

# 获取 BSC 最新区块
BSC_LATEST=$(curl -s https://api.bscscan.com/api\?module=proxy\&action=eth_blockNumber\&apikey=YourApiKeyToken | jq -r '.result' | xargs printf "%d\n")
echo "目标区块：    $BSC_LATEST (BSC 实时最新)"

# 查询 Subgraph 状态
RESPONSE=$(curl -s http://localhost:8100/subgraphs/name/eagle-swap/pancakeswap/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ _meta { block { number } deployment hasIndexingErrors } }"}')

# 解析当前区块
CURRENT_BLOCK=$(echo "$RESPONSE" | jq -r '.data._meta.block.number // "null"')

# 解析部署 ID
DEPLOYMENT=$(echo "$RESPONSE" | jq -r '.data._meta.deployment // "unknown"')

# 解析是否有错误
HAS_ERRORS=$(echo "$RESPONSE" | jq -r '.data._meta.hasIndexingErrors // false')

# 如果无法获取数据，显示错误
if [ "$CURRENT_BLOCK" = "null" ] || [ -z "$CURRENT_BLOCK" ]; then
  echo "当前区块：    null"
  echo ""
  echo "⚠️  Subgraph 还未就绪或未部署"
  echo ""
  echo "请检查："
  echo "1. docker logs eagle-graph-node"
  echo "2. 确认 Subgraph 已部署"
  exit 1
fi

echo "当前区块：    $CURRENT_BLOCK"

# 查询起始区块（从 subgraph.yaml）
START_BLOCK=$(grep -m 1 "startBlock:" ~/eagle-swap-subgraph/subgraph.yaml | awk '{print $2}')
echo "起始区块：    $START_BLOCK"

# 计算进度
INDEXED=$((CURRENT_BLOCK - START_BLOCK))
REMAINING=$((BSC_LATEST - CURRENT_BLOCK))
TOTAL=$((BSC_LATEST - START_BLOCK))

if [ $TOTAL -gt 0 ]; then
  PROGRESS=$(awk "BEGIN {printf \"%.2f\", ($INDEXED / $TOTAL) * 100}")
else
  PROGRESS="0.00"
fi

echo "=================================================================="
echo "已索引：      $INDEXED 区块"
echo "剩余：        $REMAINING 区块"
echo "进度：        $PROGRESS%"
echo ""

# 磁盘使用
echo "💾 磁盘使用："
df -h /dev/nvme2n1p2 | tail -1
echo ""

# PostgreSQL 大小
PG_SIZE=$(docker exec eagle-postgres psql -U graph-node -d graph-node -t -c "SELECT pg_size_pretty(pg_database_size('graph-node'));" 2>/dev/null | xargs)
echo "💾 PostgreSQL: $PG_SIZE"
echo ""

# 显示状态
echo "=================================================================="
if [ "$HAS_ERRORS" = "true" ]; then
  echo "❌ 索引状态：有错误"
  echo ""
  echo "查看错误日志："
  echo "docker logs --tail 50 eagle-graph-node | grep -i error"
elif [ $REMAINING -eq 0 ]; then
  echo "✅ 索引完成！"
else
  echo "⏳ 正在索引中..."
  
  # 估算完成时间（假设 2 区块/秒）
  SECONDS_LEFT=$((REMAINING / 2))
  HOURS=$((SECONDS_LEFT / 3600))
  MINUTES=$(((SECONDS_LEFT % 3600) / 60))
  
  echo ""
  echo "预计剩余时间：约 $HOURS 小时 $MINUTES 分钟"
fi

echo "=================================================================="
echo "更新时间：$(date '+%Y-%m-%d %H:%M:%S')"
echo "按 Ctrl+C 退出"
