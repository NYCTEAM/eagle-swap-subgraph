#!/bin/bash

# =====================================================
# Subgraph 存储空间设置脚本 - 系统盘版本
# =====================================================
# 在系统盘上创建 Subgraph 存储目录
# 适用于 1.5TB 系统盘
# =====================================================

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Eagle Swap Subgraph - 系统盘存储设置${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 配置 - 使用系统盘路径
BASE_DIR="/opt/subgraph"  # 或者使用 /var/lib/subgraph
POSTGRES_DIR="$BASE_DIR/postgres"
IPFS_DIR="$BASE_DIR/ipfs"
GRAPH_DIR="$BASE_DIR/graph-node"
DOCKER_DIR="$BASE_DIR/docker"
LOGS_DIR="$BASE_DIR/logs"
BACKUPS_DIR="$BASE_DIR/backups"

# 检查系统盘空间
echo -e "${YELLOW}1. 检查系统盘空间...${NC}"
TOTAL=$(df -h / | tail -1 | awk '{print $2}')
USED=$(df -h / | tail -1 | awk '{print $3}')
AVAILABLE=$(df -h / | tail -1 | awk '{print $4}')
USE_PERCENT=$(df -h / | tail -1 | awk '{print $5}')

echo -e "${CYAN}   总容量: $TOTAL${NC}"
echo -e "${CYAN}   已使用: $USED ($USE_PERCENT)${NC}"
echo -e "${CYAN}   可用空间: $AVAILABLE${NC}"

# 检查可用空间是否足够
AVAILABLE_GB=$(df / | tail -1 | awk '{print $4}')
REQUIRED_GB=$((800 * 1024 * 1024))  # 800GB in KB

if [ $AVAILABLE_GB -lt $REQUIRED_GB ]; then
    echo -e "${RED}❌ 可用空间不足${NC}"
    echo -e "${YELLOW}   建议至少有 800GB 可用空间${NC}"
    echo -e "${YELLOW}   当前可用: $AVAILABLE${NC}"
    read -p "是否继续? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}✅ 空间检查通过${NC}"

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

cat > "$BASE_DIR/monitor-space.sh" << 'EOFMON'
#!/bin/bash

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Subgraph 存储监控 - $(date '+%Y-%m-%d %H:%M:%S')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 系统盘总体使用
echo "📊 系统盘存储使用:"
df -h / | grep -E "Filesystem|/$"
echo ""

# Subgraph 各组件使用
echo "📁 Subgraph 组件存储:"
BASE_DIR="/opt/subgraph"

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

# 检查磁盘使用率
echo ""
echo "⚠️  磁盘使用率警告:"
USE_PERCENT=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $USE_PERCENT -gt 80 ]; then
    echo "  ❌ 磁盘使用率过高: ${USE_PERCENT}%"
    echo "  建议清理旧数据或扩容"
elif [ $USE_PERCENT -gt 70 ]; then
    echo "  ⚠️  磁盘使用率较高: ${USE_PERCENT}%"
    echo "  建议关注磁盘空间"
else
    echo "  ✅ 磁盘使用率正常: ${USE_PERCENT}%"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
EOFMON

chmod +x "$BASE_DIR/monitor-space.sh"
echo -e "${GREEN}✅ 监控脚本创建完成${NC}"
echo -e "${CYAN}   路径: $BASE_DIR/monitor-space.sh${NC}"

# 创建清理脚本
echo ""
echo -e "${YELLOW}5. 创建清理脚本...${NC}"

cat > "$BASE_DIR/cleanup.sh" << 'EOFCLEAN'
#!/bin/bash

BASE_DIR="/opt/subgraph"

echo "开始清理 Subgraph 数据..."
echo ""

# 清理旧日志 (30天前)
echo "1. 清理旧日志 (30天前)..."
LOGS_DELETED=$(find "$BASE_DIR/logs" -name "*.log" -mtime +30 -delete -print | wc -l)
echo "   ✅ 删除 $LOGS_DELETED 个日志文件"

# 清理旧备份 (7天前)
echo "2. 清理旧备份 (7天前)..."
BACKUPS_DELETED=$(find "$BASE_DIR/backups" -name "*.sql.gz" -mtime +7 -delete -print | wc -l)
echo "   ✅ 删除 $BACKUPS_DELETED 个备份文件"

# Docker 清理
echo "3. 清理 Docker 未使用资源..."
docker system prune -f > /dev/null 2>&1
echo "   ✅ Docker 清理完成"

# PostgreSQL VACUUM
echo "4. 执行 PostgreSQL VACUUM..."
if docker ps | grep -q eagle-postgres; then
    docker exec eagle-postgres psql -U graph-node -d graph-node -c "VACUUM ANALYZE;" > /dev/null 2>&1
    echo "   ✅ VACUUM 完成"
else
    echo "   ⚠️  PostgreSQL 未运行"
fi

# 显示清理后的空间
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "清理完成 - $(date '+%Y-%m-%d %H:%M:%S')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
df -h / | grep -E "Filesystem|/$"
EOFCLEAN

chmod +x "$BASE_DIR/cleanup.sh"
echo -e "${GREEN}✅ 清理脚本创建完成${NC}"
echo -e "${CYAN}   路径: $BASE_DIR/cleanup.sh${NC}"

# 创建备份脚本
echo ""
echo -e "${YELLOW}6. 创建备份脚本...${NC}"

cat > "$BASE_DIR/backup.sh" << 'EOFBACKUP'
#!/bin/bash

BASE_DIR="/opt/subgraph"
BACKUP_DIR="$BASE_DIR/backups"
BACKUP_FILE="$BACKUP_DIR/subgraph-$(date +%Y%m%d-%H%M%S).sql.gz"

echo "开始备份 Subgraph 数据库..."
echo "备份文件: $BACKUP_FILE"

# 检查 PostgreSQL 是否运行
if ! docker ps | grep -q eagle-postgres; then
    echo "❌ PostgreSQL 未运行"
    exit 1
fi

# 执行备份
docker exec eagle-postgres pg_dump -U graph-node graph-node | gzip > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "✅ 备份成功"
    echo "文件大小: $(du -h "$BACKUP_FILE" | cut -f1)"
    
    # 保留最近 4 个备份
    ls -t "$BACKUP_DIR"/subgraph-*.sql.gz | tail -n +5 | xargs rm -f 2>/dev/null
    echo "✅ 旧备份已清理 (保留最近 4 个)"
    
    # 显示所有备份
    echo ""
    echo "当前备份列表:"
    ls -lh "$BACKUP_DIR"/subgraph-*.sql.gz 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
else
    echo "❌ 备份失败"
    exit 1
fi
EOFBACKUP

chmod +x "$BASE_DIR/backup.sh"
echo -e "${GREEN}✅ 备份脚本创建完成${NC}"
echo -e "${CYAN}   路径: $BASE_DIR/backup.sh${NC}"

# 创建定时任务配置
echo ""
echo -e "${YELLOW}7. 创建定时任务配置...${NC}"

cat > "$BASE_DIR/crontab.txt" << 'EOFCRON'
# Subgraph 定时任务

# 每天凌晨 2 点执行清理
0 2 * * * /opt/subgraph/cleanup.sh >> /opt/subgraph/logs/cleanup.log 2>&1

# 每天凌晨 3 点执行备份
0 3 * * * /opt/subgraph/backup.sh >> /opt/subgraph/logs/backup.log 2>&1

# 每小时监控空间
0 * * * * /opt/subgraph/monitor-space.sh >> /opt/subgraph/logs/monitor.log 2>&1
EOFCRON

echo -e "${GREEN}✅ 定时任务配置创建完成${NC}"
echo -e "${CYAN}   路径: $BASE_DIR/crontab.txt${NC}"
echo -e "${YELLOW}   安装: crontab $BASE_DIR/crontab.txt${NC}"

# 显示目录结构
echo ""
echo -e "${YELLOW}8. 目录结构:${NC}"
tree -L 2 "$BASE_DIR" 2>/dev/null || ls -lah "$BASE_DIR"

# 显示空间分配
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ 系统盘存储设置完成！${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}📊 空间分配计划 (系统盘 1.5TB):${NC}"
echo -e "   PostgreSQL:  600 GB"
echo -e "   IPFS:        50 GB"
echo -e "   Graph Node:  50 GB"
echo -e "   Docker:      20 GB"
echo -e "   Logs:        30 GB"
echo -e "   Backups:     50 GB"
echo -e "   ${CYAN}─────────────────${NC}"
echo -e "   Subgraph 总计: ${GREEN}800 GB${NC}"
echo -e "   系统预留:      ${GREEN}700 GB${NC}"
echo ""
echo -e "${YELLOW}🔧 常用命令:${NC}"
echo -e "   监控空间: ${CYAN}$BASE_DIR/monitor-space.sh${NC}"
echo -e "   清理数据: ${CYAN}$BASE_DIR/cleanup.sh${NC}"
echo -e "   备份数据: ${CYAN}$BASE_DIR/backup.sh${NC}"
echo ""
echo -e "${YELLOW}⚠️  重要提示:${NC}"
echo -e "   • 系统盘使用率建议保持在 80% 以下"
echo -e "   • 定期运行清理脚本释放空间"
echo -e "   • 监控磁盘空间，及时处理告警"
echo ""
echo -e "${YELLOW}📝 下一步:${NC}"
echo -e "   1. 修改 docker-compose.yml 使用 $BASE_DIR"
echo -e "   2. 安装定时任务: ${CYAN}crontab $BASE_DIR/crontab.txt${NC}"
echo -e "   3. 启动 Subgraph: ${CYAN}cd eagle-swap-subgraph && docker-compose up -d${NC}"
echo -e "   4. 监控空间: ${CYAN}$BASE_DIR/monitor-space.sh${NC}"
echo ""
