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

        oracle = O.Oracle(100, 3600, 20)

        if update:
            self.loader.loadSwaps()
        
        csvFileData = open(self.loader.getFilename("transactions")+".csv", 'r')
        data = pd.read_csv(csvFileData)

        csvFileResult = open(self.loader.getFilename(L.LAZY_SYNCING + "/" + str(width)+"_result")+".csv", 'w')
        csvWriter = csv.writer(csvFileResult)
        csvWriter.writerow(['block', 'tick', 'tickLower', 'tickUpper', 'price', 'liquidity', 'amount0', 'amount1', 'fee0', 'fee1', 'cost0', 'cost1'])

        sqrtPrice = Decimal(data['sqrtPriceX96'].iloc[0])/P.Q96
        sqrtPriceLast = sqrtPrice

        tickLower, tickUpper = P.calc_centered(sqrtPrice, self.tickSpacing, width)
        sqrtPriceLower = P.tick_to_sqrtPrice(tickLower)
        sqrtPriceUpper = P.tick_to_sqrtPrice(tickUpper)

        liquidityInitial = Decimal(math.pow(10, (self.decimals0 + self.decimals1)/2))/(sqrtPriceUpper - sqrtPriceLower)
        self.position = P.Position(tickLower, tickUpper, liquidityInitial, self.fee)

        fee0, fee1 = Decimal(0), Decimal(0)
        am0Remain, am1Remain = Decimal(0), Decimal(0)

        for index, row in data.iterrows():
            block = int(row['block'])
            block_timestamp = int(L.BLOCK_DURATION[self.loader.chainId] * float(block)/1000)
            sqrtPrice = Decimal(row['sqrtPriceX96'])/P.Q96

            tick = P.sqrtPrice_to_tick(sqrtPrice)

            fee0Delta, fee1Delta = self.position.calc_fee(sqrtPriceLast, sqrtPrice)
            fee0, fee1 = fee0 + fee0Delta, fee1 + fee1Delta

            # if there is the place to move position toward sqrtPrice
            if oracle.ensure_no_mev(tick, block_timestamp) and (tick < tickLower-self.tickSpacing or tick >= tickUpper+self.tickSpacing):

                tickLower, tickUpper = self.position.ticks()
                tickLowerNew, tickUpperNew = P.calc_near(sqrtPrice, self.tickSpacing, width, tickLower, tickUpper)

                if tickLowerNew != tickLower and tickUpperNew != tickUpper:
                    # mint a new position
                    new_position = P.Position(tickLowerNew, tickUpperNew, Decimal(0), self.fee)
                    # move liquidity, it should be moved overall
                    am0Remain, am1Remain = P.move_liquidity(self.position, new_position, Decimal(1), sqrtPrice)
                    if am0Remain > Decimal(1e-10) or am1Remain > Decimal(1e-10):
                        print(am0Remain, am1Remain)
                    self.position = new_position

            sqrtPriceLast = sqrtPrice

            if index % L.BLOCK_WRITE_INTERVAL[self.loader.chainId] == 0:
                am0, am1 = self.position.calc_amounts(sqrtPrice)

                am0Total, am1Total = P.recalc_in_tokens(am0+fee0, am1+fee1, sqrtPrice)
                
                liquidity = self.position.liquidity()

                shift_decimals = math.pow(10, self.decimals0 - self.decimals1)
                csvWriter.writerow([
                    block, tick,
                    tickLower, tickUpper, 
                    float(sqrtPrice*sqrtPrice) * shift_decimals,
                    float(liquidity), 
                    float(am0) / 10 ** self.decimals0, float(am1) / 10 ** self.decimals1, 
                    float(fee0)/ 10 ** self.decimals0, float(fee1)/ 10 ** self.decimals1,
                    float(am0Total) / 10 ** self.decimals0, float(am1Total) / 10 ** self.decimals1, 
                    ])
                csvFileResult.flush()
