import json
import os
from web3 import Web3, HTTPProvider
from hexbytes import HexBytes
from dotenv import load_dotenv

load_dotenv()

class MintTransaction:
    def __init__(self, log):
        self.txHash = log.transactionHash.hex()
        self.block = log.blockNumber*1000 + log.transactionIndex
        self.tickLower = int.from_bytes(log.topics[2], byteorder='big', signed=True)
        self.tickUpper = int.from_bytes(log.topics[3], byteorder='big', signed=True)
        self.__extractData(log.data)

    def __extractData(self, data):
        data_bytes = bytes(data)
        liquidity = data_bytes[32:64]
        amount0 = data_bytes[64:96]
        amount1 = data_bytes[96:128]

        self.liquidity = int.from_bytes(liquidity, byteorder='big', signed=False)
        self.amount0 = int.from_bytes(amount0, byteorder='big', signed=True)
        self.amount1 = int.from_bytes(amount1, byteorder='big', signed=True)

    def toDict(self):
        return {key: (value.hex() if isinstance(value, HexBytes) else value) 
                for key, value in self.__dict__.items() if not key.startswith('_')}

class BurnTransaction:
    def __init__(self, log):
        self.txHash = log.transactionHash.hex()
        self.block = log.blockNumber*1000 + log.transactionIndex
        self.owner = log.topics[1][12:32].hex()
        self.tickLower = int.from_bytes(log.topics[2], byteorder='big', signed=True)
        self.tickUpper = int.from_bytes(log.topics[3], byteorder='big', signed=True)
        self.__extractData(log.data)

    def __extractData(self, data):
        data_bytes = bytes(data)
        liquidity = data_bytes[0:32]
        amount0 = data_bytes[32:64]
        amount1 = data_bytes[64:96]

        self.liquidity = int.from_bytes(liquidity, byteorder='big', signed=False)
        self.amount0 = int.from_bytes(amount0, byteorder='big', signed=True)
        self.amount1 = int.from_bytes(amount1, byteorder='big', signed=True)

    def toDict(self):
        return {key: (value.hex() if isinstance(value, HexBytes) else value) 
                for key, value in self.__dict__.items() if not key.startswith('_')}

class SwapTransaction:
    def __init__(self, log):
        self.txHash = log.transactionHash.hex()
        self.block = log.blockNumber*1000 + log.transactionIndex
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
    def __init__(self, chainId, dex, poolAddress, startBlock):

        self.chainId = chainId
        self.__readSettings(dex)
        self.__connect()
        
        self.poolAddress = poolAddress
        self.startBlock = startBlock
        self.endBlock = self.rpc.eth.block_number
        self.path = 'data/' + self.chainId + "/" + self.poolAddress + "/" 
        os.makedirs(self.path, exist_ok=True)
        self.part = 1
        with open(self.abiFile) as f:
            self.abiPool = json.load(f)
        self.swaps = []
        self.mints = []
        self.burns = []

    def __getFilename(self, name):
        return self.path + name

    def __connect(self):
        self.rpc = Web3(HTTPProvider(self.rpcUrl))
        if self.rpc.is_connected():
            print("Connected async to chain %s node" % (self.chainId))
        else:
            print("Failed to connect to %s node" % (self.chainId))
            exit(1)

    def __readSettings(self, dex):
        with open("settings.json") as f:
            settings = json.load(f)
            self.settings = settings[self.chainId]

        self.rpcUrl = os.getenv(self.settings['rpc_env'])
        self.logBatch = self.settings['logBatch']
        self.abiErc20File = self.settings['abiErc20File']
        self.swapTopic = self.settings['dex'][dex]['swapTopic']
        self.burnTopic = self.settings['dex'][dex]['burnTopic']
        self.mintTopic = self.settings['dex'][dex]['mintTopic']
        self.abiFile = self.settings['dex'][dex]['abiFile']
        pass

    def __getTokenDecimals(self):
        with open(self.abiErc20File) as f:
            abiErc20 = json.load(f)
        self.poolContract = self.rpc.eth.contract(address=self.poolAddress, abi=self.abiPool)
        self.token0 = self.poolContract.functions.token0().call()
        self.token1 = self.poolContract.functions.token1().call()
        self.erc20Contract0 = self.rpc.eth.contract(address=self.token0, abi=abiErc20)
        self.erc20Contract1 = self.rpc.eth.contract(address=self.token1, abi=abiErc20)
        self.decimals0 = self.erc20Contract0.functions.decimals().call()
        self.decimals1 = self.erc20Contract1.functions.decimals().call()
        pass

    def loadSwaps(self):
        self.__getTokenDecimals()
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
                self.swaps.append(SwapTransaction(log))
            swapLogs = len(logs)


            filter_params['topics'] = [self.mintTopic]
            logs = self.rpc.eth.get_logs(filter_params)
            for log in logs:
                self.mints.append(MintTransaction(log))
            mintLogs = len(logs)


            filter_params['topics'] = [self.burnTopic]
            logs = self.rpc.eth.get_logs(filter_params)
            for log in logs:
                tran = BurnTransaction(log)
                if tran.liquidity > 0:
                    self.burns.append(tran)
            burnLogs = len(logs)
            print(f"from [{fromBlock}, {toBlock}] blocks recieved: {swapLogs} swap logs | {mintLogs} mint logs | {burnLogs} burn logs")

            fromBlock += self.logBatch
            toBlock += self.logBatch
            if len(self.swaps) + len(self.mints) + len(self.burns) > 10000:
                self.writeToJsonFile()
                self.part += 1
                self.swaps = []
                self.mints = []
                self.burns = []

    def writeToJsonFile(self):
        data = {
            'swap': [instance.toDict() for instance in self.swaps],
            'mint': [instance.toDict() for instance in self.mints],
            'burn': [instance.toDict() for instance in self.burns],
        }
        with open(self.__getFilename("transactions")+"_"+str(self.part)+".json", 'w') as file:
            json.dump(data, file, indent=4)

    def appendToCsv(self, obj):
        data = obj.toDict()
        self.writer.writerow(data)

#swapLogLoader = SwapLogLoader('10', "velodrome", "0x2d5814480EC2698B46B5b3f3287A89d181612228", 118000000, 121385392)
#swapLogLoader = SwapLogLoader('10', "velodrome", "0x3241738149B24C9164dA14Fa2040159FFC6Dd237", 121085392, 121385392)
swapLogLoader = SwapLogLoader('10', "velodrome", "0x1e60272caDcFb575247a666c11DBEA146299A2c4", 117069418)
# weth-op 0x1e60272caDcFb575247a666c11DBEA146299A2c4
swapLogLoader.loadSwaps()
