import loader as L
import csv
import math
from decimal import Decimal, getcontext
getcontext().prec = 50

import pandas as pd
import position as P
import oracle as O

OPT_CHAIN_ID = '10'
BASE_CHAIN_ID = '8453'

class TamperSimulator:
    def __init__(self, pool):
        self.loader = L.SwapLogLoader(pool)
        self.tickSpacing = self.loader.tickSpacing
        self.fee = Decimal(self.loader.fee)
        self.decimals0 = self.loader.decimals0
        self.decimals1 = self.loader.decimals1

        self.pos_left = None
        self.pos_right = None
        
    # return [tickLower, tickUpper] of position aligned with half of position width
    # center of [tickLower, tickUpper] is close as possible to the spot tick
    def get_target(self, sqrtPrice, tickLower, tickUpper, width):
        half = width//2
        if tickLower == tickUpper:
            return P.calc_centered(sqrtPrice, self.tickSpacing, width)
        else:
            sqrtPriceLower = P.tick_to_sqrtPrice(tickLower)
            sqrtPriceUpper = P.tick_to_sqrtPrice(tickUpper)

            if sqrtPrice > sqrtPriceLower and sqrtPrice < sqrtPriceUpper: # in range
                return tickLower, tickUpper
            elif sqrtPrice < sqrtPriceLower:
                return tickLower-half, tickUpper-half
            elif sqrtPrice > sqrtPriceUpper:
                return tickLower+half, tickUpper+half
            
    def get_left(self, pos: P.Position, width):
        shift = width//2
        tickLower, tickUpper = pos.ticks()
        return tickLower-shift, tickUpper-shift
    
    def get_right(self, pos: P.Position, width):
        shift = width//2
        tickLower, tickUpper = pos.ticks()
        return tickLower+shift, tickUpper+shift
    
    def get_liquidity_ratio(self):
        liquidityL = self.pos_left.liquidity()
        liquidityR = self.pos_right.liquidity()
        return liquidityL/(liquidityL+liquidityR)

    def get_liquidity_ratio_target(self, sqrtPrice, tickLower, tickUpper):
        half = (tickUpper-tickLower)//2

        l = Decimal(1) - (P.sqrtPrice_to_tick_prec(sqrtPrice)-Decimal(tickLower))/Decimal(half)

        if l < Decimal(0):
            l = Decimal(0)
        elif l > Decimal(1):
            l = Decimal(1)

        return l

    def get_width_ratio(self, tickLower, tickUpper):
        half = (tickUpper-tickLower)/2
        sqrtPriceLowerL = P.tick_to_sqrtPrice(tickLower-half)
        sqrtPriceUpperL = P.tick_to_sqrtPrice(tickUpper-half)
        sqrtPriceLowerR = P.tick_to_sqrtPrice(tickLower+half)
        sqrtPriceUpperR = P.tick_to_sqrtPrice(tickUpper+half)

        return (sqrtPriceUpperL-sqrtPriceLowerL)/(sqrtPriceUpperR-sqrtPriceLowerR)
    
    def get_target_token_ratio(self, sqrtPrice, tickLower, tickUpper):
        sqrtPriceLower = P.tick_to_sqrtPrice(tickLower)
        sqrtPriceUpper = P.tick_to_sqrtPrice(tickUpper)

        if sqrtPrice > sqrtPriceUpper:
            return Decimal(0), Decimal(1)
        elif sqrtPrice < sqrtPriceLower:
            return Decimal(1), Decimal(0)
        else:
            w = sqrtPriceUpper-sqrtPriceLower
            return (sqrtPriceUpper-sqrtPrice)/w, (sqrtPrice-sqrtPriceLower)/w,

    def simulate(self, width, update):
        oracle = O.Oracle(100, 3600, 20)

        if update:
            self.loader.loadSwaps()
        
        csvFileData = open(self.loader.getFilename("transactions")+".csv", 'r')
        data = pd.read_csv(csvFileData)

        csvFileResult = open(self.loader.getFilename(L.TAMPER + "/" + str(width)+"_result")+".csv", 'w')
        csvWriter = csv.writer(csvFileResult)
        csvWriter.writerow(['block', 'tick', 'tickLower', 'tickUpper', 'price', 'liquidity', 'amount0', 'amount1', 'fee0', 'fee1', 'cost0', 'cost1'])

        sqrtPrice = Decimal(data['sqrtPriceX96'].iloc[0])/P.Q96
        sqrtPriceLast = sqrtPrice

        tickLower, tickUpper = self.get_target(sqrtPrice, 0, 0, width)
        sqrtPriceLower = P.tick_to_sqrtPrice(tickLower)
        sqrtPriceUpper = P.tick_to_sqrtPrice(tickUpper)

        liquidityInitial = Decimal(math.pow(10, (self.decimals0 + self.decimals1)/2))/(sqrtPriceUpper - sqrtPriceLower)

        self.pos_left = P.Position(tickLower, tickUpper, liquidityInitial/2, self.fee)
        lower, upper = self.get_right(self.pos_left, width)
        self.pos_right = P.Position(lower, upper, liquidityInitial/2, self.fee)

        am0Hold, am1Hold = Decimal(0), Decimal(0)
        fee0, fee1 = Decimal(0), Decimal(0)
        am0Remain, am1Remain = Decimal(0), Decimal(0)

        for index, row in data.iterrows():
            block = int(row['block'])
            block_timestamp = int(L.BLOCK_DURATION[self.loader.chainId] * float(block)/1000)
            sqrtPrice = Decimal(row['sqrtPriceX96'])/P.Q96

            tick = P.sqrtPrice_to_tick(sqrtPrice)

            fee0L, fee1L = self.pos_left.calc_fee(sqrtPriceLast, sqrtPrice)
            fee0R, fee1R = self.pos_right.calc_fee(sqrtPriceLast, sqrtPrice)
            fee0, fee1 = fee0 + fee0L + fee0R, fee1 + fee1L + fee1R # total collected fee in token0 and token1

            tickLowerTarget, tickUpperTarget = self.get_target(sqrtPrice, tickLower, tickUpper, width)

            if oracle.ensure_no_mev(tick, block_timestamp):

                ratioL = self.get_liquidity_ratio()
                ratioR = Decimal(1)-ratioL
                ratioLTarget = self.get_liquidity_ratio_target(sqrtPrice, tickLower, tickUpper)

                ratio_deviation = ratioLTarget-ratioL
                am0r, am1r = Decimal(0), Decimal(0)

                if tickLowerTarget == tickLower and tickUpperTarget == tickUpper and math.fabs(ratio_deviation) > Decimal(0.05):
                    if ratio_deviation > 0: # to the left
                        am0r, am1r = P.move_liquidity(self.pos_right, self.pos_left, +ratio_deviation/ratioR, sqrtPrice)
                    else: # to the right
                        am0r, am1r = P.move_liquidity(self.pos_left, self.pos_right, -ratio_deviation/ratioL, sqrtPrice)

                if tickLowerTarget != tickLower and tickUpperTarget != tickUpper:

                    if tickLowerTarget < tickLower: # move all liquidity to the left
                        # new left position
                        lower, upper = self.get_left(self.pos_left, width)
                        new_left = P.Position(lower, upper, Decimal(0), self.fee)
                        # move all from right to the new left
                        am0r, am1r = P.move_liquidity(self.pos_right, new_left, Decimal(1), sqrtPrice)
                        # try to use remain unused blances
                        am0Remain, am1Remain = new_left.increase_liquidity(am0Remain, am1Remain, sqrtPrice)
                        self.pos_left, self.pos_right = new_left, self.pos_left
                    elif tickUpperTarget > tickUpper:
                        lower, upper = self.get_right(self.pos_right, width)
                        new_right = P.Position(lower, upper, Decimal(0), self.fee)
                        # move all from left to the new right
                        am0r, am1r = P.move_liquidity(self.pos_left, new_right, Decimal(1), sqrtPrice)
                        # try to use remain unused blances
                        am0Remain, am1Remain = new_right.increase_liquidity(am0Remain, am1Remain, sqrtPrice)
                        self.pos_left, self.pos_right = self.pos_right, new_right

                    sqrtPriceLower = P.tick_to_sqrtPrice(tickLowerTarget)
                    sqrtPriceUpper = P.tick_to_sqrtPrice(tickUpperTarget)
                    tickLower, tickUpper = tickLowerTarget, tickUpperTarget
                    
                am0Remain, am1Remain = am0Remain+am0r, am1Remain+am1r

            sqrtPriceLast = sqrtPrice

            if index % L.BLOCK_WRITE_INTERVAL[self.loader.chainId] == 0 or index == len(data)-1:

                am0L, am1L = self.pos_left.calc_amounts(sqrtPrice)
                am0R, am1R = self.pos_right.calc_amounts(sqrtPrice)
                am0, am1 = am0L+am0R+am0Remain, am1L+am1R+am1Remain
                am0Total, am1Total = P.recalc_in_tokens(am0+fee0, am1+fee1, sqrtPrice) # amounts recalculated in token0 and token1 at spot price

                liquidity = self.pos_left.liquidity()+self.pos_right.liquidity()
                
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
            