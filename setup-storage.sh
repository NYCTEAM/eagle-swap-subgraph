#!/bin/bash

# =====================================================
# Subgraph 存储空间设置脚本
# =====================================================
# 在你的服务器上创建 Subgraph 存储目录
# 使用现有的 NVMe 盘 (Chaindata)
# =====================================================

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Eagle Swap Subgraph - 存储空间设置${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 配置
BASE_DIR="/mnt/chaindata/subgraph"
POSTGRES_DIR="$BASE_DIR/postgres"
IPFS_DIR="$BASE_DIR/ipfs"
GRAPH_DIR="$BASE_DIR/graph-node"
DOCKER_DIR="$BASE_DIR/docker"
LOGS_DIR="$BASE_DIR/logs"
BACKUPS_DIR="$BASE_DIR/backups"

# 检查挂载点
echo -e "${YELLOW}1. 检查存储挂载点...${NC}"
if ! mountpoint -q /mnt/chaindata; then
    echo -e "${RED}❌ /mnt/chaindata 未挂载${NC}"
    echo -e "${YELLOW}   请先挂载 NVMe 盘到 /mnt/chaindata${NC}"
    exit 1
fi
echo -e "${GREEN}✅ /mnt/chaindata 已挂载${NC}"

# 显示可用空间
AVAILABLE=$(df -h /mnt/chaindata | tail -1 | awk '{print $4}')
echo -e "${CYAN}   可用空间: $AVAILABLE${NC}"

# 创建目录结构
echo ""
echo -e "${YELLOW}2. 创建目录结构...${NC}"

mkdir -p "$POSTGRES_DIR"
mkdir -p "$IPFS_DIR"
mkdir -p "$GRAPH_DIR"
mkdir -p "$DOCKER_DIR"
mkdir -p "$LOGS_DIR"
mkdir -p "$BACKUPS_DIR"

echo -e "${GREEN}✅ 目录创建完成${NC}"
echo -e "${CYAN}   基础目录: $BASE_DIR${NC}"

# 设置权限
echo ""
echo -e "${YELLOW}3. 设置目录权限...${NC}"

# PostgreSQL 需要特定用户权限
chown -R 999:999 "$POSTGRES_DIR"
chmod -R 755 "$POSTGRES_DIR"

# IPFS 权限
chown -R 1000:1000 "$IPFS_DIR"
chmod -R 755 "$IPFS_DIR"

# 其他目录
chmod -R 755 "$GRAPH_DIR"
chmod -R 755 "$DOCKER_DIR"
chmod -R 755 "$LOGS_DIR"
chmod -R 755 "$BACKUPS_DIR"

echo -e "${GREEN}✅ 权限设置完成${NC}"

# 创建监控脚本
echo ""
echo -e "${YELLOW}4. 创建监控脚本...${NC}"

cat > "$BASE_DIR/monitor-space.sh" << 'EOF'
#!/bin/bash

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Subgraph 存储监控 - $(date '+%Y-%m-%d %H:%M:%S')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 总体使用
echo "📊 总体存储使用:"
df -h /mnt/chaindata | grep chaindata
echo ""

# 各组件使用
echo "📁 各组件存储使用:"
BASE_DIR="/mnt/chaindata/subgraph"

if [ -d "$BASE_DIR/postgres" ]; then
    POSTGRES_SIZE=$(du -sh "$BASE_DIR/postgres" 2>/dev/null | cut -f1)
    echo "  PostgreSQL:  $POSTGRES_SIZE"
fi

if [ -d "$BASE_DIR/ipfs" ]; then
    IPFS_SIZE=$(du -sh "$BASE_DIR/ipfs" 2>/dev/null | cut -f1)
    echo "  IPFS:        $IPFS_SIZE"
fi

if [ -d "$BASE_DIR/graph-node" ]; then
    GRAPH_SIZE=$(du -sh "$BASE_DIR/graph-node" 2>/dev/null | cut -f1)
    echo "  Graph Node:  $GRAPH_SIZE"
fi

if [ -d "$BASE_DIR/logs" ]; then
    LOGS_SIZE=$(du -sh "$BASE_DIR/logs" 2>/dev/null | cut -f1)
    echo "  Logs:        $LOGS_SIZE"
fi

if [ -d "$BASE_DIR/backups" ]; then
    BACKUP_SIZE=$(du -sh "$BASE_DIR/backups" 2>/dev/null | cut -f1)
    echo "  Backups:     $BACKUP_SIZE"
fi

TOTAL_SIZE=$(du -sh "$BASE_DIR" 2>/dev/null | cut -f1)
echo "  ─────────────────────"
echo "  总计:        $TOTAL_SIZE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
EOF

chmod +x "$BASE_DIR/monitor-space.sh"
echo -e "${GREEN}✅ 监控脚本创建完成${NC}"
echo -e "${CYAN}   路径: $BASE_DIR/monitor-space.sh${NC}"

# 创建清理脚本
echo ""
echo -e "${YELLOW}5. 创建清理脚本...${NC}"

cat > "$BASE_DIR/cleanup.sh" << 'EOF'
#!/bin/bash

# 清理旧日志 (30天前)
echo "清理旧日志..."
find /mnt/chaindata/subgraph/logs -name "*.log" -mtime +30 -delete
echo "✅ 日志清理完成"

# 清理旧备份 (7天前)
echo "清理旧备份..."
find /mnt/chaindata/subgraph/backups -name "*.sql.gz" -mtime +7 -delete
echo "✅ 备份清理完成"

# PostgreSQL VACUUM
echo "执行 PostgreSQL VACUUM..."
docker exec eagle-postgres psql -U graph-node -d graph-node -c "VACUUM ANALYZE;" 2>/dev/null || echo "⚠️ PostgreSQL 未运行"
echo "✅ VACUUM 完成"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "清理完成 - $(date '+%Y-%m-%d %H:%M:%S')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
EOF

chmod +x "$BASE_DIR/cleanup.sh"
echo -e "${GREEN}✅ 清理脚本创建完成${NC}"
echo -e "${CYAN}   路径: $BASE_DIR/cleanup.sh${NC}"

# 创建备份脚本
echo ""
echo -e "${YELLOW}6. 创建备份脚本...${NC}"

cat > "$BASE_DIR/backup.sh" << 'EOF'
#!/bin/bash

BACKUP_DIR="/mnt/chaindata/subgraph/backups"
BACKUP_FILE="$BACKUP_DIR/subgraph-$(date +%Y%m%d-%H%M%S).sql.gz"

echo "开始备份 Subgraph 数据库..."
echo "备份文件: $BACKUP_FILE"

# 执行备份
docker exec eagle-postgres pg_dump -U graph-node graph-node | gzip > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "✅ 备份成功"
    echo "文件大小: $(du -h "$BACKUP_FILE" | cut -f1)"
    
    # 保留最近 4 个备份
    ls -t "$BACKUP_DIR"/subgraph-*.sql.gz | tail -n +5 | xargs rm -f 2>/dev/null
    echo "✅ 旧备份已清理"
else
    echo "❌ 备份失败"
    exit 1
fi
EOF

chmod +x "$BASE_DIR/backup.sh"
echo -e "${GREEN}✅ 备份脚本创建完成${NC}"
echo -e "${CYAN}   路径: $BASE_DIR/backup.sh${NC}"

# 显示目录结构
echo ""
echo -e "${YELLOW}7. 目录结构:${NC}"
tree -L 2 "$BASE_DIR" 2>/dev/null || ls -lah "$BASE_DIR"

# 显示空间分配
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ 存储空间设置完成！${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}📊 空间分配计划:${NC}"
echo -e "   PostgreSQL:  700 GB"
echo -e "   IPFS:        50 GB"
echo -e "   Graph Node:  50 GB"
echo -e "   Docker:      20 GB"
echo -e "   Logs:        30 GB"
echo -e "   Backups:     100 GB"
echo -e "   Reserved:    50 GB"
echo -e "   ${CYAN}─────────────────${NC}"
echo -e "   总计:        ${GREEN}1 TB${NC}"
echo ""
echo -e "${YELLOW}🔧 常用命令:${NC}"
echo -e "   监控空间: ${CYAN}$BASE_DIR/monitor-space.sh${NC}"
echo -e "   清理数据: ${CYAN}$BASE_DIR/cleanup.sh${NC}"
echo -e "   备份数据: ${CYAN}$BASE_DIR/backup.sh${NC}"
echo ""
echo -e "${YELLOW}📝 下一步:${NC}"
echo -e "   1. 修改 docker-compose.yml 使用这些目录"
echo -e "   2. 启动 Subgraph: ${CYAN}docker-compose up -d${NC}"
echo -e "   3. 监控空间使用: ${CYAN}$BASE_DIR/monitor-space.sh${NC}"
echo ""
