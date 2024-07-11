from dotenv import load_dotenv
import json
import os
import subprocess
from web3 import Web3
from odos import Odos, PulseVeloBotLazySwapData

load_dotenv()
CHAIN_ID = 10
ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'
VELO_BOT_ADDRESS = '0xd5823002f1D34e68B47AAce5551d6A76E6379d5c'

class Operator:
    def __init__(self):
        infura_url = os.environ.get("OPTIMISM_RPC")
        self.rpc = Web3(Web3.HTTPProvider(infura_url))

        if self.rpc.is_connected():
            print("Connected to Optimism node")
        else:
            print("Connection failed")

        # load bot ABI
        with open("./abi/PulseVeloBotLazy.json") as f:
            self.bot_abi = json.load(f)

        # init bot contract
        self.bot = self.rpc.eth.contract(address=VELO_BOT_ADDRESS, abi=self.bot_abi)

        # init Odos quoter to obtain swap data
        self.odos = Odos(VELO_BOT_ADDRESS)

    """ 
        1. method asks bool array of posisions that should be rebalanced
        2. asks amounts for swap
        3. write to .json swap data array
    """
    def rebalance(self):
        # obtain desired swap amount to have ability to mint positions
        needRebalances = self.bot.functions.needRebalance().call()

        for i, needRebalance in enumerate(needRebalances):
            pulseVeloBotLazySwapData = []
            if needRebalance:
                swapInfo = self.bot.functions.necessarySwapAmountForMint(i).call()
   
                tokenIn = swapInfo[0]
                tokenOut = swapInfo[1]
                amountIn = swapInfo[2]
                if tokenIn != ZERO_ADDRESS and tokenOut != ZERO_ADDRESS and amountIn > 0:
                    try:
                        # quote shallow swap data
                        quote = self.odos.quote(10, tokenIn, tokenOut, amountIn)
                        # swap specific swap data including 'to' and 'callData'
                        swapData = self.odos.swap(quote.path_id)
                        pulseVeloBotLazySwapData.append( 
                            PulseVeloBotLazySwapData(
                                positionId=i,
                                tokenIn=tokenIn, 
                                tokenOut=tokenOut, 
                                amountIn=amountIn, 
                                expectedAmountOut=int(swapData[1].expectedAmount),
                                router=swapData[1].to, 
                                callData=swapData[1].data)
                        )
                        print(pulseVeloBotLazySwapData)
                    except Exception as e:
                        print("error during quoting", e)
                else:
                    pulseVeloBotLazySwapData.append(
                        PulseVeloBotLazySwapData(
                            positionId=i,
                            tokenIn=ZERO_ADDRESS, 
                            tokenOut=ZERO_ADDRESS, 
                            amountIn=0,
                            expectedAmountOut=0,
                            router=ZERO_ADDRESS, 
                            callData='0x')
                        )

                # run solidity rebalance script that reads swap data and do rebalance on-chain
                self.__runForgeScript(pulseVeloBotLazySwapData)

    """
        runs forge script to rebalance with swap data
        logs are saved to dedug and check 
    """
    def __runForgeScript(self, pulseVeloBotLazySwapData):

        # write obtained swap data into json
        data = [instance.toDict() for instance in pulseVeloBotLazySwapData]
        with open("pulseVeloBotLazySwapData.json", 'w') as file:
            json.dump(data, file, indent=4)

        subfolder = "logs"
        os.makedirs(subfolder, exist_ok=True)
        log_path = os.path.join(subfolder, str(pulseVeloBotLazySwapData[0].positionId) + ".log")

        # test run on fork
        command = [
            'forge', 'script', '../../bots/PulseVeloBotLazy.s.sol',
            '--rpc-url', os.environ.get("OPTIMISM_RPC"),
            '--fork-block-number', '122545420',
            '-vvvvv'
        ]

        # on-chain run
        """ command = [
            'forge', 'script', '../../bots/PulseVeloBotLazy.s.sol',
            '--rpc-url', os.environ.get("OPTIMISM_RPC"),
            '--broadcast',
            '--slow',
            '-vvvvv'
        ] """

        with open(log_path, 'w') as log_file:
            result = subprocess.run(command, stdout=log_file, text=True)
        
        print(f"see the transaction logs at {subfolder} folder")

bot = Operator()
bot.rebalance()