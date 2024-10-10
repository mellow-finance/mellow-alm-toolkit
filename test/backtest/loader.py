import json
import os
from web3 import Web3, HTTPProvider
from hexbytes import HexBytes
from dotenv import load_dotenv

load_dotenv()

POOL_ADDRESS = "0x3241738149B24C9164dA14Fa2040159FFC6Dd237" # old USDC-WETH
BLOCK_INIT = 117044401

#POOL_ADDRESS = "0x478946BcD4a5a22b316470F5486fAfb928C0bA25" # new USDC-WETH
#BLOCK_INIT = 121535851
CHAIN_ID = '10'

class SwapTransaction:
    def __init__(self, log):
        self.typeTransaction = 1
        self.txHash = log.transactionHash.hex()
        self.block = log.blockNumber*1000 + log.transactionIndex
        self.tickLower = 0
        self.tickUpper = 0
        self.__extractData(log.data.hex())
        
    def __extractData(self, data):
        data = data[2:]
        amount0_bytes = bytes.fromhex(data[:64])
        amount1_bytes = bytes.fromhex(data[64:128])
        sqrtPriceX96_bytes = bytes.fromhex(data[128:192])
        liqudity_bytes = bytes.fromhex(data[192:256])

        self.liquidity = int.from_bytes(liqudity_bytes, byteorder='big', signed=False)
        self.sqrtPriceX96 = int.from_bytes(sqrtPriceX96_bytes, byteorder='big', signed=False)
        self.amount0 = int.from_bytes(amount0_bytes, byteorder='big', signed=True)
        self.amount1 = int.from_bytes(amount1_bytes, byteorder='big', signed=True)

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
        self.trans = []

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
            lasLenLogs = len(self.trans)
            filter_params = {
                'fromBlock': fromBlock,
                'toBlock': toBlock,
                'address': self.poolAddress,
                'topics': [self.swapTopic]
            }
            try:
                logs = self.rpc.eth.get_logs(filter_params)
            except:
                print("an error during get_logs")
                continue

            for log in logs:
                self.trans.append(SwapTransaction(log))
                
            print(f"from [{fromBlock}, {toBlock}] blocks recieved: {len(self.trans) - lasLenLogs} logs")

            fromBlock += self.logBatch
            toBlock += self.logBatch

        self.writeTransToJsonFile()

    def writeTransToJsonFile(self):
        data = [instance.toDict() for instance in self.trans]
        with open(self.__getFilename("transactions")+".json", 'w') as file:
            json.dump(data, file, indent=4)

#swapLogLoader = SwapLogLoader('10', "velodrome", "0x2d5814480EC2698B46B5b3f3287A89d181612228", 118000000, 121385392)
swapLogLoader = SwapLogLoader(CHAIN_ID, "velodrome", POOL_ADDRESS, BLOCK_INIT)
#swapLogLoader = SwapLogLoader('10', "velodrome", "0x1e60272caDcFb575247a666c11DBEA146299A2c4", 117069418)
# weth-op 0x1e60272caDcFb575247a666c11DBEA146299A2c4
swapLogLoader.loadSwaps()