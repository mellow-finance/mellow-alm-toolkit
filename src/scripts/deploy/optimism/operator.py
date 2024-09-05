from dotenv import load_dotenv
import json
import os
import subprocess
from web3 import Web3
from odos import Odos, PulseVeloBotLazySwapData

load_dotenv()

ON_CHAIN = True

CHAIN_ID = 10
ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'
VELO_BOT_ADDRESS = '0x9D7C0BdbfEbB9a6a0120F1116D53387156D126ba'
VELO_CORE_ADDRESS = '0x30ce7bB58dd3ea6FbE32645f644462479170e090'
VELO_DEPLOY_FACTORY_ADDRESS = '0xdca5BC88366A58883f2711708Ade7b1E866ecC83'

PIPS_DENOMINATOR = 10000
SLIPPAGE_PIPS = 10 # 10/10000 = 0.1%

POOLS = [
    '0xeBD5311beA1948e1441333976EadCFE5fBda777C',
    '0x4DC22588Ade05C40338a9D95A6da9dCeE68Bcd60', 
    '0x478946BcD4a5a22b316470F5486fAfb928C0bA25', 
    '0x319C0DD36284ac24A6b2beE73929f699b9f48c38', 
    '0xEE1baC98527a9fDd57fcCf967817215B083cE1F0', 
    '0xb71Ac980569540cE38195b38369204ff555C80BE', 
    '0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4', 
    '0x84Ce89B4f6F67E523A81A82f9f2F14D84B726F6B', 
    '0x2FA71491F8070FA644d97b4782dB5734854c0f6F', 
    '0x3C01ec09D15D5450FC702DC4353b17Cd2978d8a5', 
    '0x8Ac2f9daC7a2852D44F3C09634444d533E4C078e', 
]

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

        # load bot ABI
        with open("./abi/VeloDeployFactory.json") as f:
            self.factory_abi = json.load(f)

        # load bot ABI
        with open("./abi/LpWrapper.json") as f:
            self.lpWrapper_abi = json.load(f)

        # init bot contract
        self.bot = self.rpc.eth.contract(address=VELO_BOT_ADDRESS, abi=self.bot_abi)

        # init core contract
        self.core = self.rpc.eth.contract(address=VELO_CORE_ADDRESS, abi=self.core_abi)

        # init factory contract
        self.factory = self.rpc.eth.contract(address=VELO_DEPLOY_FACTORY_ADDRESS, abi=self.factory_abi)

        # init Odos quoter to obtain swap data
        self.odos = Odos(VELO_BOT_ADDRESS)

    """ 
        takes position ids for pool list
    """
    def get_managed_positions(self):
        managed_position_ids = []
        for pool in POOLS:
            poolToAddresses = self.factory.functions.poolToAddresses(pool).call()
            print(pool, "lpWrapperAddres", poolToAddresses[1], "farmAddress", poolToAddresses[0])
            lpWrapperAddress = poolToAddresses[1]
            if lpWrapperAddress != ZERO_ADDRESS:
                lpWrapper = self.rpc.eth.contract(address=lpWrapperAddress, abi=self.lpWrapper_abi)
                position_id = lpWrapper.functions.positionId().call()
                print("lpWrapperAddres", lpWrapperAddress, "position_id", position_id)
                managed_position_ids.append(position_id)

        return managed_position_ids

    """ 
        1. method asks bool array of positions that should be rebalanced
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
                        expectedAmountWithSlippage = int(swapData[1].expectedAmount)
                        
                        expectedAmountWithSlippage = int((PIPS_DENOMINATOR - SLIPPAGE_PIPS)*expectedAmountWithSlippage/PIPS_DENOMINATOR)
                        pulseVeloBotLazySwapData = PulseVeloBotLazySwapData(
                                positionId=managed_position_ids[i],
                                tokenIn=tokenIn, 
                                tokenOut=tokenOut, 
                                amountIn=amountIn, 
                                expectedAmountOut=expectedAmountWithSlippage,
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
        if ON_CHAIN:
            command.append('--broadcast')
            command.append('--slow')

        with open(log_path, 'w') as log_file:
            result = subprocess.run(command, stdout=log_file, text=True)
        
        print(f"see the transaction logs at {subfolder} folder")

bot = Operator()
bot.rebalance()