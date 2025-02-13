from multiprocessing import Pool

import simulator as SIM
import lazy_simulator as LS
import tamper_simulator as TS
import loader as L
import plot as P

# width for backtesting in tickSpacing's of pool
LAZY_LOW_VOLATILE_WIDTH = list([1,2,3,4,6,8,16,24,32,48,56,64,72,80,88,96])
LAZY_HIGH_VOLATILE_WIDTH = list([24,32,48,56,64,72,80,88,96,104,112,128,144,160,176,192])
TAMPER_LOW_VOLATILE_WIDTH = list([2,4,6,8,12,16,24,32,48,64])
TAMPER_HIGH_VOLATILE_WIDTH = list([32,48,64,80,96,112,128,144,160])
COOL_DOWN = list([5,10,15,30])

lazy_simulator = None
tamper_simulator = None

def update_historical_data(pool):
    loader = L.SwapLogLoader(pool)
    loader.loadSwaps()

def initialize_lazy_simulator(pool, sub_type, cool_down):
    global lazy_simulator
    update_historical_data(pool)
    lazy_simulator = LS.LazySimulator(pool, sub_type, cool_down)

def initialize_tamper_simulator(pool, sub_type, cool_down):
    global tamper_simulator
    update_historical_data(pool)
    tamper_simulator = TS.TamperSimulator(pool, sub_type, cool_down)

def run_lazy_simulation(N):
    return lazy_simulator.simulate(N, update=False)

def run_tamper_simulation(N):
    return tamper_simulator.simulate(N, update=False)

# Tamper
def tamper(pool, width, sub_type, cool_down):
    print("run Tamper simulator for the pool", pool, sub_type, cool_down)
    initialize_tamper_simulator(pool, sub_type, cool_down)
    with Pool(processes=min(32, len(width))) as threadPool:
        results = threadPool.map(run_tamper_simulation, width)

# Lazy
def lazy(pool, width, sub_type, cool_down):
    print("run Lazy simulator for the pool", pool, sub_type, cool_down)
    initialize_lazy_simulator(pool, sub_type, cool_down)

    with Pool(processes=min(32, len(width))) as threadPool:
        results = threadPool.map(run_lazy_simulation, width)

def debug_tamper(pool, width, sub_type, cool_down):
    print("run tamper simulator for the pool", pool, sub_type, cool_down)
    initialize_tamper_simulator(pool, sub_type, cool_down)
    run_tamper_simulation(width)

def debug_lazy(pool, width, sub_type, cool_down):
    print("run Lazy simulator for the pool", pool, sub_type, cool_down)
    initialize_lazy_simulator(pool, sub_type, cool_down)
    run_lazy_simulation(width)

def plot_data(pool, strategy, cool_down):
    P.tableTotal(pool, strategy, 0)
    P.tableTotal(pool, strategy, 1)

    P.plot(pool, strategy, cool_down, 0, 180)
    P.plot(pool, strategy, cool_down, 1, 180)

def simulate(pool, strategy, width = None):
    if strategy == SIM.LAZY_ASCENDING or strategy == SIM.LAZY_DESCENDING or strategy == SIM.LAZY_SYNCING:
        width = LAZY_LOW_VOLATILE_WIDTH if width is None else width
        for minute in COOL_DOWN:
            cool_down = L.ONE_MINUTE * minute
            lazy(pool, width, strategy, cool_down)
            plot_data(pool, strategy, cool_down)
    else:
        width = TAMPER_LOW_VOLATILE_WIDTH if width is None else width
        for minute in COOL_DOWN:
            cool_down = L.ONE_MINUTE * minute
            tamper(pool, width, SIM.TAMPER_LOW, cool_down)
            plot_data(pool, SIM.TAMPER_LOW, cool_down)
            tamper(pool, width, SIM.TAMPER_MEDIUM, cool_down)
            plot_data(pool, SIM.TAMPER_MEDIUM, cool_down)
            tamper(pool, width, SIM.TAMPER_SENSITIVE, cool_down)
            plot_data(pool, SIM.TAMPER_SENSITIVE, cool_down)

if __name__ == "__main__":
    #simulate(L.POOLS[L.MODE_CHAIN_ID]['WETH_USDC'], SIM.LAZY_SYNCING, LAZY_HIGH_VOLATILE_WIDTH)
    #simulate(L.POOLS[L.MODE_CHAIN_ID]['WETH_MODE'], SIM.LAZY_SYNCING, LAZY_HIGH_VOLATILE_WIDTH)
    #simulate(L.POOLS[L.MODE_CHAIN_ID]['WETH_XVELO'], SIM.LAZY_SYNCING, LAZY_HIGH_VOLATILE_WIDTH)
    #simulate(L.POOLS[L.MODE_CHAIN_ID]['USDC_USDT'], SIM.TAMPER_LOW, TAMPER_LOW_VOLATILE_WIDTH)
    simulate(L.POOLS[L.MODE_CHAIN_ID]['USDC_USDT'], SIM.TAMPER_LOW, TAMPER_HIGH_VOLATILE_WIDTH)
    exit(1)
   # simulate(L.POOLS[L.OPT_CHAIN_ID]['WETH_VELO'], SIM.LAZY_SYNCING)
   # simulate(L.POOLS[L.OPT_CHAIN_ID]['USDC_wstETH'], SIM.LAZY_SYNCING)
   # simulate(L.POOLS[L.OPT_CHAIN_ID]['WBTC_tBTC'], SIM.LAZY_SYNCING)
   # simulate(L.POOLS[L.BASE_CHAIN_ID]['WETH_AERO'], SIM.LAZY_SYNCING)
    simulate(L.POOLS[L.BASE_CHAIN_ID]['WETH_AIXBT'], SIM.LAZY_SYNCING)
    simulate(L.POOLS[L.OPT_CHAIN_ID]['WETH_rETH'], SIM.TAMPER_LOW)
    simulate(L.POOLS[L.BASE_CHAIN_ID]['cbETH_WETH'], SIM.TAMPER_LOW)
    simulate(L.POOLS[L.OPT_CHAIN_ID]['USDC_sUSD'], SIM.TAMPER_LOW)
    simulate(L.POOLS[L.OPT_CHAIN_ID]['WBTC_tBTC'], SIM.TAMPER_LOW)
    simulate(L.POOLS[L.BASE_CHAIN_ID]['USDC_USDT'], SIM.TAMPER_LOW)
    simulate(L.POOLS[L.OPT_CHAIN_ID]['WETH_BTC'], SIM.LAZY_SYNCING)
    simulate(L.POOLS[L.OPT_CHAIN_ID]['USDC_sUSD'], SIM.LAZY_SYNCING)
    exit(1)

    #simulate(L.POOLS[L.OPT_CHAIN_ID]['WETH_rETH'], SIM.TAMPER)
    #simulate(L.POOLS[L.OPT_CHAIN_ID]['WETH_rETH'], SIM.LAZY_DESCENDING)
    #simulate(L.POOLS[L.OPT_CHAIN_ID]['WSTETH_WETH'], SIM.TAMPER)
    #simulate(L.POOLS[L.OPT_CHAIN_ID]['WSTETH_WETH'], SIM.LAZY_ASCENDING)

    #simulate(L.POOLS[L.BASE_CHAIN_ID]['cbETH_WETH'], SIM.TAMPER)
    #simulate(L.POOLS[L.BASE_CHAIN_ID]['cbETH_WETH'], SIM.LAZY_ASCENDING)
    #simulate(L.POOLS[L.BASE_CHAIN_ID]['USDC_cbBTC'], SIM.LAZY_SYNCING)
    #simulate(L.POOLS[L.BASE_CHAIN_ID]['USDC_USDT'], SIM.LAZY_SYNCING)
    #simulate(L.POOLS[L.BASE_CHAIN_ID]['USDC_USDT'], SIM.TAMPER)
    simulate(L.POOLS[L.BASE_CHAIN_ID]['VIRTUAL_WETH'], SIM.LAZY_SYNCING)
    simulate(L.POOLS[L.BASE_CHAIN_ID]['WETH_VVV'], SIM.LAZY_SYNCING)


    simulate(L.POOLS[L.OPT_CHAIN_ID]['WETH_rETH'], SIM.LAZY_DESCENDING)