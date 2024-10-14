import json
import os
import csv
import time
import math
import pandas as pd
from web3 import Web3, HTTPProvider
from hexbytes import HexBytes
from dotenv import load_dotenv
from decimal import Decimal, getcontext
getcontext().prec = 50

Q96 = Decimal('79228162514264337593543950336')
base = Decimal(1.0001)
base_log = base.log10()

DECIMAL_ZERO = Decimal(0)
DECIMAL_ONE = Decimal(1)
SWAP_IMPACT = Decimal(0.01/100)
INFINITE_BLOCK = 10**20

def tick_to_sqrtPrice(tick) -> Decimal:
    return base ** Decimal(tick/2)

def sqrtPrice_to_tick(sqrtPrice: Decimal) -> int:
    result = 2 * sqrtPrice.log10() / base_log
    return result.to_integral_value(rounding='ROUND_FLOOR')

load_dotenv()
SWAP_TOPIC = '0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67'

WETH_USDC = "0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59" # WETH-USDC
WETH_USDT = "0x9785eF59E2b499fB741674ecf6fAF912Df7b3C1b" # WETH-USDT

# address -> init block
POOLS = {
    WETH_USDC: 13904084,
    WETH_USDT: 17538788,
}

OPT_CHAIN_ID = '10'
BASE_CHAIN_ID = '8453'

CHAIN_ID = BASE_CHAIN_ID

class SwapTransaction:
    def __init__(self, log):
        self.typeTransaction = 1
        self.txHash = log.transactionHash.hex()
        self.block = log.blockNumber*1000 + log.transactionIndex
        self.__extractData(log.data.hex())
        
    def __extractData(self, data):
        data = data[2:]
        amount0_bytes = bytes.fromhex(data[:64])
        amount1_bytes = bytes.fromhex(data[64:128])
        sqrtPriceX96_bytes = bytes.fromhex(data[128:192])
        liquidity_bytes = bytes.fromhex(data[192:256])

        self.liquidity = int.from_bytes(liquidity_bytes, byteorder='big', signed=False)
        self.sqrtPriceX96 = int.from_bytes(sqrtPriceX96_bytes, byteorder='big', signed=False)
        self.amount0 = int.from_bytes(amount0_bytes, byteorder='big', signed=True)
        self.amount1 = int.from_bytes(amount1_bytes, byteorder='big', signed=True)

    def toDict(self):
        return {key: (value.hex() if isinstance(value, HexBytes) else value) 
                for key, value in self.__dict__.items() if not key.startswith('_')}
    
class SwapLogLoader:
    def __init__(self, poolAddress):

        self.chainId = CHAIN_ID
        self.__readSettings()
        self.__connect()
        
        self.poolAddress = poolAddress
        self.startBlock = POOLS[poolAddress]
        self.endBlock = self.rpc.eth.block_number
        self.path = 'data/' + self.chainId + "/" + self.poolAddress + "/" 
        os.makedirs(self.path, exist_ok=True)
        self.part = 1
        with open(self.abiFile) as f:
            self.abiPool = json.load(f)
        self.__getTokenDecimals()

    def __getFilename(self, name):
        return self.path + name

    def __connect(self):
        self.rpc = Web3(HTTPProvider(self.rpcUrl))
        if self.rpc.is_connected():
            print("Connected async to chain %s node" % (self.chainId))
        else:
            print("Failed to connect to %s node" % (self.chainId))
            exit(1)

    def __readSettings(self):
        if CHAIN_ID==OPT_CHAIN_ID:
            self.rpcUrl = os.getenv('OPTIMISM_DRPC')
            self.logBatch = 20000
        elif CHAIN_ID==BASE_CHAIN_ID:
            self.rpcUrl = os.getenv('BASE_DRPC')
            self.logBatch = 20000

        self.abiErc20File = './abi/erc20.json'
        self.abiFile = "./abi/velodrom_abi.json"

    def __getTokenDecimals(self):
        with open(self.abiErc20File) as f:
            abiErc20 = json.load(f)
        self.poolContract = self.rpc.eth.contract(address=self.poolAddress, abi=self.abiPool)
        self.token0 = self.poolContract.functions.token0().call()
        self.token1 = self.poolContract.functions.token1().call()
        self.tickSpacing = self.poolContract.functions.tickSpacing().call()
        self.erc20Contract0 = self.rpc.eth.contract(address=self.token0, abi=abiErc20)
        self.erc20Contract1 = self.rpc.eth.contract(address=self.token1, abi=abiErc20)
        self.decimals0 = self.erc20Contract0.functions.decimals().call()
        self.decimals1 = self.erc20Contract1.functions.decimals().call()
        pass

    def loadSwaps(self):
        fromBlock = self.startBlock

        file_path = self.__getFilename("transactions")+".csv"
        status = 'w'
        if os.path.exists(file_path):
            if os.path.getsize(file_path) != 0:
                try:
                    data = pd.read_csv(file_path)
                    fromBlock = data['block'].max()//1000
                    status = 'a'
                finally:
                    if math.isnan(fromBlock):
                        fromBlock = self.startBlock
                        status = 'w'
                    pass
        print("start block is", fromBlock)

        self.csvFile = open(file_path, status)
        csvWriter = csv.writer(self.csvFile)

        if status == 'w':
            csvWriter.writerow(['block', 'sqrtPriceX96', 'liquidity', 'amount0', 'amount1'])

        toBlock = fromBlock + self.logBatch
        if toBlock > self.endBlock:
            toBlock = self.endBlock

        while fromBlock < self.endBlock:
            filter_params = {
                'fromBlock': int(fromBlock),
                'toBlock': int(toBlock),
                'address': self.poolAddress,
                'topics': [SWAP_TOPIC]
            }
            try:
                logs = self.rpc.eth.get_logs(filter_params)
            except Exception as e:
                if "Log response size exceeded" in str(e):
                    self.logBatch = int(9 * self.logBatch // 10)
                    toBlock = fromBlock + self.logBatch
                    print(f"log batch reduced to {self.logBatch}")
                else:
                    print(f"an error {e} during get_logs, sleep for 1 min")
                    time.sleep(60)
                continue

            for log in logs:
                l = SwapTransaction(log)
                csvWriter.writerow([l.block, l.sqrtPriceX96, l.liquidity, l.amount0, l.amount1])
                
            print(f"from [{fromBlock}, {toBlock}] blocks received: {len(logs)} logs")
            self.csvFile.flush()

            fromBlock += self.logBatch
            toBlock += self.logBatch

        print("loading has been finished")

    """
        calculate cost of position in amount of both tokens
        based on current spot price
    """
    def __calc_amounts(self, liquidity: Decimal, sqrtPrice: Decimal, sqrtPriceLower: Decimal, sqrtPriceUpper: Decimal):
        am0, am1 = DECIMAL_ZERO, DECIMAL_ZERO
        if sqrtPrice > sqrtPriceLower and sqrtPrice < sqrtPriceUpper:
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

        return am0Total, am1Total
    
    def __calc_liquidity(self, am0, am1, sqrtPrice: Decimal, sqrtPriceLower: Decimal, sqrtPriceUpper: Decimal):
        liquidity = DECIMAL_ZERO
        if sqrtPrice <= sqrtPriceLower:
            liquidity = am0 / (DECIMAL_ONE/sqrtPriceLower - DECIMAL_ONE/sqrtPriceUpper)
        elif sqrtPrice >= sqrtPriceUpper:
            liquidity = am1 / (sqrtPriceUpper - sqrtPriceLower)
        else:
            print("error: in range")
            exit(1)

        return liquidity

    def __calc_centered(self, sqrtPrice, width):
        tick = int(sqrtPrice_to_tick(sqrtPrice))
        tick = (tick // self.tickSpacing) * self.tickSpacing

        if tick < 0:
            tick -= self.tickSpacing
        if (width // self.tickSpacing) % 2 == 0:
            return int(tick-width/2), int(tick+width/2)
        else:
            tick += self.tickSpacing / 2
            return int(tick-width/2), int(tick+width/2)

    def __calc_near(self, sqrtPrice, width, sqrtPriceLower, sqrtPriceUpper):
        tick = int(sqrtPrice_to_tick(sqrtPrice))
        tick = (tick // self.tickSpacing) * self.tickSpacing

        if tick < 0:
            tick -= self.tickSpacing
        if sqrtPrice < sqrtPriceLower:
            tickLower = tick + self.tickSpacing
            tickUpper = tickLower + width
        elif sqrtPrice > sqrtPriceUpper:
            tickUpper = tick
            tickLower = tickUpper - width
        
        return tickLower, tickUpper

    def simulateLazy(self, width):

        self.loadSwaps()
        
        csvFileData = open(self.__getFilename("transactions")+".csv", 'r')
        data = pd.read_csv(csvFileData)

        csvFileResult = open(self.__getFilename(str(width)+"_result")+".csv", 'w')
        csvWriter = csv.writer(csvFileResult)
        csvWriter.writerow(['block',  'tickLower', 'tickUpper', 'tick', 'price', 'liquidity', 'amount0', 'amount1', 'inRange', 'IL0', 'IL1'])

        blocksInRangePercentage = 0
        blocksInRange = 0
        blocksInRangeDelta = 0

        inRange = False
        lastBlock = data['block'].iloc[0]
        sqrtPrice = Decimal(data['sqrtPriceX96'].iloc[0])/Q96
        firstBlock = lastBlock

        # amounts token at the start
        am0Hold, am1Hold = Decimal(10 ** self.decimals0), Decimal(10 ** self.decimals1)

        tickLower, tickUpper = self.__calc_centered(sqrtPrice, width)
        sqrtPriceLower = tick_to_sqrtPrice(tickLower)
        sqrtPriceUpper = tick_to_sqrtPrice(tickUpper)
        liquidity = (am0Hold * sqrtPrice * sqrtPrice + am1Hold) / (sqrtPriceUpper - sqrtPriceLower)
        am0Hold, am1Hold = self.__calc_amounts(liquidity, sqrtPrice, sqrtPriceLower, sqrtPriceUpper)

        for index, row in data.iterrows():
            block = int(row['block'])
            sqrtPrice = Decimal(row['sqrtPriceX96'])/Q96

            tick = sqrtPrice_to_tick(sqrtPrice)

            # if there is the place to move position toward sqrtPrice
            if tick < tickLower-self.tickSpacing or tick > tickUpper+self.tickSpacing:
                am0, am1 = self.__calc_amounts(liquidity, sqrtPrice, sqrtPriceLower, sqrtPriceUpper)

                tickLower, tickUpper = self.__calc_near(sqrtPrice, width, sqrtPriceLower, sqrtPriceUpper)

                sqrtPriceLower = tick_to_sqrtPrice(tickLower)
                sqrtPriceUpper = tick_to_sqrtPrice(tickUpper)

                liquidity = self.__calc_liquidity(am0, am1, sqrtPrice, sqrtPriceLower, sqrtPriceUpper)

                inRange = False
            
            # sqrtPrice inside range
            if sqrtPrice >= sqrtPriceLower and sqrtPrice <= sqrtPriceUpper:
                if inRange: # if it was in range => take into account previous block
                    blocksInRangeDelta = block-lastBlock
                inRange = True
            # sqrtPrice outside the range 
            else:
                if inRange: # if it was in range => take into account previous block
                    blocksInRangeDelta = block-lastBlock-1
                inRange = False

            if blocksInRangeDelta > 0:
                blocksInRange += blocksInRangeDelta

            if index % 1000 == 0:
                am0, am1 = self.__calc_amounts(liquidity, sqrtPrice, sqrtPriceLower, sqrtPriceUpper)
                csvWriter.writerow([
                    block, 
                    tickLower, tickUpper, tick,
                    float(sqrtPrice*sqrtPrice), 
                    float(liquidity), 
                    float(am0) / 10 ** self.decimals0, float(am1) / 10 ** self.decimals1, 
                    100 * blocksInRangePercentage,
                    100 * float((am0-am0Hold)/am0Hold), 100 * float((am1-am1Hold)/am1Hold)])
                csvFileResult.flush()

            if block > firstBlock:
                blocksInRangePercentage = blocksInRange/(block-firstBlock)
            lastBlock = block

swapLogLoader = SwapLogLoader(WETH_USDC)
swapLogLoader.simulateLazy(4000)
