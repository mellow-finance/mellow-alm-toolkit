import json
import os
import subprocess
from dotenv import load_dotenv
from web3 import Web3, HTTPProvider
import time

load_dotenv()
OP_HOLDER = '0x790b4086D106Eafd913e71843AED987eFE291c92'
OP_ADRESS = '0x4200000000000000000000000000000000000042'
WETH_ADRESS = '0x420000000000000000000000000000000000006'

# Start Anvil with custom code size limit
#anvil_process = subprocess.Popen([
#    'anvil',
#    '--fork-url', 'https://opt-mainnet.g.alchemy.com/v2/oPPlIjgGxGvQx3qKFOhzbhvZPUsm6amk',
#    '--fork-block-number', '117069417',
#    '--gas-limit', '1000000000',
#    '--gas-price', '1',
#    '--auto-impersonate',
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
        self.sentTransactionToPool()
        return

    def grantTokens(self, to, amount0, amount1):
        with open(self.abiErc20File) as f:
            abiErc20 = json.load(f)
        #transfer WETH
        balance = self.rpc.eth.get_balance(to)
        self.grantEth(to, amount0)
        print("ETH transferred", balance, self.rpc.eth.get_balance(to), "transfer amount0", amount0)
        # transfer OP
        self.opContract = self.rpc.eth.contract(address=OP_ADRESS, abi=abiErc20)
        amount1 = self.rpc.to_wei(amount1, 'ether')
        tx_data = self.opContract.functions.transfer(to, amount1).build_transaction({
            'from': OP_HOLDER,
            'nonce': self.rpc.eth.get_transaction_count(OP_HOLDER),
            'gas': 200000,
            'gasPrice': self.rpc.eth.gas_price,
        })
        balanceBefore = self.opContract.functions.balanceOf(to).call()
        tx_hash = self.rpc.eth.send_transaction(tx_data)
        receipt = self.rpc.eth.wait_for_transaction_receipt(tx_hash)
        #print(receipt)
        balanceAfter = self.opContract.functions.balanceOf(to).call()
        print("token transferred", balanceBefore, balanceAfter, "transfer amount1", amount1)
        return tx_hash
    
    # Grant ETH to the wallet
    def grantEth(self, address, amount):
        wei_amount = self.rpc.to_wei(amount, 'ether')
        hex_wei_amount = hex(wei_amount)
        response = self.rpc.provider.make_request("anvil_setBalance", [address, hex_wei_amount])
        #print(response)
        print(f'Granted {amount} ETH to {address}')

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
        tx_data = {
            'chainId': 10,  # Update the chain ID if necessary
            'gas': 30000000,
            'data': self.bytecodeTest,
            'nonce': nonce,
            'gasPrice': self.rpc.eth.gas_price,
        }
        # Sign and send transaction
        signed_tx = self.rpc.eth.account.sign_transaction(tx_data, self.private_key)
        #print(f'Transaction data: {tx_data}')
        tx_hash = self.rpc.eth.send_raw_transaction(signed_tx.rawTransaction)
        #print(f'Transaction sent with hash: {tx_hash.hex()}')

        # Optionally wait for the transaction receipt
        receipt = self.rpc.eth.wait_for_transaction_receipt(tx_hash)
        #print(f'Transaction receipt: {receipt}')
        self.testContractAddress = receipt.contractAddress

        code = self.rpc.eth.get_code(self.testContractAddress)
        if code and code != b'0x':
            print(f'There is a contract deployed at address {self.testContractAddress}')
        else:
            print(f'There is no contract at address {self.testContractAddress}')
            exit(1)
        self.testContract = self.rpc.eth.contract(address=self.testContractAddress, abi=self.abiTest)

        self.grantTokens(receipt.contractAddress, 10**5, 10**6)
        self.checkBalances()

        
    def sentTransactionToPool(self):
        filePath =  os.path.abspath('data/10/0x1e60272caDcFb575247a666c11DBEA146299A2c4/transactions.json')
        data = None
        with open(filePath, 'r') as file:
            data = json.load(file)
        data = sorted(data, key=lambda x: x["block"])
        batch = 10
        for step in range(len(data)//batch):
            formatted_transactions = [
                {
                    "typeTransaction": tx["typeTransaction"],
                    "amount0": int(tx["amount0"]),
                    "amount1": int(tx["amount1"]),
                    "block": tx["block"],
                    "liquidity": int(tx["liquidity"]),
                    "tickLower": tx["tickLower"],
                    "tickUpper": tx["tickUpper"],
                    "txHash": Web3.to_bytes(hexstr=tx["txHash"])
                }
                for tx in data[step*batch:(step+1)*batch]
            ]
            print(f"send {step}-th batch")
            #for d in data[step*batch:(step+1)*batch]:
            #    print(d["block"], d["typeTransaction"], d["txHash"])
                
            tx_data = self.testContract.functions.poolTransaction(formatted_transactions).build_transaction({
                'chainId': 10,
                'gas': 30000000,
                'gasPrice': self.rpc.eth.gas_price,
                'nonce': self.rpc.eth.get_transaction_count(self.account),
            })
            # Sign and send transaction
            signed_tx = self.rpc.eth.account.sign_transaction(tx_data, self.private_key)
            tx_hash = self.rpc.eth.send_raw_transaction(signed_tx.rawTransaction)

            # Optionally wait for the transaction receipt
            receipt = self.rpc.eth.wait_for_transaction_receipt(tx_hash)
            print(f"finish {step}-th batch with status {receipt.status}\n")

    def checkBalances(self):
        data = self.testContract.encodeABI(fn_name='setUp')
        tx_data = {
            'chainId': 10,
            'gas': 30000000,
            'to': self.testContractAddress,
            'data': data,
            'nonce': self.rpc.eth.get_transaction_count(self.account),
            'gasPrice': self.rpc.eth.gas_price,
        }

        # Sign and send transaction
        signed_tx = self.rpc.eth.account.sign_transaction(tx_data, self.private_key)
        tx_hash = self.rpc.eth.send_raw_transaction(signed_tx.rawTransaction)

        # Optionally wait for the transaction receipt
        receipt = self.rpc.eth.wait_for_transaction_receipt(tx_hash)
time.sleep(3)
swapLogLoader = HistoryTest('10', "velodrome", "0x1e60272caDcFb575247a666c11DBEA146299A2c4", 117069418)