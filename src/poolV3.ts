import { BigInt, BigDecimal, log } from '@graphprotocol/graph-ts'
import { Swap as SwapEvent } from '../generated/templates/PancakePoolV3/PancakePoolV3'
import { PoolV3, Token, SwapV3, Transaction, Bundle, PancakeFactoryV3 } from '../generated/schema'

let ZERO_BD = BigDecimal.fromString('0')
let ZERO_BI = BigInt.fromI32(0)
let ONE_BI = BigInt.fromI32(1)
let BI_18 = BigInt.fromI32(18)

let FACTORY_ADDRESS_V3 = '0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865'

// Stablecoins
let USDT_ADDRESS = '0x55d398326f99059ff775485246999027b3197955'
let BUSD_ADDRESS = '0xe9e7cea3dedca5984780bafc599bd69add087d56'
let USDC_ADDRESS = '0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d'

function exponentToBigDecimal(decimals: BigInt): BigDecimal {
  let bd = BigDecimal.fromString('1')
  for (let i = ZERO_BI; i.lt(decimals as BigInt); i = i.plus(ONE_BI)) {
    bd = bd.times(BigDecimal.fromString('10'))
  }
  return bd
}

function convertTokenToDecimal(tokenAmount: BigInt, exchangeDecimals: BigInt): BigDecimal {
  if (exchangeDecimals == ZERO_BI) {
    return tokenAmount.toBigDecimal()
  }
  return tokenAmount.toBigDecimal().div(exponentToBigDecimal(exchangeDecimals))
}

function safeAbs(value: BigInt): BigInt {
  if (value.lt(ZERO_BI)) {
    return value.neg()
  }
  return value
}

// Handle V3 Swap event
export function handleSwapV3(event: SwapEvent): void {
  let pool = PoolV3.load(event.address.toHexString())
  if (pool === null) {
    log.warning('V3 Pool not found: {}', [event.address.toHexString()])
    return
  }

  let token0 = Token.load(pool.token0)
  let token1 = Token.load(pool.token1)
  if (token0 === null || token1 === null) {
    return
  }

  // Update pool state
  pool.sqrtPriceX96 = event.params.sqrtPriceX96
  pool.tick = BigInt.fromI32(event.params.tick)
  pool.liquidity = event.params.liquidity

  // Calculate price from sqrtPriceX96
  // price = (sqrtPriceX96 / 2^96)^2
  let sqrtPrice = event.params.sqrtPriceX96.toBigDecimal()
  let Q96 = BigDecimal.fromString('79228162514264337593543950336') // 2^96
  let priceRatio = sqrtPrice.div(Q96)
  let price = priceRatio.times(priceRatio)
  
  // Adjust for decimals
  let decimal0 = token0.decimals
  let decimal1 = token1.decimals
  let decimalDiff = decimal0.minus(decimal1)
  
  if (decimalDiff.gt(ZERO_BI)) {
    price = price.times(exponentToBigDecimal(decimalDiff))
  } else if (decimalDiff.lt(ZERO_BI)) {
    price = price.div(exponentToBigDecimal(decimalDiff.neg()))
  }

  pool.token0Price = price
  if (price.gt(ZERO_BD)) {
    pool.token1Price = BigDecimal.fromString('1').div(price)
  }

  // Convert amounts
  let amount0 = convertTokenToDecimal(safeAbs(event.params.amount0), token0.decimals)
  let amount1 = convertTokenToDecimal(safeAbs(event.params.amount1), token1.decimals)

  // Calculate USD amount
  let amountUSD = ZERO_BD
  let bundle = Bundle.load('1')
  if (bundle !== null) {
    let token0Address = token0.id.toLowerCase()
    let token1Address = token1.id.toLowerCase()
    
    if (token0Address == USDT_ADDRESS || token0Address == BUSD_ADDRESS || token0Address == USDC_ADDRESS) {
      amountUSD = amount0
    } else if (token1Address == USDT_ADDRESS || token1Address == BUSD_ADDRESS || token1Address == USDC_ADDRESS) {
      amountUSD = amount1
    } else if (token0.derivedUSD.gt(ZERO_BD)) {
      amountUSD = amount0.times(token0.derivedUSD)
    } else if (token1.derivedUSD.gt(ZERO_BD)) {
      amountUSD = amount1.times(token1.derivedUSD)
    }
  }

  // Update pool volume
  pool.volumeToken0 = pool.volumeToken0.plus(amount0)
  pool.volumeToken1 = pool.volumeToken1.plus(amount1)
  pool.volumeUSD = pool.volumeUSD.plus(amountUSD)
  pool.txCount = pool.txCount.plus(ONE_BI)
  pool.save()

  // Update token volumes
  token0.tradeVolume = token0.tradeVolume.plus(amount0)
  token0.tradeVolumeUSD = token0.tradeVolumeUSD.plus(amountUSD)
  token0.txCount = token0.txCount.plus(ONE_BI)
  token0.save()

  token1.tradeVolume = token1.tradeVolume.plus(amount1)
  token1.tradeVolumeUSD = token1.tradeVolumeUSD.plus(amountUSD)
  token1.txCount = token1.txCount.plus(ONE_BI)
  token1.save()

  // Update factory
  let factory = PancakeFactoryV3.load(FACTORY_ADDRESS_V3)
  if (factory !== null) {
    factory.totalVolumeUSD = factory.totalVolumeUSD.plus(amountUSD)
    factory.txCount = factory.txCount.plus(ONE_BI)
    factory.save()
  }

  // Create transaction if not exists
  let transaction = Transaction.load(event.transaction.hash.toHexString())
  if (transaction === null) {
    transaction = new Transaction(event.transaction.hash.toHexString())
    transaction.blockNumber = event.block.number
    transaction.timestamp = event.block.timestamp
    transaction.save()
  }

  // Create swap entity
  let swapId = event.transaction.hash.toHexString() + '-' + event.logIndex.toString()
  let swap = new SwapV3(swapId)
  swap.transaction = transaction.id
  swap.timestamp = event.block.timestamp
  swap.pool = pool.id
  swap.sender = event.params.sender
  swap.recipient = event.params.recipient
  swap.amount0 = convertTokenToDecimal(event.params.amount0, token0.decimals)
  swap.amount1 = convertTokenToDecimal(event.params.amount1, token1.decimals)
  swap.amountUSD = amountUSD
  swap.sqrtPriceX96 = event.params.sqrtPriceX96
  swap.tick = BigInt.fromI32(event.params.tick)
  swap.logIndex = event.logIndex
  swap.save()
}
