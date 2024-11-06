import json
import requests
from typing import List, Dict, Union
from dataclasses import dataclass, asdict
from hexbytes import HexBytes

@dataclass
class InputToken:
    amount: int
    tokenAddress: str

@dataclass
class OutputToken:
    proportion: int
    tokenAddress: str

@dataclass
class OdosQuoteData:
    chainId: int
    compact: bool
    gasPrice: float
    inputTokens: List[InputToken]
    outputTokens: List[OutputToken]
    referralCode: int
    slippageLimitPercent: float
    sourceBlacklist: List[str]
    sourceWhitelist: List[str]
    userAddr: str

@dataclass
class OdosQuoteResponse:
    inTokens: List[str]
    outTokens: List[str]
    inAmounts: List[str]
    outAmounts: List[str]
    gasEstimate: float
    dataGasEstimate: int
    gweiPerGas: float
    gasEstimateValue: float
    inValues: List[float]
    outValues: List[float]
    netOutValue: float
    priceImpact: float
    percentDiff: float
    partnerFeePercent: float
    pathId: str
    pathViz: Union[str, None]
    blockNumber: int

@dataclass
class QuoteResult:
    router: str
    path_id: str
    amount_out: int
    error: Union[Exception, None]

@dataclass
class TransactionDetails:
    gas: int
    gasPrice: int
    value: str
    to: str
    fromAddr: str
    data: str
    nonce: int
    chainId: int
    expectedAmount: int

@dataclass
class SimulationError:
    type: str
    errorMessage: str

@dataclass
class SimulationDetails:
    isSuccess: bool
    amountsOut: List[int]
    gasEstimate: int
    simulationError: SimulationError

@dataclass
class OdosSwapData:
    deprecated: str
    blockNumber: int
    gasEstimate: int
    gasEstimateValue: float
    inputTokens: List[InputToken]
    outputTokens: List[InputToken]
    netOutValue: float
    outValues: List[str]
    transaction: TransactionDetails
    simulation: SimulationDetails

@dataclass
class PulseVeloBotLazySwapData:
    amountIn: int
    callData: str
    expectedAmountOut: int
    pool: str
    router: str
    tokenIn: str
    tokenOut: str

    def toDict(self):
        return {key: (value.hex() if isinstance(value, HexBytes) else value) 
                for key, value in self.__dict__.items() if not key.startswith('_')}

class Odos:
    def __init__(self, wallet):
        self.wallet = wallet
        self.odos_endpoint = "https://api.odos.xyz/"
        self.odos_quote_path = "https://api.odos.xyz/sor/quote/v2"
        self.odos_swap_path = "https://api.odos.xyz/sor/assemble"

    def quote(self, chain_id, token_in: int, token_out: str, amount_in: int) -> QuoteResult:
        quote_data = OdosQuoteData(
            chainId=chain_id,
            compact=False,
            gasPrice=0.0125,
            inputTokens=[InputToken(amount=str(amount_in), tokenAddress=token_in)],
            outputTokens=[OutputToken(proportion=1, tokenAddress=token_out)],
            referralCode=0,
            slippageLimitPercent=0.1,
            sourceBlacklist=[],#["Velodrome Slipstream"],
            sourceWhitelist=[],
            userAddr=self.wallet,
        )
        try:
            json_data = json.dumps(asdict(quote_data))
            response = requests.post(self.odos_quote_path, headers={"accept": "application/json", "Content-Type": "application/json"}, data=json_data)
            response.raise_for_status()
            response_data = response.json()
            response_obj = OdosQuoteResponse(**response_data)

            amount_out = int(response_obj.outAmounts[0])
            return QuoteResult(router="OdosRouter", path_id=response_obj.pathId, amount_out=amount_out, error=None)
        except Exception as e:
            print(quote_data)
            return QuoteResult(router="", path_id="", amount_out=0, error=e)

    def swap(self, path_id: str):
        swap_data = {"pathId": path_id, "simulate": False, "userAddr": self.wallet}

        try:
            json_data = json.dumps(swap_data)
            response = requests.post(self.odos_swap_path, headers={"accept": "application/json", "Content-Type": "application/json"}, data=json_data)
            response.raise_for_status()
            response_data = response.json()
            response_obj = OdosSwapData(**response_data)

            if response_obj.simulation is not None:
                if not response_obj.simulation['isSuccess']:
                    raise Exception(f"Simulation error: {response_obj.simulation['simulationError']}")
            transaction = TransactionDetails(
                gas=response_obj.transaction['gas'],
                gasPrice=response_obj.transaction['gasPrice'],
                value=response_obj.transaction['value'],
                to=response_obj.transaction['to'],
                fromAddr=response_obj.transaction['from'],
                data=response_obj.transaction['data'],
                nonce=response_obj.transaction['nonce'],
                chainId=response_obj.transaction['chainId'],
                expectedAmount=response_obj.outputTokens[0]['amount']
            )
            amount_out = int(response_obj.outputTokens[0]['amount'])
            return amount_out, transaction, None
        except Exception as e:
            return None, None, e
