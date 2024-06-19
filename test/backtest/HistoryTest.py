import json
import os
import subprocess
from dotenv import load_dotenv
from web3 import Web3, HTTPProvider
import time

load_dotenv()

# Start Anvil with custom code size limit
#anvil_process = subprocess.Popen([
#    'anvil',
#    '--fork-url', 'https://opt-mainnet.g.alchemy.com/v2/oPPlIjgGxGvQx3qKFOhzbhvZPUsm6amk',
#    '--fork-block-number', '117124556',
#    '--gas-limit', '1000000000',
#    '--code-size-limit', '50000'
#])

class HistoryTest:
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

        self.private_key = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'
        self.account = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'

        self.__deploy()
    
    # Grant ETH to the wallet
    def grant_eth(self, address, amount_eth):
        self.rpc.provider.make_request("anvil_setBalance", [address, self.rpc.to_wei(amount_eth, 'ether')])
        print(f'Granted {amount_eth} ETH to {address}')

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

        self.rpcUrl = 'http://127.0.0.1:8545'
        self.logBatch = self.settings['logBatch']
        self.abiErc20File = self.settings['abiErc20File']
        self.abiFile = self.settings['dex'][dex]['abiFile']
        pass

    def __deploy(self):

        testAbiFile =  os.path.abspath('../../out/HistoryStrategyTest.t.sol/HistoryTest.json')

        with open(testAbiFile) as f:
            data = json.load(f)
            self.abiTest = data["abi"]
            self.bytecodeTest = data['bytecode']['object']
        nonce = self.rpc.eth.get_transaction_count(self.account)
        #gasPrice = self.rpc.eth.eth_gasPrice()
        tx_data = {
            'chainId': 10,  # Update the chain ID if necessary
            'gas': 30000000,
            'data': self.bytecodeTest,
            'nonce': nonce,
            'gasPrice': 603,
        }
        # Sign and send transaction
        signed_tx = self.rpc.eth.account.sign_transaction(tx_data, self.private_key)
        #print(f'Transaction data: {tx_data}')
        tx_hash = self.rpc.eth.send_raw_transaction(signed_tx.rawTransaction)
        print(f'Transaction sent with hash: {tx_hash.hex()}')

        # Optionally wait for the transaction receipt
        receipt = self.rpc.eth.wait_for_transaction_receipt(tx_hash)
        print(f'Transaction receipt: {receipt}')
        self.testContractAddress = receipt.contractAddress

        code = self.rpc.eth.get_code(self.testContractAddress)
        if code and code != b'0x':
            print(f'There is a contract deployed at address {self.testContractAddress}')
        else:
            print(f'There is no contract at address {self.testContractAddress}')
            exit(1)
        self.testContract = self.rpc.eth.contract(address=self.testContractAddress, abi=self.abiTest)
        self.makeCall()
        return
        filename = 'HistoryStrategyDeploy.s.sol'
        fullPath = os.path.abspath(filename)
        command = [
            'forge', 'script', "--use", "0.8.20", fullPath + ':Deploy', '--rpc-url', self.rpcUrl, "--broadcast", "-vvv", "--verify"
        ]
        result = subprocess.run(command, capture_output=True, text=True)
        print(result.stdout)
        print(result.stderr)


        
        for line in result.stdout.split('\n'):
            if 'Contract deployed at:' in line:
                self.testContractAddress = line.split('Contract deployed at: ')[1].strip()
        if self.testContractAddress is None:
            raise Exception("Failed to deploy contract")
        
        print("test contract deployed at ", self.testContractAddress)
        code = self.rpc.eth.get_code(self.testContractAddress)
        print(f'Bytecode at address {self.testContractAddress}: {code}')
        if code and code != b'0x':
            print(f'There is a contract deployed at address {self.testContractAddress}')
        else:
            print(f'There is no contract at address {self.testContractAddress}')
            exit(1)
        print('code', code)
        self.testContract = self.rpc.eth.contract(address=self.testContractAddress, abi=self.abiTest)
        #self.makeCall()

    def makeCall(self):
        data = self.testContract.encodeABI(fn_name='testSimulateTransactions', args=["test/backtest/data/10/0x1e60272caDcFb575247a666c11DBEA146299A2c4/transactions_1.json"])
        nonce = self.rpc.eth.get_transaction_count(self.account)
        #gasPrice = self.rpc.eth.eth_gasPrice()
        tx_data = {
            'chainId': 10,  # Update the chain ID if necessary
            'gas': 30000000,
            'to': self.testContractAddress,#'0x5b73c5498c1e3b4dba84de0f1833c4a029d90519',#self.testContractAddress,
            'data': data,
            'nonce': nonce,
            'gasPrice': 603,
        }

        # Sign and send transaction
        signed_tx = self.rpc.eth.account.sign_transaction(tx_data, self.private_key)
        print(f'Transaction data: {tx_data}')
        tx_hash = self.rpc.eth.send_raw_transaction(signed_tx.rawTransaction)
        print(f'Transaction sent with hash: {tx_hash.hex()}')

        # Optionally wait for the transaction receipt
        receipt = self.rpc.eth.wait_for_transaction_receipt(tx_hash)
        print(f'Transaction receipt: {receipt}')

swapLogLoader = HistoryTest('10', "velodrome", "0x1e60272caDcFb575247a666c11DBEA146299A2c4", 117069418)