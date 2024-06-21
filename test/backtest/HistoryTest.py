import json
import os
import subprocess
from dotenv import load_dotenv
from web3 import Web3, HTTPProvider
import time

load_dotenv()
CHAIN_ID = 10
GAS_LIMIT = 30000000
NONFUNGIBLE_POSITION_MANAGER = '0xbB5DFE1380333CEE4c2EeBd7202c80dE2256AdF4'
ADMIN = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'
OP_HOLDER = '0x790b4086D106Eafd913e71843AED987eFE291c92'
OP_ADRESS = '0x4200000000000000000000000000000000000042'
WETH_ADRESS = '0x4200000000000000000000000000000000000006'
ZERO_ADRESS = '0x0000000000000000000000000000000000000000'
TRANSACTION_BATCH = 100
BLOCK_VALID_POSITION = 117109417

# Start Anvil with custom code size limit
PORT = '8546'
anvil_process = subprocess.Popen([
    'anvil',
    '--fork-url', os.environ.get("OPTIMISM_RPC"),
    '--fork-block-number', '117078536',
    '--gas-limit', '1000000000',
    '--gas-price', '1',
    '--auto-impersonate',
    '--code-size-limit', '50000',
    '--port', PORT
])

SmartContracts = {
    'VeloOracle': '',
    'PulseStrategyModule': '',
    'VeloDeployFactoryHelper': '',
    'VeloAmmModule': '',
    'VeloDepositWithdrawModule': '',
    'PulseVeloBot': '',
}


class HistoryTest:
    def __init__(self, dex, poolAddress, startBlock):
        
        self.__readSettings(dex)
        self.__connect()
        
        self.rpc.eth.default_account = ADMIN
        
        self.poolAddress = poolAddress
        self.startBlock = startBlock
        self.endBlock = self.rpc.eth.block_number
        self.path = 'data/' + str(CHAIN_ID) + "/" + self.poolAddress + "/" 
        os.makedirs(self.path, exist_ok=True)
        self.part = 1
        with open(self.abiFile) as f:
            self.abiPool = json.load(f)

        self.deployAll()
        return
    
    def updateContractParams(self):
        self.SmartContractsParam = {
            'VeloOracle': [NONFUNGIBLE_POSITION_MANAGER],
            'PulseStrategyModule': '',
            'VeloDeployFactoryHelper': '',
            'VeloAmmModule': [NONFUNGIBLE_POSITION_MANAGER],
            'VeloDepositWithdrawModule': [NONFUNGIBLE_POSITION_MANAGER],
            'PulseVeloBot': [ZERO_ADRESS, ZERO_ADRESS, NONFUNGIBLE_POSITION_MANAGER],
            'HistoryTest': [
                SmartContracts['VeloOracle'], 
                SmartContracts['PulseStrategyModule'], 
                SmartContracts['VeloDeployFactoryHelper'], 
                SmartContracts['VeloAmmModule'],
                SmartContracts['VeloDepositWithdrawModule'], 
                SmartContracts['PulseVeloBot'], 
            ]
        }

    def __connect(self):
        self.rpc = Web3(HTTPProvider(self.rpcUrl))
        if self.rpc.is_connected():
            print("Connected to chain %s node" % (CHAIN_ID))
        else:
            print("Failed to connect to %s node" % (CHAIN_ID))
            exit(1)

    def __readSettings(self, dex):
        with open("settings.json") as f:
            settings = json.load(f)
            self.settings = settings[str(CHAIN_ID)]

        self.rpcUrl = 'http://127.0.0.1:' + PORT
        self.abiErc20File = self.settings['abiErc20File']
        self.abiFile = self.settings['dex'][dex]['abiFile']

        with open(self.abiErc20File) as f:
            self.abiErc20 = json.load(f)

    def deployAll(self):
        for key in SmartContracts:
            self.deployContract(key)
        self.__deploy()

    def deployContract(self, name):
        self.updateContractParams()
        print(f"deploy {name}", self.SmartContractsParam[name])
        abiFile =  os.path.abspath('../../out/'+name+'.sol/'+name+'.json')
        with open(abiFile) as f:
            data = json.load(f)
            abi = data["abi"]
            if abi is None:
                print(f"abi of {name} not found")
                exit(1)
            bytecode = data['bytecode']['object']
            if bytecode is None:
                print(f"bytecode of {name} not found")
                exit(1)
            nonce = self.rpc.eth.get_transaction_count(ADMIN)
            contract = self.rpc.eth.contract(abi=abi, bytecode=bytecode)
            txData = contract.constructor(*self.SmartContractsParam[name]).build_transaction({
                'from': ADMIN,
                'chainId': CHAIN_ID,
                'gas': GAS_LIMIT,
                'nonce': nonce,
                'gasPrice': self.rpc.eth.gas_price,
            })
            receipt = self.__sendTransaction(txData)
            
            contractAddress = receipt.contractAddress
            if contractAddress is None:
                print(f"contract {name} was not deployed")
                exit(1)
            SmartContracts[name] = contractAddress
            print(f"contract {name} was deployed at {contractAddress}")

    def __deploy(self):
        self.updateContractParams()
        print(f"deploy HistoryTest", self.SmartContractsParam['HistoryTest'])
        testAbiFile =  os.path.abspath('../../out/HistoryStrategyTest.t.sol/HistoryTest.json')

        with open(testAbiFile) as f:
            data = json.load(f)
            self.abiTest = data["abi"]
            self.bytecodeTest = data['bytecode']['object']
        nonce = self.rpc.eth.get_transaction_count(ADMIN)
        contract = self.rpc.eth.contract(abi=self.abiTest, bytecode=self.bytecodeTest)

        txData = contract.constructor(*self.SmartContractsParam['HistoryTest']).build_transaction({
            'chainId': CHAIN_ID,
            'gas': GAS_LIMIT,
            'nonce': nonce,
            'gasPrice': self.rpc.eth.gas_price,
        })
        receipt = self.__sendTransaction(txData)
        
        self.testContractAddress = receipt.contractAddress

        code = self.rpc.eth.get_code(self.testContractAddress)
        if code and code != b'0x':
            print(f'There is a contract deployed at address {self.testContractAddress}')
        else:
            print(f'There is no contract at address {self.testContractAddress}')
            exit(1)
        self.testContract = self.rpc.eth.contract(address=self.testContractAddress, abi=self.abiTest)

        self.__grantTokens(receipt.contractAddress)
        self.__init()

    def __sendTransaction(self, txData):
        txHash = self.rpc.eth.send_transaction(txData)
        return self.rpc.eth.wait_for_transaction_receipt(txHash)

    def __grantTokens(self, to):
        #transfer WETH
        balance = self.rpc.eth.get_balance(to)
        amount0 = 10**8
        self.opContract = self.rpc.eth.contract(address=OP_ADRESS, abi=self.abiErc20)
        amount1 = self.opContract.functions.balanceOf(OP_HOLDER).call()
        self.__grantEth(to, amount0)
        print("ETH transferred", balance, self.rpc.eth.get_balance(to), "transfer amount0", amount0)
        # transfer OP
        self.__grantEth(OP_HOLDER, 1)
        txData = self.opContract.functions.transfer(to, amount1).build_transaction({
            'from': OP_HOLDER,
            'nonce': self.rpc.eth.get_transaction_count(OP_HOLDER),
            'gas': GAS_LIMIT,
            'gasPrice': self.rpc.eth.gas_price,
        })
        balanceBefore = self.opContract.functions.balanceOf(to).call()

        receipt = self.__sendTransaction(txData)
        balanceAfter = self.opContract.functions.balanceOf(to).call()
        print("token transferred", balanceBefore, balanceAfter, "transfer amount1", amount1)
    
    # Grant ETH to the wallet
    def __grantEth(self, address, amount):
        wei_amount = self.rpc.to_wei(amount, 'ether')
        hex_wei_amount = hex(wei_amount)
        self.rpc.provider.make_request("anvil_setBalance", [address, hex_wei_amount])
        print(f'Granted {amount} ETH to {address}')

    def __init(self):
        txData = self.testContract.functions.init().build_transaction({
            'chainId': CHAIN_ID,
            'gas': GAS_LIMIT,
            'nonce': self.rpc.eth.get_transaction_count(ADMIN),
            'gasPrice': self.rpc.eth.gas_price,
        })
        receipt = self.__sendTransaction(txData)

    def __setUpStrategy(self):
        txData = self.testContract.functions.setUpStrategy(2).build_transaction({
            'chainId': CHAIN_ID,
            'gas': GAS_LIMIT,
            'nonce': self.rpc.eth.get_transaction_count(ADMIN),
            'gasPrice': self.rpc.eth.gas_price,
        })
        return self.__sendTransaction(txData)
    
    def __rebalance(self):
        txData = self.testContract.functions.rebalance().build_transaction({
            'chainId': CHAIN_ID,
            'gas': GAS_LIMIT,
            'nonce': self.rpc.eth.get_transaction_count(ADMIN),
            'gasPrice': self.rpc.eth.gas_price,
        })
        reciept = self.__sendTransaction(txData)
        if reciept.status == 1:
            return self.testContract.functions.rebalance().call()
        return 0

    def simulate(self):
        reciept = self.__setUpStrategy()
        if reciept.status != 1:
            print(f"set up staretegy is finished with {reciept.status}")
            print(reciept)
            exit(1)
        filePath =  os.path.abspath('data/10/0x1e60272caDcFb575247a666c11DBEA146299A2c4/transactions.json')
        data = None
        with open(filePath, 'r') as file:
            data = json.load(file)
        data = sorted(data, key=lambda x: x["block"])
        successAll = 0
        for step in range(len(data)//TRANSACTION_BATCH):
            formatted_transactions = [
                {
                    "typeTransaction": tx["typeTransaction"],
                    "amount0": int(tx["amount0"]),
                    "amount1": int(tx["amount1"]),
                    "block": tx["block"]//1000,
                    "liquidity": int(tx["liquidity"]),
                    "tickLower": tx["tickLower"],
                    "tickUpper": tx["tickUpper"],
                    "txHash": Web3.to_bytes(hexstr=tx["txHash"])
                }
                for tx in data[step*TRANSACTION_BATCH:(step+1)*TRANSACTION_BATCH]
            ]

            txData = self.testContract.functions.poolTransaction(formatted_transactions).build_transaction({
                'chainId': CHAIN_ID,
                'gas': GAS_LIMIT,
                'gasPrice': self.rpc.eth.gas_price,
                'nonce': self.rpc.eth.get_transaction_count(ADMIN),
            })

            receipt = self.__sendTransaction(txData)
            if receipt.status != 1:
                print(f"ERROR at call {step} batch, transactions from {step*TRANSACTION_BATCH} to {(step+1)*TRANSACTION_BATCH}")
                print(formatted_transactions)
                continue
            successBatch = self.testContract.functions.poolTransaction(formatted_transactions).call()
            successAll += successBatch
            tokenId = self.testContract.functions.tokenId().call()
            [token0Pos, token1Pos] = self.testContract.functions.positionView().call()
            print(f"{step}-th batch: {100*successBatch/TRANSACTION_BATCH}% | total: {100*successAll/((step+1)*TRANSACTION_BATCH)}% tokenId {tokenId} position {token0Pos} WETH | {token1Pos} OP")
time.sleep(3)
swapLogLoader = HistoryTest("velodrome", "0x1e60272caDcFb575247a666c11DBEA146299A2c4", 117069418)
swapLogLoader.simulate()