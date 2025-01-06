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
import os
cwd = os.getcwd()
print(cwd)

DECIMAL_ZERO = Decimal(0)
DECIMAL_ONE = Decimal(1)
SWAP_IMPACT = Decimal(0.01/100)
INFINITE_BLOCK = 10**20

load_dotenv()

SWAP_TOPIC = '0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67'

"""
          BASE AERO
    [0]   0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59 | 4000 | 100 |  weth  |  usdc  |  500k |   lazy   |   30     | 1 hour |  42   |
    [1]   0x861A2922bE165a5Bd41b1E482B49216b465e1B5F |    1 |   1 |  weth  |  wsteth|  500k |  tamper  |   30     | 1 hour |   5   |
    [2]   0xc5E51044eB7318950B1aFb044FccFb25782C48c1 | 1000 |   1 |  eurc  |  usdc  |  500k |  tamper  |
    [3]   0x70aCDF2Ad0bf2402C957154f944c19Ef4e1cbAE1 | 4000 | 100 |  weth  | cbbtc  |  500k |   lazy   |
"""

"""      OPTIMISM VELO                          
    [0]  0x478946BcD4a5a22b316470F5486fAfb928C0bA25 | 4200 | 100 | usdc   |   weth |  500k | lazySync |   30     | 1 hour |  42   |
    [1]  0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4 |  280 |   1 | wsteth |   weth |  400k |  tamper  |   30     | 1 hour |   5   |
    [2]  0x84a67CD00EB244edCa2288346ADD251A783243c8 | 6000 |  50 | weth   |     op |  500k | lazySync |   30     | 1 hour |  60   |
"""

# address -> init block
OPT_CHAIN_ID = '10'
BASE_CHAIN_ID = '8453'

POOLS = {
    #======================================================
    "WETH-USDC_BASE": [
        "0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59",
        13904084,
        BASE_CHAIN_ID
    ],
    "WETH-WSTETH_BASE": [
        "0x861A2922bE165a5Bd41b1E482B49216b465e1B5F",
        13954872,
        BASE_CHAIN_ID
    ],
    "EURC-USDC_BASE": [
        "0xc5E51044eB7318950B1aFb044FccFb25782C48c1",
        21861234,
        BASE_CHAIN_ID
    ],
    "WETH-CBBTC_BASE": [
        "0x70aCDF2Ad0bf2402C957154f944c19Ef4e1cbAE1",
        19347433,
        BASE_CHAIN_ID
    ],
    #======================================================
    "USDC-WETH_OPT": [
        "0x478946BcD4a5a22b316470F5486fAfb928C0bA25",
        117044107,
        OPT_CHAIN_ID
    ],
    "WSTETH-WETH_OPT": [
        "0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4",
        121537871,
        OPT_CHAIN_ID
    ],
    "WETH-OP_OPT": [
        "0x84a67CD00EB244edCa2288346ADD251A783243c8",
        129174241,
        OPT_CHAIN_ID
    ],
    #======================================================
}

BLOCK_DURATION = {
    OPT_CHAIN_ID: 2.0,
    BASE_CHAIN_ID: 2.0
}

BLOCK_WRITE_INTERVAL= {
    OPT_CHAIN_ID: 1000,
    BASE_CHAIN_ID: 1000
}

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
    def __init__(self, pool):
        self.poolAddress = pool[0]
        self.startBlock = pool[1]
        self.chainId = pool[2]
        self.fee = None
        
        self.__readSettings()
        self.__connect()
        
        self.endBlock = self.rpc.eth.block_number
        self.path = '../data/' + self.chainId + "/" + self.poolAddress + "/" 
        os.makedirs(self.path, exist_ok=True)
        self.part = 1
        with open(self.abiFile) as f:
            self.abiPool = json.load(f)
        self.__getTokenDecimals()

    def getFilename(self, name):
        return self.path + name

    def __connect(self):
        self.rpc = Web3(HTTPProvider(self.rpcUrl))
        if self.rpc.is_connected():
            print("Connected async to chain %s node" % (self.chainId))
        else:
            print("Failed to connect to %s node" % (self.chainId))
            exit(1)

    def __readSettings(self):
        if self.chainId == OPT_CHAIN_ID:
            self.rpcUrl = os.getenv('OPTIMISM_RPC')
            self.logBatch = 20000
        elif self.chainId == BASE_CHAIN_ID:
            self.rpcUrl = os.getenv('BASE_RPC')
            self.logBatch = 20000

        self.abiErc20File = '../abi/erc20.json'
        self.abiFile = "../abi/velodrom_abi.json"

    def __getTokenDecimals(self):
        with open(self.abiErc20File) as f:
            abiErc20 = json.load(f)
        self.poolContract = self.rpc.eth.contract(address=self.poolAddress, abi=self.abiPool)
        self.token0 = self.poolContract.functions.token0().call()
        self.token1 = self.poolContract.functions.token1().call()
        self.tickSpacing = self.poolContract.functions.tickSpacing().call()
        self.fee = Decimal(self.poolContract.functions.fee().call())/1000000
        self.erc20Contract0 = self.rpc.eth.contract(address=self.token0, abi=abiErc20)
        self.erc20Contract1 = self.rpc.eth.contract(address=self.token1, abi=abiErc20)
        self.decimals0 = self.erc20Contract0.functions.decimals().call()
        self.decimals1 = self.erc20Contract1.functions.decimals().call()
        print(self.poolAddress, self.tickSpacing, self.fee, self.decimals0, self.decimals1)
        pass

    def loadSwaps(self):
        fromBlock = self.startBlock

        file_path = self.getFilename("transactions")+".csv"
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


#swapLogLoader = SwapLogLoader(POOLS['WETH-USDC_BASE'])
#swapLogLoader.simulateLazy(4000)
