from dotenv import load_dotenv
import json
import os
import subprocess
from web3 import Web3
from odos import Odos, PulseVeloBotLazySwapData

load_dotenv()
CHAIN_ID = 10
ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'
VELO_BOT_ADDRESS = '0x71431c910dE11b7412674728884E301D0e444242'

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

    def rebalance(self):
        # obtain desired swap amount to have ability to mint positions
        swapInfo = self.bot.functions.necessarySwapAmountForMint().call()
        pulseVeloBotLazySwapData = []
        for swap in swapInfo:
            tokenIn = swap[0]
            tokenOut = swap[1]
            amountIn = swap[2]
            if tokenIn != ZERO_ADDRESS and tokenOut != ZERO_ADDRESS and amountIn > 0:
                try:
                    # quote shallow swap data
                    quote = self.odos.quote(10, tokenIn, tokenOut, amountIn)
                    # swap specific swap data including 'to' and 'callData'
                    swapData = self.odos.swap(quote.path_id)
                    pulseVeloBotLazySwapData.append( 
                        PulseVeloBotLazySwapData(
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
                        tokenIn=ZERO_ADDRESS, 
                        tokenOut=ZERO_ADDRESS, 
                        amountIn=0,
                        expectedAmountOut=0,
                        router=ZERO_ADDRESS, 
                        callData='0x')
                    )
        
        # write obtained swap data into json
        data = [instance.toDict() for instance in pulseVeloBotLazySwapData]
        with open("pulseVeloBotLazySwapData.json", 'w') as file:
            json.dump(data, file, indent=4)

        # run solidity rebalance script that reads swap data and do rebalance on-chain
        self.__runForgeScript()
        
    def __runForgeScript(self):
        """ command = [
            'forge', 'script', '../../bots/PulseVeloBotLazy.s.sol',
            '--rpc-url', os.environ.get("OPTIMISM_RPC"),
            '--fork-block-number', '122505158',
            '-vvvvv'
        ] """
        command = [
            'forge', 'script', '../../bots/PulseVeloBotLazy.s.sol',
            '--rpc-url', os.environ.get("OPTIMISM_RPC"),
            '--broadcast',
            '--slow',
            '-vvvvv'
        ]

        # Run the command
        result = subprocess.run(command, capture_output=True, text=True)
        print(result.stdout)
        print(result.stderr)

bot = Operator()
bot.rebalance()