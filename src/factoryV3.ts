import { BigInt, BigDecimal, Address, log } from '@graphprotocol/graph-ts'
import { PoolCreated } from '../generated/PancakeFactoryV3/PancakeFactoryV3'
import { PoolV3, Token, PancakeFactoryV3 } from '../generated/schema'
import { PancakePoolV3 as PoolTemplate } from '../generated/templates'
import { ERC20 } from '../generated/PancakeFactoryV3/ERC20'

let ZERO_BD = BigDecimal.fromString('0')
let ZERO_BI = BigInt.fromI32(0)
let ONE_BI = BigInt.fromI32(1)

let FACTORY_ADDRESS_V3 = '0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865'

export function handlePoolCreatedV3(event: PoolCreated): void {
  // Load or create factory
  let factory = PancakeFactoryV3.load(FACTORY_ADDRESS_V3)
  if (factory === null) {
    factory = new PancakeFactoryV3(FACTORY_ADDRESS_V3)
    factory.poolCount = 0
    factory.totalVolumeUSD = ZERO_BD
    factory.totalValueLockedUSD = ZERO_BD
    factory.txCount = ZERO_BI
  }
  factory.poolCount = factory.poolCount + 1
  factory.save()

  // Create token0
  let token0 = Token.load(event.params.token0.toHexString())
  if (token0 === null) {
    token0 = new Token(event.params.token0.toHexString())
    token0.symbol = fetchTokenSymbol(event.params.token0)
    token0.name = fetchTokenName(event.params.token0)
    token0.decimals = fetchTokenDecimals(event.params.token0)
    token0.totalSupply = ZERO_BD
    token0.tradeVolume = ZERO_BD
    token0.tradeVolumeUSD = ZERO_BD
    token0.txCount = ZERO_BI
    token0.totalLiquidity = ZERO_BD
    token0.derivedBNB = ZERO_BD
    token0.derivedUSD = ZERO_BD
    token0.save()
  }

  // Create token1
  let token1 = Token.load(event.params.token1.toHexString())
  if (token1 === null) {
    token1 = new Token(event.params.token1.toHexString())
    token1.symbol = fetchTokenSymbol(event.params.token1)
    token1.name = fetchTokenName(event.params.token1)
    token1.decimals = fetchTokenDecimals(event.params.token1)
    token1.totalSupply = ZERO_BD
    token1.tradeVolume = ZERO_BD
    token1.tradeVolumeUSD = ZERO_BD
    token1.txCount = ZERO_BI
    token1.totalLiquidity = ZERO_BD
    token1.derivedBNB = ZERO_BD
    token1.derivedUSD = ZERO_BD
    token1.save()
  }

  // Create pool
  let pool = new PoolV3(event.params.pool.toHexString())
  pool.token0 = token0.id
  pool.token1 = token1.id
  pool.feeTier = BigInt.fromI32(event.params.fee)
  pool.liquidity = ZERO_BI
  pool.sqrtPriceX96 = ZERO_BI
  pool.tick = ZERO_BI
  pool.token0Price = ZERO_BD
  pool.token1Price = ZERO_BD
  pool.volumeToken0 = ZERO_BD
  pool.volumeToken1 = ZERO_BD
  pool.volumeUSD = ZERO_BD
  pool.txCount = ZERO_BI
  pool.totalValueLockedToken0 = ZERO_BD
  pool.totalValueLockedToken1 = ZERO_BD
  pool.totalValueLockedUSD = ZERO_BD
  pool.createdAtTimestamp = event.block.timestamp
  pool.createdAtBlockNumber = event.block.number
  pool.save()

  // Create the tracked contract based on the template
  PoolTemplate.create(event.params.pool)

  log.info('New V3 pool created: {} (token0: {}, token1: {}, fee: {})', [
    event.params.pool.toHexString(),
    token0.symbol,
    token1.symbol,
    event.params.fee.toString()
  ])
}

function fetchTokenSymbol(tokenAddress: Address): string {
  let contract = ERC20.bind(tokenAddress)
  let result = contract.try_symbol()
  if (result.reverted) {
    return 'UNKNOWN'
  }
  return result.value
}

function fetchTokenName(tokenAddress: Address): string {
  let contract = ERC20.bind(tokenAddress)
  let result = contract.try_name()
  if (result.reverted) {
    return 'Unknown Token'
  }
  return result.value
}

function fetchTokenDecimals(tokenAddress: Address): BigInt {
  let contract = ERC20.bind(tokenAddress)
  let result = contract.try_decimals()
  if (result.reverted) {
    return BigInt.fromI32(18)
  }
  return BigInt.fromI32(result.value)
}
