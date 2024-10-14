from dotenv import load_dotenv
import json
import os
import sys
import time
import subprocess
from web3 import Web3
from odos import Odos, PulseVeloBotLazySwapData
from eth_account import Account
from decimal import Decimal, getcontext

load_dotenv()
getcontext().prec = 50

ON_CHAIN = False

Q96 = Decimal('79228162514264337593543950336')

MAX_RETRY_REBALANCE = 5

CHAIN_ID = os.environ.get("CHAIN_ID")
ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'
BOT_ADDRESS = '0xa809DA0D3fa492A75BA1c8b11601A382a43457cC' #os.environ.get("BOT_ADDRESS")
CORE_ADDRESS = '0xd17613D91150a2345eCe9598D055C7197A1f5A71' #os.environ.get("CORE_ADDRESS")
DEPLOY_FACTORY_ADDRESS = '0x5B1b1aaC71bDca9Ed1dCb2AA357f678584db4029' #os.environ.get("DEPLOY_FACTORY_ADDRESS")

REBALANCE_ACTION_STRING = 'r'
DISTRIBUTION_REWARD_ACTION_STRING = 'd'

PIPS_DENOMINATOR = 10000
SLIPPAGE_PIPS = 10 # 10/10000 = 0.1%
DIFF_STEP = 0.01/100

POOLS = [
    '0x4e829F8A5213c42535AB84AA40BD4aDCCE9cBa02',
    '0xaFB62448929664Bfccb0aAe22f232520e765bA88',
    '0x82321f3BEB69f503380D6B233857d5C43562e2D0',
    '0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59',
    '0x4D69971CCd4A636c403a3C1B00c85e99bB9B5606',
    '0x9785eF59E2b499fB741674ecf6fAF912Df7b3C1b',
    '0xE846373C1a92B167b4E9cd5d8E4d6B1Db9E90EC7',
    '0x861A2922bE165a5Bd41b1E482B49216b465e1B5F',
    '0x2ae9DF02539887d4EbcE0230168a302d34784c82',
    '0xdE5Ff829fEF54d1BdEc957D9538A306f0EAD1368',
    '0x988702fe529a3461ec7Fd09Eea3f962856709FD9',
    '0x47cA96Ea59C13F72745928887f84C9F52C3D7348',
    '0xDC7EAd706795eDa3FEDa08Ad519d9452BAdF2C0d',
    '0x70aCDF2Ad0bf2402C957154f944c19Ef4e1cbAE1',
    '0x4e962BB3889Bf030368F56810A9c96B83CB3E778',
]


def contains_substring(file_path, substring):
    with open(file_path, 'r') as file:
        file_content = file.read()
        return substring in file_content
    
class Operator:
    def __init__(self):
        infura_url = os.environ.get("BASE_DRPC")
        self.rpc = Web3(Web3.HTTPProvider(infura_url))

        if self.rpc.is_connected():
            print("Connected to Base node")
        else:
            print(f"Connection failed {infura_url}")

        # load bot ABI
        with open("./abi/PulseVeloBotLazy.json") as f:
            self.bot_abi = json.load(f)

        # load factory ABI
        with open("./abi/VeloDeployFactory.json") as f:
            self.factory_abi = json.load(f)

        # load compounder ABI
        with open("./abi/Compounder.json") as f:
            self.compounder_abi = json.load(f)

        # init bot contract
        self.bot = self.rpc.eth.contract(address=BOT_ADDRESS, abi=self.bot_abi)

        # init factory contract
        self.factory = self.rpc.eth.contract(address=DEPLOY_FACTORY_ADDRESS, abi=self.factory_abi)

        # init Odos quoter to obtain swap data
        self.odos = Odos(BOT_ADDRESS)

    def __get_swap_data(self, swapInfo) -> PulseVeloBotLazySwapData:
        tokenIn = swapInfo[0]
        tokenOut = swapInfo[1]
        amountIn = swapInfo[2]
        quote = self.odos.quote(CHAIN_ID, tokenIn, tokenOut, amountIn)
        if quote.path_id == '':
            print(f"odos qoute {quote} error at input {swapInfo}")
        # swap specific swap data including 'to' and 'callData'
        return self.odos.swap(quote.path_id)

    """ 
        1. method asks bool array of positions that should be rebalanced
        2. asks amounts for swap
        3. write to .json swap data array
    """
    def rebalance(self):

        print("Start rebalance action")

        for pool in POOLS:
            needRebalance = self.bot.functions.needRebalancePosition(pool).call()

            pulseVeloBotLazySwapData = None
            result = False
            tries = 0

            print(f"pool {pool} needs rebalance: {needRebalance}")
            if needRebalance:
                swapInfo = self.bot.functions.necessarySwapAmountForMint(pool, 0).call()
                tokenIn = swapInfo[0]
                tokenOut = swapInfo[1]
                amountIn = swapInfo[2]
                print(pool, "swapInfo", swapInfo)

                while not result and tries <= MAX_RETRY_REBALANCE:
                    if tokenIn != ZERO_ADDRESS and tokenOut != ZERO_ADDRESS and amountIn > 0:
                        try:
                            swapData = self.__get_swap_data(swapInfo)
                            expectedAmountOut = int(swapData[1].expectedAmount)

                            priceX96 = (Q96 * Decimal(expectedAmountOut))/Decimal(amountIn)

                            swapInfo = self.bot.functions.necessarySwapAmountForMint(pool, int(priceX96)).call()
                            print(pool, "swapInfo", swapInfo)

                            swapData = self.__get_swap_data(swapInfo)
                            amountIn = swapInfo[2]

                            pulseVeloBotLazySwapData = PulseVeloBotLazySwapData(
                                    pool=pool,
                                    tokenIn=tokenIn, 
                                    tokenOut=tokenOut, 
                                    amountIn=amountIn, 
                                    expectedAmountOut=expectedAmountOut,
                                    router=swapData[1].to, 
                                    callData=swapData[1].data)

                            print(pulseVeloBotLazySwapData)
                        except Exception as e:
                            print("error during quoting", e)
                            continue

                    else:
                        pulseVeloBotLazySwapData = PulseVeloBotLazySwapData(
                                pool=pool,
                                tokenIn=ZERO_ADDRESS, 
                                tokenOut=ZERO_ADDRESS, 
                                amountIn=0,
                                expectedAmountOut=0,
                                router=ZERO_ADDRESS, 
                                callData='0x')
                        
                    # run solidity rebalance script that reads swap data and do rebalance on-chain
                    result = self.__runForgeScript(pulseVeloBotLazySwapData)

                    tries += 1

    """
        Make distribution of rewards
    """
    def distribute_rewards(self):

        print("Start distribution rewards action")

        subfolder = "logs"
        os.makedirs(subfolder, exist_ok=True)
        log_path = os.path.join(subfolder, "distribute_rewards.log")

        try:
            # get compounder address
            mutableParams = self.factory.functions.getMutableParams().call()
            farmOperator = mutableParams[3]
            print("Farm Operator", farmOperator)

            # init factory contract
            self.compounder = self.rpc.eth.contract(address=farmOperator, abi=self.compounder_abi)

            private_key = os.environ.get("OPERATOR_PRIVATE_KEY")

            account = Account.from_key(private_key)
            operator_address = account.address

            print("EOA Operator address", operator_address)

        except Exception as e:
            with open(log_path, 'w') as log_file:
                log_file.write(f"{e}")
            print("error during transaction preparing", e)
            return

        try:
            transaction = self.compounder.functions.compound(DEPLOY_FACTORY_ADDRESS, POOLS).build_transaction({
                'from': operator_address,
                'nonce': self.rpc.eth.get_transaction_count(operator_address),
                'gasPrice': self.rpc.eth.gas_price,
                'chainId': CHAIN_ID
            })

            signed_tx = self.rpc.eth.account.sign_transaction(transaction, private_key=private_key)

            tx_hash = self.rpc.eth.send_raw_transaction(signed_tx.rawTransaction)

            receipt = self.rpc.eth.wait_for_transaction_receipt(tx_hash)
        except Exception as e:
            with open(log_path, 'w') as log_file:
                log_file.write(f"{e}")
            print("transaction fails", e)
            return
        finally:
            print("Rewards were distributed successfully!")
            with open(log_path, 'w') as log_file:
                log_file.write(f"tx_hash:  {tx_hash.hex()}\n {receipt}")

    """
        runs forge script to rebalance with swap data
        logs are saved to debug and check 
    """
    def __runForgeScript(self, pulseVeloBotLazySwapData):
        try:
            with open("../../bots/pulseVeloBotLazySwapData.json", 'w') as file:
                json.dump(pulseVeloBotLazySwapData.toDict(), file, indent=4)

            subfolder = "logs"
            os.makedirs(subfolder, exist_ok=True)
            log_path = os.path.join(subfolder, str(pulseVeloBotLazySwapData.pool) + ".log")

            # test run on fork
            command = [
                'forge', 'script', '../../bots/PulseVeloBotLazy.s.sol',
                '--rpc-url', os.environ.get("BASE_DRPC"),
                '-vvvvv'
            ]

            # on-chain run
            if ON_CHAIN:
                command.append('--broadcast')
                command.append('--slow')

            with open(log_path, 'w') as log_file:
                result = subprocess.run(command, stdout=log_file, text=True)          

            print(f"see the transaction logs at {subfolder} folder")

            return contains_substring(log_path, "rebalance is successfull for")
        except Exception as e:
            print("error during running forge", e)
            return False

    def action(self):
        
        if len(sys.argv) < 2:
            print(f"Usage: python operator.py [action]\n\
            `{REBALANCE_ACTION_STRING}`: checks and does rebalance for all strategies\n\
            `{DISTRIBUTION_REWARD_ACTION_STRING}`: distributes rewards")
            sys.exit(1)
        
        action_string = sys.argv[1]
        if action_string == REBALANCE_ACTION_STRING:
            self.rebalance()
        elif action_string == DISTRIBUTION_REWARD_ACTION_STRING:
            self.distribute_rewards()
        else:
            print("Error: undefined action")

while True:
    bot = Operator()
    bot.action()
    print("Sleep for an hour")
    time.sleep(3600)
