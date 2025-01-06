from decimal import Decimal, getcontext
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

class Position:
    def __init__(self, tickSpacing):
        self.tickSpacing = tickSpacing
        pass

    """
        calculate cost of position in amount of both tokens
        based on current spot price
    """
    def calc_amounts(self, liquidity: Decimal, sqrtPrice: Decimal, sqrtPriceLower: Decimal, sqrtPriceUpper: Decimal):
        am0, am1 = DECIMAL_ZERO, DECIMAL_ZERO
        if sqrtPrice >= sqrtPriceLower and sqrtPrice < sqrtPriceUpper:
            am0 = (DECIMAL_ONE/sqrtPrice - DECIMAL_ONE/sqrtPriceUpper)
            am1 = (sqrtPrice - sqrtPriceLower)
        elif sqrtPrice > sqrtPriceUpper:
            am1 = (sqrtPriceUpper - sqrtPriceLower)
        elif sqrtPrice < sqrtPriceLower:
            am0 = (DECIMAL_ONE/sqrtPriceLower - DECIMAL_ONE/sqrtPriceUpper)

        am0, am1 = liquidity * am0, liquidity * am1

        price = sqrtPrice * sqrtPrice
        am0Total = (am0 + am1 / price) #/ Decimal(10 ** self.decimals0)
        am1Total = (am0 * price + am1) #/ Decimal(10 ** self.decimals1)

        return am0Total, am1Total, am0, am1
    
    def calc_liquidity(self, am0, am1, sqrtPrice: Decimal, sqrtPriceLower: Decimal, sqrtPriceUpper: Decimal) -> Decimal:
        if sqrtPrice < sqrtPriceLower:
            # 1/(1.0001^-198300/2)-1/(1.0001^-194300/2) 269608685
            # 1/(1.0001^-200000/2)-1/(1.0001^-196000/2) 319565766
            return am0 / (DECIMAL_ONE/sqrtPriceLower - DECIMAL_ONE/sqrtPriceUpper)
        elif sqrtPrice >= sqrtPriceUpper:
            # (1.0001^-194300/2)-(1.0001^-198300/2) 6.0134678e-10
            # (1.0001^-200000/2)-(1.0001^-196000/2) 5.0733943e-10
            return am1 / (sqrtPriceUpper - sqrtPriceLower)
        else:
            liquidity0 = am0 / (DECIMAL_ONE/sqrtPriceLower - DECIMAL_ONE/sqrtPriceUpper)
            liquidity1 = am1 / (sqrtPriceUpper - sqrtPriceLower)
            return min(liquidity0, liquidity1)

    def calc_centered(self, sqrtPrice, width):
        tick = int(sqrtPrice_to_tick(sqrtPrice))
        tick = (tick // self.tickSpacing) * self.tickSpacing

        if tick < 0:
            tick -= self.tickSpacing
        if (width // self.tickSpacing) % 2 == 0:
            return int(tick-width/2), int(tick+width/2)
        else:
            tick += self.tickSpacing / 2
            return int(tick-width/2), int(tick+width/2)

    def calc_near(self, sqrtPrice, width, sqrtPriceLower, sqrtPriceUpper):
        tick = sqrtPrice_to_tick(sqrtPrice)
        tickNear = (tick // self.tickSpacing) * self.tickSpacing

        if tickNear < 0:
            tickNear -= self.tickSpacing

        if sqrtPrice < sqrtPriceLower:
            tickLower = tickNear + self.tickSpacing
            tickUpper = tickLower + width
        elif sqrtPrice >= sqrtPriceUpper:
            tickUpper = tickNear
            tickLower = tickUpper - width

        #print("calc_near", tick, tickNear, tickLower, tickUpper)
        
        return tickLower, tickUpper