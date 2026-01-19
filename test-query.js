#!/usr/bin/env node

/**
 * Subgraph 查询测试脚本
 * 测试查询代币的所有流动性池
 */

const GRAPHQL_ENDPOINT = 'http://localhost:8100/subgraphs/name/eagle-swap/pancakeswap';

// 主流代币地址
const TOKENS = {
  WBNB: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
  USDT: '0x55d398326f99059fF775485246999027B3197955',
  USDC: '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d',
  BUSD: '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56',
};

/**
 * 查询代币的所有流动性池
 */
async function queryTokenPools(tokenAddress) {
  const query = `
    query {
      # 代币基本信息
      token(id: "${tokenAddress.toLowerCase()}") {
        id
        symbol
        name
        decimals
        totalLiquidity
        derivedUSD
        derivedBNB
        tradeVolumeUSD
        txCount
      }
      
      # V2 池子 (代币作为 token0)
      pairsAsToken0: pairs(
        first: 20
        orderBy: reserveUSD
        orderDirection: desc
        where: { token0: "${tokenAddress.toLowerCase()}" }
      ) {
        id
        token0 { symbol }
        token1 { symbol }
        reserve0
        reserve1
        reserveUSD
        token0Price
        token1Price
        volumeUSD
        txCount
      }
      
      # V2 池子 (代币作为 token1)
      pairsAsToken1: pairs(
        first: 20
        orderBy: reserveUSD
        orderDirection: desc
        where: { token1: "${tokenAddress.toLowerCase()}" }
      ) {
        id
        token0 { symbol }
        token1 { symbol }
        reserve0
        reserve1
        reserveUSD
        token0Price
        token1Price
        volumeUSD
        txCount
      }
      
      # V3 池子 (代币作为 token0)
      poolsV3AsToken0: poolsV3(
        first: 20
        orderBy: totalValueLockedUSD
        orderDirection: desc
        where: { token0: "${tokenAddress.toLowerCase()}" }
      ) {
        id
        token0 { symbol }
        token1 { symbol }
        feeTier
        liquidity
        totalValueLockedUSD
        token0Price
        token1Price
        volumeUSD
        txCount
      }
      
      # V3 池子 (代币作为 token1)
      poolsV3AsToken1: poolsV3(
        first: 20
        orderBy: totalValueLockedUSD
        orderDirection: desc
        where: { token1: "${tokenAddress.toLowerCase()}" }
      ) {
        id
        token0 { symbol }
        token1 { symbol }
        feeTier
        liquidity
        totalValueLockedUSD
        token0Price
        token1Price
        volumeUSD
        txCount
      }
    }
  `;

  try {
    const response = await fetch(GRAPHQL_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query }),
    });

    const result = await response.json();
    
    if (result.errors) {
      console.error('❌ GraphQL 错误:', result.errors);
      return null;
    }

    return result.data;
  } catch (error) {
    console.error('❌ 请求失败:', error.message);
    return null;
  }
}

/**
 * 查询最新交易
 */
async function queryRecentSwaps(limit = 10) {
  const query = `
    query {
      # V2 最新交易
      swapsV2: swaps(
        first: ${limit}
        orderBy: timestamp
        orderDirection: desc
      ) {
        id
        timestamp
        pair {
          token0 { symbol }
          token1 { symbol }
        }
        amount0In
        amount1In
        amount0Out
        amount1Out
        amountUSD
      }
      
      # V3 最新交易
      swapsV3(
        first: ${limit}
        orderBy: timestamp
        orderDirection: desc
      ) {
        id
        timestamp
        pool {
          token0 { symbol }
          token1 { symbol }
          feeTier
        }
        amount0
        amount1
        amountUSD
      }
    }
  `;

  try {
    const response = await fetch(GRAPHQL_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query }),
    });

    const result = await response.json();
    return result.data;
  } catch (error) {
    console.error('❌ 请求失败:', error.message);
    return null;
  }
}

/**
 * 查询 Subgraph 元数据
 */
async function queryMetadata() {
  const query = `
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
  `;

  try {
    const response = await fetch(GRAPHQL_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query }),
    });

    const result = await response.json();
    return result.data;
  } catch (error) {
    console.error('❌ 请求失败:', error.message);
    return null;
  }
}

/**
 * 格式化输出
 */
function printResults(data, tokenSymbol) {
  console.log('\n' + '='.repeat(80));
  console.log(`📊 ${tokenSymbol} 流动性池统计`);
  console.log('='.repeat(80));

  if (!data || !data.token) {
    console.log('❌ 未找到代币数据');
    return;
  }

  const { token, pairsAsToken0, pairsAsToken1, poolsV3AsToken0, poolsV3AsToken1 } = data;

  // 代币信息
  console.log('\n📌 代币信息:');
  console.log(`   名称: ${token.name} (${token.symbol})`);
  console.log(`   地址: ${token.id}`);
  console.log(`   价格: $${parseFloat(token.derivedUSD).toFixed(6)}`);
  console.log(`   总流动性: ${parseFloat(token.totalLiquidity).toFixed(2)}`);
  console.log(`   交易量: $${parseFloat(token.tradeVolumeUSD).toLocaleString()}`);
  console.log(`   交易次数: ${token.txCount}`);

  // V2 池子统计
  const totalV2Pools = pairsAsToken0.length + pairsAsToken1.length;
  const totalV2Liquidity = [...pairsAsToken0, ...pairsAsToken1]
    .reduce((sum, pair) => sum + parseFloat(pair.reserveUSD), 0);

  console.log('\n💧 V2 流动性池:');
  console.log(`   池子数量: ${totalV2Pools}`);
  console.log(`   总流动性: $${totalV2Liquidity.toLocaleString()}`);

  // 显示前 5 个 V2 池子
  const allV2Pools = [...pairsAsToken0, ...pairsAsToken1]
    .sort((a, b) => parseFloat(b.reserveUSD) - parseFloat(a.reserveUSD))
    .slice(0, 5);

  console.log('\n   前 5 大流动性池:');
  allV2Pools.forEach((pair, i) => {
    console.log(`   ${i + 1}. ${pair.token0.symbol}/${pair.token1.symbol}`);
    console.log(`      流动性: $${parseFloat(pair.reserveUSD).toLocaleString()}`);
    console.log(`      储备: ${parseFloat(pair.reserve0).toFixed(2)} ${pair.token0.symbol} / ${parseFloat(pair.reserve1).toFixed(2)} ${pair.token1.symbol}`);
    console.log(`      交易量: $${parseFloat(pair.volumeUSD).toLocaleString()}`);
  });

  // V3 池子统计
  const totalV3Pools = poolsV3AsToken0.length + poolsV3AsToken1.length;
  const totalV3Liquidity = [...poolsV3AsToken0, ...poolsV3AsToken1]
    .reduce((sum, pool) => sum + parseFloat(pool.totalValueLockedUSD), 0);

  console.log('\n🌊 V3 流动性池:');
  console.log(`   池子数量: ${totalV3Pools}`);
  console.log(`   总流动性: $${totalV3Liquidity.toLocaleString()}`);

  // 显示前 5 个 V3 池子
  const allV3Pools = [...poolsV3AsToken0, ...poolsV3AsToken1]
    .sort((a, b) => parseFloat(b.totalValueLockedUSD) - parseFloat(a.totalValueLockedUSD))
    .slice(0, 5);

  console.log('\n   前 5 大流动性池:');
  allV3Pools.forEach((pool, i) => {
    const feePercent = (parseInt(pool.feeTier) / 10000).toFixed(2);
    console.log(`   ${i + 1}. ${pool.token0.symbol}/${pool.token1.symbol} (${feePercent}%)`);
    console.log(`      TVL: $${parseFloat(pool.totalValueLockedUSD).toLocaleString()}`);
    console.log(`      交易量: $${parseFloat(pool.volumeUSD).toLocaleString()}`);
  });

  console.log('\n' + '='.repeat(80));
}

/**
 * 主函数
 */
async function main() {
  console.log('🚀 Eagle Swap Subgraph 测试\n');

  // 1. 检查 Subgraph 状态
  console.log('1️⃣ 检查 Subgraph 状态...');
  const meta = await queryMetadata();
  
  if (!meta) {
    console.log('❌ 无法连接到 Subgraph');
    console.log('   请确保 Graph Node 正在运行: docker-compose ps');
    return;
  }

  console.log('✅ Subgraph 运行正常');
  console.log(`   当前区块: ${meta._meta.block.number}`);
  console.log(`   区块哈希: ${meta._meta.block.hash}`);
  console.log(`   索引错误: ${meta._meta.hasIndexingErrors ? '是' : '否'}`);

  // 2. 查询 WBNB 流动性池
  console.log('\n2️⃣ 查询 WBNB 流动性池...');
  const wbnbData = await queryTokenPools(TOKENS.WBNB);
  if (wbnbData) {
    printResults(wbnbData, 'WBNB');
  }

  // 3. 查询 USDT 流动性池
  console.log('\n3️⃣ 查询 USDT 流动性池...');
  const usdtData = await queryTokenPools(TOKENS.USDT);
  if (usdtData) {
    printResults(usdtData, 'USDT');
  }

  // 4. 查询最新交易
  console.log('\n4️⃣ 查询最新交易...');
  const swaps = await queryRecentSwaps(5);
  
  if (swaps) {
    console.log('\n📈 最新 V2 交易:');
    swaps.swapsV2.forEach((swap, i) => {
      const date = new Date(parseInt(swap.timestamp) * 1000);
      console.log(`   ${i + 1}. ${swap.pair.token0.symbol}/${swap.pair.token1.symbol}`);
      console.log(`      金额: $${parseFloat(swap.amountUSD).toLocaleString()}`);
      console.log(`      时间: ${date.toLocaleString()}`);
    });

    console.log('\n📈 最新 V3 交易:');
    swaps.swapsV3.forEach((swap, i) => {
      const date = new Date(parseInt(swap.timestamp) * 1000);
      const feePercent = (parseInt(swap.pool.feeTier) / 10000).toFixed(2);
      console.log(`   ${i + 1}. ${swap.pool.token0.symbol}/${swap.pool.token1.symbol} (${feePercent}%)`);
      console.log(`      金额: $${parseFloat(swap.amountUSD).toLocaleString()}`);
      console.log(`      时间: ${date.toLocaleString()}`);
    });
  }

  console.log('\n✅ 测试完成！\n');
}

// 运行
main().catch(console.error);
