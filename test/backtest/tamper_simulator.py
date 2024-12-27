import loader as L
import csv
import math
from decimal import Decimal, getcontext
getcontext().prec = 50

import pandas as pd
import position as P
import oracle as O
#from self.position import tick_to_sqrtPrice, sqrtPrice_to_tick, Q96

OPT_CHAIN_ID = '10'
BASE_CHAIN_ID = '8453'

BLOCK_WRITE_INTERVAL = {
    OPT_CHAIN_ID: 10000,
    BASE_CHAIN_ID: 10000
}

class TamperSimulator:
    def __init__(self, pool):
        self.loader = L.SwapLogLoader(pool)
        self.tickSpacing = self.loader.tickSpacing
        self.fee = Decimal(self.loader.fee)
        self.decimals0 = self.loader.decimals0
        self.decimals1 = self.loader.decimals1
        self.position = P.Position(self.loader.tickSpacing)
        
    def get_target(self, sqrtPrice, tickLower, tickUpper, width):
        half = width//2
        if tickLower == tickUpper:
            return self.position.calc_centered(sqrtPrice, half)
        else:
            sqrtPriceLower = P.tick_to_sqrtPrice(tickLower)
            sqrtPriceUpper = P.tick_to_sqrtPrice(tickUpper)

            if sqrtPrice > sqrtPriceLower and sqrtPrice < sqrtPriceUpper: # in range
                return tickLower, tickUpper
            elif sqrtPrice < sqrtPriceLower:
                return tickLower-half, tickUpper-half
            elif sqrtPrice > sqrtPriceUpper:
                return tickLower+half, tickUpper+half
            
    def get_left(self, tickLower, tickUpper, width):
        half = width/2
        return tickLower-half, tickUpper-half
    
    def get_right(self, tickLower, tickUpper, width):
        half = width/2
        return tickLower+half, tickUpper+half
    
    def get_liquidity_ratio(self, sqrtPrice, sqrtPriceLower, sqrtPriceUpper):
        half = (sqrtPriceUpper-sqrtPriceLower)/2

        l = Decimal(1) - (sqrtPrice-sqrtPriceLower)/half

        if l < Decimal(0):
            l = Decimal(0)
        elif l > Decimal(1):
            l = Decimal(1)

        return l
    
    def calc_amounts(self, liquidity, sqrtPrice, sqrtPriceLower, sqrtPriceUpper):

        half = (sqrtPriceUpper-sqrtPriceLower)/2
        l = self.get_liquidity_ratio(sqrtPrice, sqrtPriceLower, sqrtPriceUpper)
        r = Decimal(1) - l
        
        am0HoldL, am1HoldL, am0L, am1L = self.position.calc_amounts(liquidity * l, sqrtPrice, sqrtPriceLower-half, sqrtPriceUpper-half)
        am0HoldR, am1HoldR, am0R, am1R = self.position.calc_amounts(liquidity * r, sqrtPrice, sqrtPriceLower+half, sqrtPriceUpper+half)

        return am0HoldL+am0HoldR, am1HoldL+am1HoldR, am0L+am0R, am1L+am1R
    
    def calc_liquidity(self, am0, am1, sqrtPrice, sqrtPriceLower, sqrtPriceUpper):
        half = (sqrtPriceUpper-sqrtPriceLower)/2

        liquidityL = self.position.calc_liquidity(am0, am1, sqrtPrice, sqrtPriceLower-half, sqrtPriceUpper-half)
        liquidityR = self.position.calc_liquidity(am0, am1, sqrtPrice, sqrtPriceLower+half, sqrtPriceUpper+half)

        return (liquidityL + liquidityR)
    
    def get_width_ratio(self, tickLower, tickUpper):
        half = (tickUpper-tickLower)/2
        sqrtPriceLowerL = P.tick_to_sqrtPrice(tickLower-half)
        sqrtPriceUpperL = P.tick_to_sqrtPrice(tickUpper-half)
        sqrtPriceLowerR = P.tick_to_sqrtPrice(tickLower+half)
        sqrtPriceUpperR = P.tick_to_sqrtPrice(tickUpper+half)

        return (sqrtPriceUpperL-sqrtPriceLowerL)/(sqrtPriceUpperR-sqrtPriceLowerR)
    
   #def get_swap_share(self, sqrtPrice, sqrtPriceLower, sqrtPriceUpper, to_left):
   #    half = (sqrtPriceUpper-sqrtPriceLower)/3
   #    share = Decimal(0)
   #    if to_left:
   #        share = ()#((sqrtPriceUpper-sqrtPrice) - (sqrtPriceUpper-sqrtPrice-half))/half
   #    else:
   #        share = ((sqrtPrice-sqrtPriceLower) - (sqrtPrice-sqrtPriceLower-half))/half


    def simulate(self, width, update):
        oracle = O.Oracle(100, 3600, 20)

        if update:
            self.loader.loadSwaps()
        
        csvFileData = open(self.loader.getFilename("transactions")+".csv", 'r')
        data = pd.read_csv(csvFileData)

        csvFileResult = open(self.loader.getFilename(str(width)+"_result")+".csv", 'w')
        csvWriter = csv.writer(csvFileResult)
        csvWriter.writerow(['block',  'tickLower', 'tickUpper', 'tick', 'price', 'liquidity', 'amount0', 'amount1', 'fee0', 'fee1', 'IL0', 'IL1', 'IL0_with_fee', 'IL1_with_fee'])

        sqrtPrice = Decimal(data['sqrtPriceX96'].iloc[0])/P.Q96
        sqrtPriceLast = sqrtPrice

        tickLower, tickUpper = self.get_target(sqrtPrice, 0, 0, width)
        sqrtPriceLower = P.tick_to_sqrtPrice(tickLower)
        sqrtPriceUpper = P.tick_to_sqrtPrice(tickUpper)

        liquidity = Decimal(math.pow(10, (self.decimals0 + self.decimals1)/2))/(sqrtPriceUpper - sqrtPriceLower)
        am0Hold, am1Hold, am0, am1 = self.calc_amounts(liquidity, sqrtPrice, sqrtPriceLower, sqrtPriceUpper)
        ratioL = self.get_liquidity_ratio(sqrtPrice, sqrtPriceLower, sqrtPriceUpper)
        fee_liquidity = Decimal(0)

        for index, row in data.iterrows():
            block = int(row['block'])
            sqrtPrice = Decimal(row['sqrtPriceX96'])/P.Q96

            tick = P.sqrtPrice_to_tick(sqrtPrice)

            tickLowerTarget, tickUpperTarget = self.get_target(sqrtPrice, tickLower, tickUpper, width)

            if oracle.ensure_no_mev(tick):

                ratioLTarget = self.get_liquidity_ratio(sqrtPrice, sqrtPriceLower, sqrtPriceUpper)
                ratio_deviation = ratioLTarget-ratioL

                if tickLowerTarget == tickLower and tickUpperTarget == tickUpper and math.fabs(ratio_deviation) > Decimal(0.05):
                    ratio_width = self.get_width_ratio(tickLower, tickUpper)
                    liquidityDelta = Decimal(math.fabs(liquidity * ratio_deviation)/2) # moving liquidity
                    liquidity -= liquidityDelta
                    if ratio_deviation > 0: # to the left, more narrow range
                        liquidityDelta = liquidityDelta * ratio_width - liquidityDelta * self.fee
                    else: # to the right, more wide range
                        liquidityDelta = liquidityDelta / ratio_width - liquidityDelta * self.fee
                    liquidity += liquidityDelta

                if tickLowerTarget != tickLower and tickUpperTarget != tickUpper:
                    
                    ratio_width = self.get_width_ratio(tickLower, tickUpper)

                    if tickLowerTarget < tickLower: # move al liquidity to the left
                        liquidityDelta = Decimal(math.fabs(liquidity * (Decimal(1)-ratioL))/2) # moving liquidity
                        liquidity -= liquidityDelta
                        liquidityDelta = liquidityDelta * ratio_width - liquidityDelta * self.fee
                    elif tickUpperTarget > tickUpper:
                        liquidityDelta = Decimal(math.fabs(liquidity * ratioL)/2) # moving liquidity
                        liquidity -= liquidityDelta
                        liquidityDelta = liquidityDelta / ratio_width - liquidityDelta * self.fee
                    liquidity += liquidityDelta

                    sqrtPriceLower = P.tick_to_sqrtPrice(tickLowerTarget)
                    sqrtPriceUpper = P.tick_to_sqrtPrice(tickUpperTarget)
                    tickLower, tickUpper = tickLowerTarget, tickUpperTarget

                ratioL = ratioLTarget

            oracle.push(tick, int(L.BLOCK_DURATION[self.loader.chainId] * float(block)/1000))

            tickLowerL, tickUpperL = self.get_left(tickLower, tickUpper, width)
            sqrtPriceLowerL = P.tick_to_sqrtPrice(tickLowerL)
            sqrtPriceUpperL = P.tick_to_sqrtPrice(tickUpperL)
            x, y = P.get_cross_ranges(sqrtPriceLowerL, sqrtPriceUpperL, sqrtPrice, sqrtPriceLast)
            delta = P.get_cross_ranges_ration(sqrtPriceLowerL, sqrtPriceUpperL, x, y)
            fee_liquidity += delta * self.fee * liquidity

            tickLowerR, tickUpperR = self.get_left(tickLower, tickUpper, width)
            sqrtPriceLowerR = P.tick_to_sqrtPrice(tickLowerR)
            sqrtPriceUpperR = P.tick_to_sqrtPrice(tickUpperR)
            x, y = P.get_cross_ranges(sqrtPriceLowerR, sqrtPriceUpperR, sqrtPrice, sqrtPriceLast)
            delta = P.get_cross_ranges_ration(sqrtPriceLowerR, sqrtPriceUpperR, x, y)
            fee_liquidity += delta * self.fee * liquidity

            sqrtPriceLast = sqrtPrice

            if index % BLOCK_WRITE_INTERVAL[self.loader.chainId] == 0:
                am0, am1, _ ,_ = self.calc_amounts(liquidity, sqrtPrice, sqrtPriceLower, sqrtPriceUpper)

                fee0, fee1, _,_ = self.calc_amounts(fee_liquidity, sqrtPrice, sqrtPriceLower, sqrtPriceUpper)
                csvWriter.writerow([
                    block, 
                    tickLower, tickUpper, tick,
                    float(sqrtPrice*sqrtPrice), 
                    float(liquidity), 
                    float(am0) / 10 ** self.decimals0, float(am1) / 10 ** self.decimals1, 
                    float(fee0)/ 10 ** self.decimals0, float(fee1)/ 10 ** self.decimals1,
                    100 * float((am0-am0Hold)/am0Hold), 100 * float((am1-am1Hold)/am1Hold),
                    100 * float((am0-am0Hold+fee0)/am0Hold), 100 * float((am1-am1Hold+fee1)/am1Hold),
                    ])
                csvFileResult.flush()
                