import { BigInt, BigDecimal, log } from '@graphprotocol/graph-ts'
import { Sync, Swap as SwapEvent } from '../generated/templates/PancakePairV2/PancakePairV2'
import { Pair, Token, Swap, Sync as SyncEntity, Transaction, Bundle, PancakeFactory } from '../generated/schema'

let ZERO_BD = BigDecimal.fromString('0')
let ZERO_BI = BigInt.fromI32(0)
let ONE_BI = BigInt.fromI32(1)
let BI_18 = BigInt.fromI32(18)

let FACTORY_ADDRESS = '0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73'

// Stablecoins
let USDT_ADDRESS = '0x55d398326f99059ff775485246999027b3197955'
let BUSD_ADDRESS = '0xe9e7cea3dedca5984780bafc599bd69add087d56'
let USDC_ADDRESS = '0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d'
let USD1_ADDRESS = '0x8d0d000ee44948fc98c9b98a4fa4921476f08b0d'
let USDS_ADDRESS = '0xce24439f2d9c6a2289f741120fe202248b666666'
let WBNB_ADDRESS = '0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c'

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

// Handle Sync event - updates reserves
export function handleSync(event: Sync): void {
  let pair = Pair.load(event.address.toHexString())
  if (pair === null) {
    log.warning('Pair not found: {}', [event.address.toHexString()])
    return
  }

  let token0 = Token.load(pair.token0)
  let token1 = Token.load(pair.token1)
  if (token0 === null || token1 === null) {
    return
  }

  // Update reserves
  pair.reserve0 = convertTokenToDecimal(event.params.reserve0, token0.decimals)
  pair.reserve1 = convertTokenToDecimal(event.params.reserve1, token1.decimals)

  // Calculate prices
  if (pair.reserve1.notEqual(ZERO_BD)) {
    pair.token0Price = pair.reserve0.div(pair.reserve1)
  }
  if (pair.reserve0.notEqual(ZERO_BD)) {
    pair.token1Price = pair.reserve1.div(pair.reserve0)
  }

  // Update sync tracking
  pair.syncCount = pair.syncCount.plus(ONE_BI)
  pair.lastSyncTimestamp = event.block.timestamp
  pair.lastSyncBlock = event.block.number

  // Calculate USD values
  let bundle = Bundle.load('1')
  if (bundle !== null) {
    // Check if either token is a stablecoin
    let token0Address = token0.id.toLowerCase()
    let token1Address = token1.id.toLowerCase()
    
    if (token0Address == USDT_ADDRESS || token0Address == BUSD_ADDRESS || token0Address == USDC_ADDRESS || token0Address == USD1_ADDRESS || token0Address == USDS_ADDRESS) {
      pair.reserveUSD = pair.reserve0.times(BigDecimal.fromString('2'))
      token1.derivedUSD = pair.token1Price
    } else if (token1Address == USDT_ADDRESS || token1Address == BUSD_ADDRESS || token1Address == USDC_ADDRESS || token1Address == USD1_ADDRESS || token1Address == USDS_ADDRESS) {
      pair.reserveUSD = pair.reserve1.times(BigDecimal.fromString('2'))
      token0.derivedUSD = pair.token0Price
    } else if (token0Address == WBNB_ADDRESS && bundle.bnbPrice.gt(ZERO_BD)) {
      pair.reserveUSD = pair.reserve0.times(bundle.bnbPrice).times(BigDecimal.fromString('2'))
      token1.derivedBNB = pair.token1Price
      token1.derivedUSD = token1.derivedBNB.times(bundle.bnbPrice)
    } else if (token1Address == WBNB_ADDRESS && bundle.bnbPrice.gt(ZERO_BD)) {
      pair.reserveUSD = pair.reserve1.times(bundle.bnbPrice).times(BigDecimal.fromString('2'))
      token0.derivedBNB = pair.token0Price
      token0.derivedUSD = token0.derivedBNB.times(bundle.bnbPrice)
    }

    // Update BNB price if this is WBNB/stablecoin pair
    if (token0Address == WBNB_ADDRESS && 
        (token1Address == USDT_ADDRESS || token1Address == BUSD_ADDRESS || token1Address == USDC_ADDRESS || token1Address == USD1_ADDRESS || token1Address == USDS_ADDRESS)) {
      bundle.bnbPrice = pair.token1Price
      bundle.save()
    } else if (token1Address == WBNB_ADDRESS && 
        (token0Address == USDT_ADDRESS || token0Address == BUSD_ADDRESS || token0Address == USDC_ADDRESS || token0Address == USD1_ADDRESS || token0Address == USDS_ADDRESS)) {
      bundle.bnbPrice = pair.token0Price
      bundle.save()
    }

    token0.save()
    token1.save()
  }

  pair.save()

  // Save sync entity
  let syncId = event.transaction.hash.toHexString() + '-' + event.logIndex.toString()
  let sync = new SyncEntity(syncId)
  sync.pair = pair.id
  sync.reserve0 = pair.reserve0
  sync.reserve1 = pair.reserve1
  sync.timestamp = event.block.timestamp
  sync.blockNumber = event.block.number
  sync.save()
}

// Handle Swap event
export function handleSwap(event: SwapEvent): void {
  let pair = Pair.load(event.address.toHexString())
  if (pair === null) {
    return
  }

  let token0 = Token.load(pair.token0)
  let token1 = Token.load(pair.token1)
  if (token0 === null || token1 === null) {
    return
  }

  // Convert amounts
  let amount0In = convertTokenToDecimal(event.params.amount0In, token0.decimals)
  let amount1In = convertTokenToDecimal(event.params.amount1In, token1.decimals)
  let amount0Out = convertTokenToDecimal(event.params.amount0Out, token0.decimals)
  let amount1Out = convertTokenToDecimal(event.params.amount1Out, token1.decimals)

  // Calculate USD amount
  let amountUSD = ZERO_BD
  let bundle = Bundle.load('1')
  if (bundle !== null) {
    let token0Address = token0.id.toLowerCase()
    let token1Address = token1.id.toLowerCase()
    
    if (token0Address == USDT_ADDRESS || token0Address == BUSD_ADDRESS || token0Address == USDC_ADDRESS) {
      amountUSD = amount0In.plus(amount0Out)
    } else if (token1Address == USDT_ADDRESS || token1Address == BUSD_ADDRESS || token1Address == USDC_ADDRESS) {
      amountUSD = amount1In.plus(amount1Out)
    } else if (token0.derivedUSD.gt(ZERO_BD)) {
      amountUSD = amount0In.plus(amount0Out).times(token0.derivedUSD)
    } else if (token1.derivedUSD.gt(ZERO_BD)) {
      amountUSD = amount1In.plus(amount1Out).times(token1.derivedUSD)
    }
  }

  // Update pair volume
  pair.volumeToken0 = pair.volumeToken0.plus(amount0In).plus(amount0Out)
  pair.volumeToken1 = pair.volumeToken1.plus(amount1In).plus(amount1Out)
  pair.volumeUSD = pair.volumeUSD.plus(amountUSD)
  pair.txCount = pair.txCount.plus(ONE_BI)
  pair.save()

  // Update token volumes
  token0.tradeVolume = token0.tradeVolume.plus(amount0In).plus(amount0Out)
  token0.tradeVolumeUSD = token0.tradeVolumeUSD.plus(amountUSD)
  token0.txCount = token0.txCount.plus(ONE_BI)
  token0.save()

  token1.tradeVolume = token1.tradeVolume.plus(amount1In).plus(amount1Out)
  token1.tradeVolumeUSD = token1.tradeVolumeUSD.plus(amountUSD)
  token1.txCount = token1.txCount.plus(ONE_BI)
  token1.save()

  // Update factory
  let factory = PancakeFactory.load(FACTORY_ADDRESS)
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
  let swap = new Swap(swapId)
  swap.transaction = transaction.id
  swap.timestamp = event.block.timestamp
  swap.pair = pair.id
  swap.sender = event.params.sender
  swap.from = event.transaction.from
  swap.to = event.params.to
  swap.amount0In = amount0In
  swap.amount1In = amount1In
  swap.amount0Out = amount0Out
  swap.amount1Out = amount1Out
  swap.amountUSD = amountUSD
  swap.logIndex = event.logIndex
  swap.save()
}
