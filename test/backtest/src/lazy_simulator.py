import loader as L
import csv
import os
import math
from decimal import Decimal, getcontext
getcontext().prec = 50

import pandas as pd
import position as P
import oracle as O
import simulator as S
#from position import tick_to_sqrtPrice, sqrtPrice_to_tick, Q96

LIQUIDITY_UNIT = Decimal(1e9)

class LazySimulator(S.Simulator):
    def __init__(self, pool, sub_type, cool_down):
        super(LazySimulator, self).__init__(pool, sub_type, cool_down)
        
    def simulate(self, width, update):

        width *= self.loader.tickSpacing

        oracle = O.Oracle(100, 3600, 40 if self.tickSpacing > 10 else 5)

        if update:
            self.loader.loadSwaps()
        
        csvFileData = open(self.loader.getFilename("transactions")+".csv", 'r')
        data = pd.read_csv(csvFileData)

        csvWriter, csvFileResult = self.createCsvWriter(width)

        sqrtPrice = Decimal(data['sqrtPriceX96'].iloc[0])/P.Q96
        sqrtPriceLast = sqrtPrice

        tickLower, tickUpper = P.calc_centered(sqrtPrice, self.tickSpacing, width)
        sqrtPriceLower = P.tick_to_sqrtPrice(tickLower)
        sqrtPriceUpper = P.tick_to_sqrtPrice(tickUpper)

        liquidityInitial = Decimal(math.pow(10, (self.decimals0 + self.decimals1)/2))/(sqrtPriceUpper - sqrtPriceLower)
        self.position = P.Position(tickLower, tickUpper, liquidityInitial, self.fee)

        fee0, fee1 = Decimal(0), Decimal(0)
        am0Remain, am1Remain = Decimal(0), Decimal(0)
        timestampInit = int(L.BLOCK_DURATION[self.loader.chainId] * float( data['block'].iloc[0])/1000)
        lastTimestamp = timestampInit
        lastTimestampRebalance = timestampInit
        lastTimestampWrite = timestampInit
        activity = 0

        for index, row in data.iterrows():
            block = int(row['block'])
            sqrtPrice = Decimal(row['sqrtPriceX96'])/P.Q96

            blockTimestamp = int(L.BLOCK_DURATION[self.loader.chainId] * float(block)/1000)

            fee0Delta, fee1Delta = self.position.calc_fee(sqrtPriceLast, sqrtPrice)
            fee0, fee1 = fee0 + fee0Delta, fee1 + fee1Delta
            activity += (blockTimestamp - lastTimestamp) * P.get_cross_ranges_ratio(sqrtPriceLast, sqrtPrice, self.position.sqrtPriceLower(), self.position.sqrtPriceUpper())
            lastTimestamp = blockTimestamp
            sqrtPriceLast = sqrtPrice
            tick = P.sqrtPrice_to_tick(sqrtPrice)

            if blockTimestamp < lastTimestampRebalance + self.cool_down:
                continue
            lastTimestampRebalance = blockTimestamp

            # if there is the place to move position toward sqrtPrice
            if oracle.ensure_no_mev(tick, blockTimestamp):
                if (tick < tickLower-self.tickSpacing and self.sub_type == S.LAZY_DESCENDING) or \
                   (tick >= tickUpper+self.tickSpacing and self.sub_type == S.LAZY_ASCENDING) or \
                   ((tick < tickLower-self.tickSpacing or tick >= tickUpper+self.tickSpacing) and self.sub_type == S.LAZY_SYNCING):

                    tickLower, tickUpper = self.position.ticks()
                    tickLowerNew, tickUpperNew = P.calc_near(sqrtPrice, self.tickSpacing, width, tickLower, tickUpper)
                    sqrtPriceLower = P.tick_to_sqrtPrice(tickLowerNew)
                    sqrtPriceUpper = P.tick_to_sqrtPrice(tickUpperNew)

                    if (tickLowerNew != tickLower and tickUpperNew != tickUpper) and (sqrtPrice < sqrtPriceLower or sqrtPrice > sqrtPriceUpper):
                        # mint a new position
                        new_position = P.Position(tickLowerNew, tickUpperNew, Decimal(0), self.fee)
                        # move liquidity, it should be moved overall
                        am0Remain, am1Remain = P.move_liquidity(self.position, new_position, Decimal(1), sqrtPrice)
                        if am0Remain > Decimal(1e-10) or am1Remain > Decimal(1e-10):
                            print(am0Remain, am1Remain)
                        self.position = new_position

            if blockTimestamp > lastTimestampWrite + L.WRITE_PERIOD or index == len(data)-1:
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
                    float(activity/(blockTimestamp-timestampInit)) * 100
                    ])
                csvFileResult.flush()
                lastTimestampWrite = blockTimestamp
