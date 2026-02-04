#!/bin/bash

# =====================================================
# Subgraph 一键部署脚本
# =====================================================
# 用途: 在 1.8T 系统盘上部署 Subgraph
# 存储: /root/eagle-swap-subgraph/data/
# =====================================================

set -e

echo "🚀 开始部署 Eagle Swap Subgraph..."
echo ""

# 检查当前目录
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ 错误: 请在 eagle-swap-subgraph 目录下运行此脚本"
    exit 1
fi

# 1. 创建数据目录
echo "📁 创建数据目录..."
mkdir -p data/postgres
mkdir -p data/ipfs
mkdir -p data/logs

# 设置权限
chmod -R 755 data/

echo "✅ 数据目录创建完成"
echo "   PostgreSQL: $(pwd)/data/postgres"
echo "   IPFS:       $(pwd)/data/ipfs"
echo ""

# 2. 检查硬盘空间
echo "💾 检查硬盘空间..."
AVAILABLE=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
echo "   可用空间: ${AVAILABLE}GB"

if [ "$AVAILABLE" -lt 200 ]; then
    echo "⚠️  警告: 可用空间不足 200GB，建议清理后再部署"
    read -p "是否继续? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo ""

# 3. 检查 Docker
echo "🐳 检查 Docker..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker 服务未运行，请启动 Docker"
    exit 1
fi
echo "✅ Docker 正常"
echo ""

# 4. 检查端口占用
echo "🔍 检查端口占用..."
PORTS=(8100 8101 8120 8130 8140 5433 5011)
for PORT in "${PORTS[@]}"; do
    if netstat -tuln | grep -q ":$PORT "; then
        echo "⚠️  警告: 端口 $PORT 已被占用"
        netstat -tuln | grep ":$PORT "
    fi
done
echo ""

# 5. 停止旧容器（如果存在）
echo "🛑 停止旧容器（如果存在）..."
docker-compose down 2>/dev/null || true
echo ""

# 6. 启动服务
echo "🚀 启动 Docker 服务..."
docker-compose up -d

# 等待服务启动
echo "⏳ 等待服务启动（30秒）..."
sleep 30

# 检查服务状态
echo ""
echo "📊 检查服务状态..."
docker-compose ps

# 检查 Graph Node 日志
echo ""
echo "📋 Graph Node 日志（最后 20 行）:"
docker-compose logs --tail 20 graph-node

echo ""
echo "✅ Docker 服务启动完成！"
echo ""

# 7. 安装 Node.js 依赖
echo "📦 安装 Node.js 依赖..."
if ! command -v npm &> /dev/null; then
    echo "⚠️  npm 未安装，跳过依赖安装"
    echo "   请手动安装 Node.js 和 npm，然后运行:"
    echo "   npm install && npm run codegen && npm run build"
else
    npm install
    echo "✅ 依赖安装完成"
    echo ""
    
    # 8. 生成代码
    echo "🔧 生成 Subgraph 代码..."
    npm run codegen
    echo "✅ 代码生成完成"
    echo ""
    
    # 9. 构建
    echo "🏗️  构建 Subgraph..."
    npm run build
    echo "✅ 构建完成"
    echo ""
    
    # 10. 创建 Subgraph
    echo "📝 创建 Subgraph..."
    npm run create:local || echo "⚠️  Subgraph 可能已存在"
    echo ""
    
    # 11. 部署 Subgraph
    echo "🚀 部署 Subgraph..."
    npm run deploy:local
    echo ""
fi

# 12. 显示部署信息
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 部署完成！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 服务信息:"
echo "   GraphQL API:       http://localhost:8100/subgraphs/name/eagle-swap/pancakeswap"
echo "   GraphQL Playground: http://localhost:8100/subgraphs/name/eagle-swap/pancakeswap/graphql"
echo "   Admin API:         http://localhost:8120"
echo "   Metrics:           http://localhost:8140"
echo ""
echo "📁 数据存储:"
echo "   PostgreSQL:        $(pwd)/data/postgres"
echo "   IPFS:              $(pwd)/data/ipfs"
echo ""
echo "🔧 常用命令:"
echo "   查看日志:          docker-compose logs -f graph-node"
echo "   查看同步进度:      ./monitor-progress.sh"
echo "   停止服务:          docker-compose down"
echo "   重启服务:          docker-compose restart"
echo "   清理旧数据:        ./cleanup-old-data.sh"
echo ""
echo "📖 详细文档:"
echo "   部署指南:          DEPLOYMENT_GUIDE_LIMITED.md"
echo "   存储需求:          STORAGE_REQUIREMENTS.md"
echo ""
echo "⏭️  下一步:"
echo "   1. 监控同步进度:   ./monitor-progress.sh"
echo "   2. 测试 API:       curl http://localhost:8100/subgraphs/name/eagle-swap/pancakeswap -d '{\"query\":\"{pairs(first:5){id}}\"}'  "
echo "   3. 设置定时清理:   crontab -e"
echo "      添加: 0 2 * * 0 $(pwd)/cleanup-old-data.sh >> /var/log/subgraph-cleanup.log 2>&1"
echo ""
