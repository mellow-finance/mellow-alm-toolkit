from dotenv import load_dotenv
import json
import os
import subprocess
from web3 import Web3
from odos import Odos, PulseVeloBotLazySwapData

load_dotenv()
CHAIN_ID = 10
ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'
VELO_BOT_ADDRESS = '0xB3dDa916420774efaD6C5cf1a7b55CDCdC245f04'
VELO_CORE_ADDRESS = '0x8CBA3833ad114b4021734357D9383F4DBD69638F'
POSTION_COUNT = 11 # count of actual managed position 

class Operator:
    def __init__(self):
        infura_url = os.environ.get("OPTIMISM_RPC")
        self.rpc = Web3(Web3.HTTPProvider(infura_url))

        if self.rpc.is_connected():
            print("Connected to Optimism node")
        else:
            print("Connection failed")

        # load core ABI
        with open("./abi/Core.json") as f:
            self.core_abi = json.load(f)

        # load bot ABI
        with open("./abi/PulseVeloBotLazy.json") as f:
            self.bot_abi = json.load(f)

        # init bot contract
        self.bot = self.rpc.eth.contract(address=VELO_BOT_ADDRESS, abi=self.bot_abi)

        # init core contract
        self.core = self.rpc.eth.contract(address=VELO_CORE_ADDRESS, abi=self.core_abi)

        # init Odos quoter to obtain swap data
        self.odos = Odos(VELO_BOT_ADDRESS)

    def get_managed_positions(self):
        managed_position_ids = []
        max_position_id = self.core.functions.positionCount().call()
        for position_id in range(max_position_id-1, 0, -1):
            position = self.core.functions.managedPositionAt(position_id).call()
            if position[0] > 0:
                managed_position_ids.append(position_id)
            if len(managed_position_ids) == POSTION_COUNT:
                break

        return managed_position_ids

    """ 
        1. method asks bool array of posisions that should be rebalanced
        2. asks amounts for swap
        3. write to .json swap data array
    """
    def rebalance(self):
        # retrive ids of actually managed positions
        managed_position_ids = self.get_managed_positions()
        print(managed_position_ids)

        # obtain desired swap amount to have ability to mint positions
        needRebalances = self.bot.functions.needRebalance(managed_position_ids).call()
        print("needRebalances", needRebalances)

        for i, needRebalance in enumerate(needRebalances):
            pulseVeloBotLazySwapData = None
            if needRebalance:
                swapInfo = self.bot.functions.necessarySwapAmountForMint(managed_position_ids[i]).call()
                tokenIn = swapInfo[0]
                tokenOut = swapInfo[1]
                amountIn = swapInfo[2]
                print(managed_position_ids[i], "swapInfo", swapInfo)
                if tokenIn != ZERO_ADDRESS and tokenOut != ZERO_ADDRESS and amountIn > 0:
                    try:
                        # quote shallow swap data
                        quote = self.odos.quote(CHAIN_ID, tokenIn, tokenOut, amountIn)
                        if quote.path_id == '':
                            raise(BaseException(f"odos qoute {quote} error at input {swapInfo}"))
                        # swap specific swap data including 'to' and 'callData'
                        swapData = self.odos.swap(quote.path_id)
                        print(swapData)
                        pulseVeloBotLazySwapData = PulseVeloBotLazySwapData(
                                positionId=managed_position_ids[i],
                                tokenIn=tokenIn, 
                                tokenOut=tokenOut, 
                                amountIn=amountIn, 
                                expectedAmountOut=int(swapData[1].expectedAmount),
                                router=swapData[1].to, 
                                callData=swapData[1].data)

                        print(pulseVeloBotLazySwapData)
                    except Exception as e:
                        print("error during quoting", e)
                        continue
                else:
                    pulseVeloBotLazySwapData = PulseVeloBotLazySwapData(
                            positionId=managed_position_ids[i],
                            tokenIn=ZERO_ADDRESS, 
                            tokenOut=ZERO_ADDRESS, 
                            amountIn=0,
                            expectedAmountOut=0,
                            router=ZERO_ADDRESS, 
                            callData='0x')

                # run solidity rebalance script that reads swap data and do rebalance on-chain
                self.__runForgeScript(pulseVeloBotLazySwapData)

    """
        runs forge script to rebalance with swap data
        logs are saved to dedug and check 
    """
    def __runForgeScript(self, pulseVeloBotLazySwapData):
 
        with open("../../bots/pulseVeloBotLazySwapData.json", 'w') as file:
            json.dump(pulseVeloBotLazySwapData.toDict(), file, indent=4)

        subfolder = "logs"
        os.makedirs(subfolder, exist_ok=True)
        log_path = os.path.join(subfolder, str(pulseVeloBotLazySwapData.positionId) + ".log")

        # test run on fork
        command = [
            'forge', 'script', '../../bots/PulseVeloBotLazy.s.sol',
            '--rpc-url', os.environ.get("OPTIMISM_RPC"),
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