import json
import os
import csv
from web3 import Web3
from hexbytes import HexBytes
from dotenv import load_dotenv

load_dotenv()

class SwapTransaction:
    def __init__(self, log):
        if len(log.data) != 160:
            print("wrong log")
            exit(1)
        self.txHash = log.transactionHash.hex()
        self.block = log.blockNumber
        self.__extractData(log.data)

    def __extractData(self, data):
        data_bytes = bytes(data)
        amount0_bytes = data_bytes[:32]
        amount1_bytes = data_bytes[32:64]
        sqrtPriceX96_bytes = data_bytes[64:96]
        liquidity_bytes = data_bytes[96:128]
        tick_bytes = data_bytes[128:160]

        self.amount0 = int.from_bytes(amount0_bytes, byteorder='big', signed=True)
        self.amount1 = int.from_bytes(amount1_bytes, byteorder='big', signed=True)
        self.sqrtPriceX96 = int.from_bytes(sqrtPriceX96_bytes, byteorder='big', signed=False)
        self.liquidity = int.from_bytes(liquidity_bytes, byteorder='big', signed=False)
        self.tick = int.from_bytes(tick_bytes, byteorder='big', signed=True)

    def toDict(self):
        return {key: (value.hex() if isinstance(value, HexBytes) else value) 
                for key, value in self.__dict__.items() if not key.startswith('_')}

class SwapLogLoader:
    def __init__(self, chainId, dex, poolAddress, startBlock, endBlock):

        self.chainId = chainId
        self.__readSettings(dex)

        print("rpc_url", self.rpcUrl)
        self.rpc = Web3(Web3.HTTPProvider(self.rpcUrl))
        if self.rpc.is_connected():
            print("Connected to chain %s node" % (chainId))
        else:
            print("Failed to connect to %s node" % (chainId))
            exit(1)

        self.poolAddress = poolAddress
        self.startBlock = startBlock
        self.endBlock = endBlock
        self.__csvInitialized = False
        self.__getTokenDecimals()
    
    def __readSettings(self, dex):
        with open("settings.json") as f:
            settings = json.load(f)
            self.settings = settings[self.chainId]

        self.rpcUrl = os.getenv(self.settings['rpc_env'])
        self.logBatch = self.settings['logBatch']
        self.abiErc20File = self.settings['abiErc20File']
        self.swapTopic = self.settings['dex'][dex]['swapTopic']
        self.abiFile = self.settings['dex'][dex]['abiFile']
        pass

    def __getTokenDecimals(self):
        with open(self.abiFile) as f:
            abiPool = json.load(f)
        with open(self.abiErc20File) as f:
            abiErc20 = json.load(f)
        self.poolContract = self.rpc.eth.contract(address=self.poolAddress, abi=abiPool)
        self.token0 = self.poolContract.functions.token0().call()
        self.token1 = self.poolContract.functions.token1().call()
        self.erc20Contract0 = self.rpc.eth.contract(address=self.token0, abi=abiErc20)
        self.erc20Contract1 = self.rpc.eth.contract(address=self.token1, abi=abiErc20)
        self.decimals0 = self.erc20Contract0.functions.decimals().call()
        self.decimals1 = self.erc20Contract1.functions.decimals().call()
        pass
    
    def loadSwaps(self):
        fromBlock = self.startBlock
        toBlock = fromBlock + self.logBatch
        while fromBlock < self.endBlock:
            filter_params = {
                'fromBlock': fromBlock,
                'toBlock': toBlock,
                'address': self.poolAddress,
                'topics': [self.swapTopic]
            }
            logs = self.rpc.eth.get_logs(filter_params)
            for log in logs:
                trans = SwapTransaction(log)
                if not self.__csvInitialized:
                    self.initializeCsv('data/' + self.chainId + "/" + self.poolAddress+'.csv', trans.toDict().keys())
                self.appendToCsv(trans)
            print(f"from [{fromBlock}, {toBlock}] blocks recieved {len(logs)} logs")
            fromBlock += self.logBatch
            toBlock += self.logBatch

    def initializeCsv(self, filename, fieldnames):
        self.file = open(filename, mode='w', newline='')
        self.writer = csv.DictWriter(self.file, fieldnames=fieldnames)
        self.writer.writeheader()
        self.__csvInitialized = True

    def appendToCsv(self, obj):
        data = obj.toDict()
        self.writer.writerow(data)

swapLogLoader = SwapLogLoader('10', "velodrome", "0x2d5814480EC2698B46B5b3f3287A89d181612228", 118000000, 121385392)
swapLogLoader.loadSwaps()
