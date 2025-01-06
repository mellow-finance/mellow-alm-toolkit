import loader as L
import csv
import math
from decimal import Decimal, getcontext
getcontext().prec = 50

import pandas as pd
import position as P
import oracle as O
#from position import tick_to_sqrtPrice, sqrtPrice_to_tick, Q96

LIQUIDITY_UNIT = Decimal(1e9)
OPT_CHAIN_ID = '10'
BASE_CHAIN_ID = '8453'


class LazySimulator:
    def __init__(self, pool):
        self.loader = L.SwapLogLoader(pool)
        self.tickSpacing = self.loader.tickSpacing
        self.fee = Decimal(self.loader.fee)
        self.decimals0 = self.loader.decimals0
        self.decimals1 = self.loader.decimals1
        
    def simulate(self, width, update):

        position = P.Position(self.loader.tickSpacing)
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

        # amounts token at the start
        #am0Hold, am1Hold = Decimal(10 ** self.decimals0), Decimal(10 ** self.decimals1)

        tickLower, tickUpper = position.calc_centered(sqrtPrice, width)
        sqrtPriceLower = P.tick_to_sqrtPrice(tickLower)
        sqrtPriceUpper = P.tick_to_sqrtPrice(tickUpper)

        liquidity = Decimal(math.pow(10, (self.decimals0 + self.decimals1)/2))/(sqrtPriceUpper - sqrtPriceLower)
        am0Hold, am1Hold,_,_ = position.calc_amounts(liquidity, sqrtPrice, sqrtPriceLower, sqrtPriceUpper)
        fee_liquidity = Decimal(0)

        for index, row in data.iterrows():
            block = int(row['block'])
            sqrtPrice = Decimal(row['sqrtPriceX96'])/P.Q96

            tick = P.sqrtPrice_to_tick(sqrtPrice)

            # if there is the place to move position toward sqrtPrice
            if (tick < tickLower-self.tickSpacing or tick >= tickUpper+self.tickSpacing) and oracle.ensure_no_mev(tick):

                _,_, am0, am1 = position.calc_amounts(liquidity, sqrtPrice, sqrtPriceLower, sqrtPriceUpper)

                tickLowerNew, tickUpperNew = position.calc_near(sqrtPrice, width, sqrtPriceLower, sqrtPriceUpper)

                if tickLowerNew != tickLower and tickUpperNew != tickUpper:

                    sqrtPriceLower = P.tick_to_sqrtPrice(tickLowerNew)
                    sqrtPriceUpper = P.tick_to_sqrtPrice(tickUpperNew)

                    liquidity = position.calc_liquidity(am0, am1, sqrtPrice, sqrtPriceLower, sqrtPriceUpper)

                    tickLower, tickUpper = tickLowerNew, tickUpperNew
            
            oracle.push(tick, int(L.BLOCK_DURATION[self.loader.chainId] * float(block)/1000))

            x, y = P.get_cross_ranges(sqrtPriceLower, sqrtPriceUpper, sqrtPrice, sqrtPriceLast)
            delta = P.get_cross_ranges_ration(sqrtPriceLower, sqrtPriceUpper, x, y)
            fee_liquidity += delta * self.fee * liquidity

            sqrtPriceLast = sqrtPrice

            if index % L.BLOCK_WRITE_INTERVAL[self.loader.chainId] == 0:
                am0, am1, _ ,_ = position.calc_amounts(liquidity, sqrtPrice, sqrtPriceLower, sqrtPriceUpper)

                fee0, fee1, _,_ = position.calc_amounts(fee_liquidity, sqrtPrice, sqrtPriceLower, sqrtPriceUpper)
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
