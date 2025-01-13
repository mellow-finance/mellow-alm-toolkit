from decimal import Decimal, getcontext
import math

getcontext().prec = 50
DECIMAL_ZERO = Decimal(0)
DECIMAL_ONE = Decimal(1)
Q96 = Decimal('79228162514264337593543950336')
base = Decimal(1.0001)
base_log = base.log10()

def tick_to_sqrtPrice(tick) -> Decimal:
    return base ** Decimal(tick/2)

def sqrtPrice_to_tick(sqrtPrice: Decimal) -> int:
    result = 2 * sqrtPrice.log10() / base_log
    return result.to_integral_value(rounding='ROUND_FLOOR')

def sqrtPrice_to_tick_prec(sqrtPrice: Decimal) -> float:
    return 2 * sqrtPrice.log10() / base_log

# returns cross of [x, y] = [X,Y] and [a,b]
def get_cross_ranges(X: Decimal, Y: Decimal, a: Decimal, b: Decimal):
    if b < a:
        a, b = b, a
    if Y < X:
        X, Y = Y, X
    return max(X, a), min(Y, b)

# returns (y-x)/(Y-X)
def ranges_ration(x: Decimal, y: Decimal, X: Decimal, Y: Decimal):
    if y > x:
        return (y-x)/(Y-X)
    
    return DECIMAL_ZERO

# returns cross of (y-x)/(Y-X), where [x, y] = [X,Y] and [a,b]
def get_cross_ranges_ration(X: Decimal, Y: Decimal, a: Decimal, b: Decimal):
    x = max(X, a)
    y = min(Y, b)

    if y > x:
        return (y-x)/(Y-X)
    
    return DECIMAL_ZERO

def calc_amounts(liquidity: Decimal, sqrtPrice: Decimal, sqrtPriceLower: Decimal, sqrtPriceUpper: Decimal):
    am0, am1 = DECIMAL_ZERO, DECIMAL_ZERO
    if sqrtPrice >= sqrtPriceLower and sqrtPrice < sqrtPriceUpper:
        am0 = (DECIMAL_ONE/sqrtPrice - DECIMAL_ONE/sqrtPriceUpper)
        am1 = (sqrtPrice - sqrtPriceLower)
    elif sqrtPrice > sqrtPriceUpper:
        am1 = (sqrtPriceUpper - sqrtPriceLower)
    elif sqrtPrice < sqrtPriceLower:
        am0 = (DECIMAL_ONE/sqrtPriceLower - DECIMAL_ONE/sqrtPriceUpper)

    am0, am1 = liquidity * am0, liquidity * am1

    return am0, am1


def calc_liquidity(am0, am1, sqrtPrice, sqrtPriceLower, sqrtPriceUpper: Decimal) -> Decimal:
    if sqrtPrice < sqrtPriceLower:
        # 1/(1.0001^-198300/2)-1/(1.0001^-194300/2) 269608685
        # 1/(1.0001^-200000/2)-1/(1.0001^-196000/2) 319565766
        return am0 / (DECIMAL_ONE/sqrtPriceLower - DECIMAL_ONE/sqrtPriceUpper)
    elif sqrtPrice >= sqrtPriceUpper:
        # (1.0001^-194300/2)-(1.0001^-198300/2) 6.0134678e-10
        # (1.0001^-200000/2)-(1.0001^-196000/2) 5.0733943e-10
        return am1 / (sqrtPriceUpper - sqrtPriceLower)
    else:
        liquidity0 = am0 / (DECIMAL_ONE/sqrtPrice - DECIMAL_ONE/sqrtPriceUpper)
        liquidity1 = am1 / (sqrtPrice - sqrtPriceLower)
        return min(liquidity0, liquidity1)

def recalc_in_tokens(am0, am1, sqrtPrice: Decimal):
    price = sqrtPrice * sqrtPrice
    return am0 + am1 / price, am0 * price + am1

def calc_fee(sqrtPriceLower, sqrtPriceUpper: int, liquidity: Decimal, sqrtPrice0, sqrtPrice1 : Decimal, fee):

    am0Before, am1Before = calc_amounts(liquidity, sqrtPrice0, sqrtPriceLower, sqrtPriceUpper)
    am0After, am1After = calc_amounts(liquidity, sqrtPrice1, sqrtPriceLower, sqrtPriceUpper)

    fee0, fee1 = Decimal(0), Decimal(0)

    if am0After > am0Before:
        fee0 = (am0After-am0Before) * fee

    if am1After > am1Before:
        fee1 = (am1After-am1Before) * fee
    
    return fee0, fee1

def calc_centered(sqrtPrice, tickSpacing, width):
    tick = int(sqrtPrice_to_tick(sqrtPrice))
    tick = (tick // tickSpacing) * tickSpacing

    if tick < 0:
        tick -= tickSpacing
    if (width // tickSpacing) % 2 == 0:
        return int(tick-width/2), int(tick+width/2)
    else:
        tick += tickSpacing / 2
        return int(tick-width/2), int(tick+width/2)

def calc_near(sqrtPrice, tickSpacing, width, tickLower, tickUpper):
    sqrtPriceLower, sqrtPriceUpper = tick_to_sqrtPrice(tickLower), tick_to_sqrtPrice(tickUpper)
    tick = sqrtPrice_to_tick(sqrtPrice)
    tickNear = (tick // tickSpacing) * tickSpacing

    if tickNear < 0:
        tickNear -= tickSpacing

    if sqrtPrice < sqrtPriceLower:
        tickLower = tickNear + tickSpacing
        tickUpper = tickLower + width
    elif sqrtPrice >= sqrtPriceUpper:
        tickUpper = tickNear
        tickLower = tickUpper - width
    return tickLower, tickUpper

def fit_amounts_for_position(am0: Decimal, am1: Decimal, sqrtPrice: Decimal, sqrtPriceLower: Decimal, sqrtPriceUpper: Decimal, fee: Decimal):
    price = sqrtPrice*sqrtPrice
    am0Input, am1Input = am0, am1
    swap_impact = Decimal(1) - fee

    if sqrtPrice < sqrtPriceLower:
        return am0 + swap_impact * am1/price, Decimal(0)
    
    if sqrtPrice > sqrtPriceUpper:
        return Decimal(0), swap_impact * am0 * price + am1

    while True:
        capital = am0*price + am1

        liquidity = calc_liquidity(am0, am1, sqrtPrice, sqrtPriceLower, sqrtPriceUpper)
        am0F, am1F = calc_amounts(liquidity, sqrtPrice, sqrtPriceLower, sqrtPriceUpper)
        dam0, dam1 = (am0-am0F), (am1-am1F)

        capitalL, capitalR = dam0*price/capital, dam1/capital # capital of remains tokens
        if capitalL > capitalR: # swap half of left remaining amount
            am0 -= dam0/2
            am1 += (dam0*price)/2
        else:
            am1 -= dam1/2
            am0 += (dam1/price)/2

        if (math.fabs(dam0*price) + math.fabs(dam1))/float(capital) < 0.0001:
            break

    if am0 > am0Input:
        am0, am1 = am0 - (am0-am0Input)*fee, am1
    elif am1 > am1Input:
        am0, am1 = am0, am1 - (am1-am1Input)*fee

    return am0, am1
        

class Position:
    def __init__(self, tickLower, tickUpper, liquidity, fee):
        self.__swap_fee = fee
        self.__liquidity = liquidity
        self.__tickLower = tickLower
        self.__tickUpper = tickUpper
        self.__sqrtPriceLower = tick_to_sqrtPrice(tickLower)
        self.__sqrtPriceUpper = tick_to_sqrtPrice(tickUpper)

    def ticks(self):
        return self.__tickLower, self.__tickUpper
    
    def liquidity(self):
        return self.__liquidity

    def calc_amounts(self, sqrtPrice: Decimal):
        return calc_amounts(self.__liquidity, sqrtPrice, self.__sqrtPriceLower, self.__sqrtPriceUpper)
    
    def calc_liquidity(self, am0, am1, sqrtPrice: Decimal) -> Decimal:
        return calc_liquidity(am0, am1, sqrtPrice, self.__sqrtPriceLower, self.__sqrtPriceUpper)
    
    # decrease liquidity of position and returns removed amounts
    def decrease_liquidity(self, liquidity_delta: Decimal, sqrtPrice: Decimal):
        if liquidity_delta > self.__liquidity:
            liquidity_delta = self.__liquidity
        
        am0Before, am1Before = self.calc_amounts(sqrtPrice)
        self.__liquidity -= liquidity_delta
        am0After, am1After = self.calc_amounts(sqrtPrice)

        return am0Before-am0After, am1Before-am1After

    # increase liquidity: takes as much as possible from am0, am1 (perform swap) and returns remaining unused amounts
    def increase_liquidity(self, am0Delta, am1Delta, sqrtPrice: Decimal):
        if am0Delta < DECIMAL_ONE and am1Delta < DECIMAL_ONE:
            return am0Delta, am1Delta

        # rebalance amount to get maximum liquidity
        am0Before, am1Before = fit_amounts_for_position(am0Delta, am1Delta, sqrtPrice, self.__sqrtPriceLower, self.__sqrtPriceUpper, self.__swap_fee)
        liquidity_delta = self.calc_liquidity(am0Before, am1Before, sqrtPrice)
        am0After, am1After = calc_amounts(liquidity_delta, sqrtPrice, self.__sqrtPriceLower, self.__sqrtPriceUpper)
        
        self.__liquidity += liquidity_delta

        am0DeltaActual, am1DeltaActual = am0Before-am0After, am1Before-am1After

        # TODO: return only positive, because a part was swapped
        return am0DeltaActual, am1DeltaActual
    
    def calc_fee(self, sqrtPrice0: Decimal, sqrtPrice1: Decimal):
        return calc_fee(self.__sqrtPriceLower, self.__sqrtPriceUpper, self.__liquidity, sqrtPrice0, sqrtPrice1, self.__swap_fee)
    
# decrease src position liquidty and increase dst, returns remaining amounts
def move_liquidity(src: Position, dst: Position, share: Decimal, sqrtPrice: Decimal):
    liquidity = src.liquidity()
    if liquidity == DECIMAL_ZERO:
        #print("zero")
        return DECIMAL_ZERO, DECIMAL_ZERO
    
    liquidity_delta = liquidity * share
    am0, am1 = src.decrease_liquidity(liquidity_delta, sqrtPrice)

    return dst.increase_liquidity(am0, am1, sqrtPrice)