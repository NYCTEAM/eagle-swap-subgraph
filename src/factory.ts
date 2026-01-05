import { BigInt, BigDecimal, Address, log } from '@graphprotocol/graph-ts'
import { PairCreated } from '../generated/PancakeFactoryV2/PancakeFactoryV2'
import { Pair, Token, PancakeFactory, Bundle } from '../generated/schema'
import { PancakePairV2 as PairTemplate } from '../generated/templates'
import { ERC20 } from '../generated/PancakeFactoryV2/ERC20'

let ZERO_BD = BigDecimal.fromString('0')
let ZERO_BI = BigInt.fromI32(0)
let ONE_BI = BigInt.fromI32(1)

let FACTORY_ADDRESS = '0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73'

// Stablecoins for USD price calculation
let USDT_ADDRESS = '0x55d398326f99059ff775485246999027b3197955'
let BUSD_ADDRESS = '0xe9e7cea3dedca5984780bafc599bd69add087d56'
let USDC_ADDRESS = '0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d'

// WBNB address
let WBNB_ADDRESS = '0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c'

export function handlePairCreated(event: PairCreated): void {
  // Load or create factory
  let factory = PancakeFactory.load(FACTORY_ADDRESS)
  if (factory === null) {
    factory = new PancakeFactory(FACTORY_ADDRESS)
    factory.pairCount = 0
    factory.totalVolumeUSD = ZERO_BD
    factory.totalVolumeBNB = ZERO_BD
    factory.totalLiquidityUSD = ZERO_BD
    factory.totalLiquidityBNB = ZERO_BD
    factory.txCount = ZERO_BI

    // Create bundle for BNB price
    let bundle = new Bundle('1')
    bundle.bnbPrice = ZERO_BD
    bundle.save()
  }
  factory.pairCount = factory.pairCount + 1
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

  // Create pair
  let pair = new Pair(event.params.pair.toHexString())
  pair.token0 = token0.id
  pair.token1 = token1.id
  pair.reserve0 = ZERO_BD
  pair.reserve1 = ZERO_BD
  pair.totalSupply = ZERO_BD
  pair.reserveBNB = ZERO_BD
  pair.reserveUSD = ZERO_BD
  pair.trackedReserveBNB = ZERO_BD
  pair.token0Price = ZERO_BD
  pair.token1Price = ZERO_BD
  pair.volumeToken0 = ZERO_BD
  pair.volumeToken1 = ZERO_BD
  pair.volumeUSD = ZERO_BD
  pair.txCount = ZERO_BI
  pair.createdAtTimestamp = event.block.timestamp
  pair.createdAtBlockNumber = event.block.number
  pair.liquidityProviderCount = ZERO_BI
  pair.syncCount = ZERO_BI
  pair.lastSyncTimestamp = ZERO_BI
  pair.lastSyncBlock = ZERO_BI
  pair.save()

  // Create the tracked contract based on the template
  PairTemplate.create(event.params.pair)

  log.info('New pair created: {} (token0: {}, token1: {})', [
    event.params.pair.toHexString(),
    token0.symbol,
    token1.symbol
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
