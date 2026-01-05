#!/bin/bash

# =====================================================
# Eagle Swap Subgraph - 一键部署脚本
# =====================================================
# 使用方法：
#   chmod +x deploy.sh
#   ./deploy.sh
# =====================================================

set -e

echo "🚀 Eagle Swap Subgraph 部署开始..."
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker 未安装，请先安装 Docker${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose 未安装${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker 已安装${NC}"

# 检查 Node.js
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}⚠️ Node.js 未安装，正在安装...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

echo -e "${GREEN}✅ Node.js $(node -v)${NC}"

# 创建数据目录
echo ""
echo "📁 创建数据目录..."
mkdir -p data/postgres data/ipfs

# 启动 Docker 服务
echo ""
echo "🐳 启动 Docker 服务..."
docker-compose up -d

# 等待服务启动
echo ""
echo "⏳ 等待服务启动 (30秒)..."
sleep 30

# 检查服务状态
echo ""
echo "🔍 检查服务状态..."
docker-compose ps

# 安装 npm 依赖
echo ""
echo "📦 安装 npm 依赖..."
npm install

# 生成代码
echo ""
echo "🔧 生成 GraphQL 代码..."
npm run codegen

# 构建 subgraph
echo ""
echo "🏗️ 构建 Subgraph..."
npm run build

# 创建 subgraph
echo ""
echo "📝 创建 Subgraph..."
npm run create:local || true

# 部署 subgraph
echo ""
echo "🚀 部署 Subgraph..."
npm run deploy:local

echo ""
echo "=============================================="
echo -e "${GREEN}✅ 部署完成！${NC}"
echo "=============================================="
echo ""
echo "📊 GraphQL API:"
echo "   http://localhost:8000/subgraphs/name/eagle-swap/pancakeswap"
echo ""
echo "🎮 GraphQL Playground:"
echo "   http://localhost:8000/subgraphs/name/eagle-swap/pancakeswap/graphql"
echo ""
echo "📈 查看日志:"
echo "   docker-compose logs -f graph-node"
echo ""
echo "🛑 停止服务:"
echo "   docker-compose down"
echo ""
