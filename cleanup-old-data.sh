#!/bin/bash

# =====================================================
# Subgraph 数据清理脚本 - 保留最近 3 个月数据
# =====================================================
# 用途: 定期清理旧数据，控制存储在 150GB 以内
# 运行: 每周执行一次 (crontab: 0 2 * * 0)
# =====================================================

set -e

echo "🧹 开始清理 Subgraph 旧数据..."
echo "保留策略: 最近 3 个月交易 + 所有日数据"
echo ""

# 计算 3 个月前的时间戳
THREE_MONTHS_AGO=$(date -d '3 months ago' +%s)
echo "📅 清理时间点: $(date -d @$THREE_MONTHS_AGO)"
echo ""

# 连接到 PostgreSQL
CONTAINER_NAME="eagle-postgres"
DB_USER="graph-node"
DB_NAME="graph-node"

# 检查容器是否运行
if ! docker ps | grep -q $CONTAINER_NAME; then
    echo "❌ PostgreSQL 容器未运行"
    exit 1
fi

echo "🗑️  清理 V2 Swap 交易记录 (3个月前)..."
docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "
DELETE FROM sgd1.swap 
WHERE timestamp < $THREE_MONTHS_AGO;
" || echo "⚠️  Swap 表可能不存在或已清理"

echo "🗑️  清理 V3 Swap 交易记录 (3个月前)..."
docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "
DELETE FROM sgd1.swap_v3 
WHERE timestamp < $THREE_MONTHS_AGO;
" || echo "⚠️  SwapV3 表可能不存在或已清理"

echo "🗑️  清理小时数据 (3个月前)..."
docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "
DELETE FROM sgd1.pair_hour_data 
WHERE hour_start_unix < $THREE_MONTHS_AGO;
" || echo "⚠️  PairHourData 表可能不存在或已清理"

echo "🗑️  清理 Sync 事件 (3个月前)..."
docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "
DELETE FROM sgd1.sync 
WHERE timestamp < $THREE_MONTHS_AGO;
" || echo "⚠️  Sync 表可能不存在或已清理"

echo ""
echo "🔧 执行 VACUUM 回收空间..."
docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "VACUUM FULL ANALYZE;"

echo ""
echo "📊 清理后数据库大小:"
docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "
SELECT 
    pg_size_pretty(pg_database_size('$DB_NAME')) as database_size;
"

echo ""
echo "📊 各表大小 (Top 10):"
docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'sgd1'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
"

echo ""
echo "✅ 清理完成！"
echo "💡 建议: 将此脚本添加到 crontab 每周自动执行"
echo "   crontab -e"
echo "   0 2 * * 0 /path/to/cleanup-old-data.sh >> /var/log/subgraph-cleanup.log 2>&1"
