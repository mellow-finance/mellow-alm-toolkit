import loader as L
import csv
import os
import math
from decimal import Decimal, getcontext
getcontext().prec = 50

import pandas as pd
import position as P
import oracle as O

LAZY_SYNCING = "lazy_syncing"
LAZY_ASCENDING = "lazy_ascending"
LAZY_DESCENDING = "lazy_descending"
TAMPER_SENSITIVE = "tamper_high" # 5%
TAMPER_MEDIUM = "tamper_medium"  # 25%
TAMPER_LOW = "tamper_low" #50%

MAX_LIQUIDITY_DEVIATION_RATIO = {
    TAMPER_SENSITIVE: 0.05,
    TAMPER_MEDIUM: 0.25,
    TAMPER_LOW: 0.50
}

class Simulator:
    def __init__(self, pool, sub_type, cool_down):
        self.loader = L.SwapLogLoader(pool)
        self.tickSpacing = self.loader.tickSpacing
        self.fee = Decimal(self.loader.fee)
        self.decimals0 = self.loader.decimals0
        self.decimals1 = self.loader.decimals1
        self.sub_type = sub_type
        self.cool_down = cool_down
        
    def createCsvWriter(self, width):
        path = self.loader.path + "/" + self.sub_type + "/" + str(self.cool_down//L.ONE_MINUTE)
        os.makedirs(path, exist_ok=True)
        csvFileResult = open(path + "/" + str(width)+"_result.csv", 'w')
        csvWriter = csv.writer(csvFileResult)
        csvWriter.writerow(['block', 'tick', 'tickLower', 'tickUpper', 'price', 'liquidity', 'amount0', 'amount1', 'fee0', 'fee1', 'cost0', 'cost1', 'activity'])
        return csvWriter, csvFileResult
        