from multiprocessing import Pool
import lazy_simulator as S
import tamper_simulator as T
import loader as L

lazy_simulator = None
tamper_simulator = None

def update_historical_data(pool):
    loader = L.SwapLogLoader(pool)
    loader.loadSwaps()

def initialize_lazy_simulator(pool_name):
    global lazy_simulator
    if lazy_simulator is None:
        pool = L.POOLS[pool_name]
        update_historical_data(pool)
        lazy_simulator = S.LazySimulator(pool)

def initialize_tamper_simulator(pool_name):
    global tamper_simulator
    if tamper_simulator is None:
        pool = L.POOLS[pool_name]
        update_historical_data(pool)
        tamper_simulator = T.TamperSimulator(L.POOLS[pool_name])

def run_lazy_simulation(N):
    return lazy_simulator.simulate(N, update=False)

def run_tamper_simulation(N):
    return tamper_simulator.simulate(N, update=False)

# Tamper
def tamper(pool_name, width):
    print("run Tamper simulator for the pool", L.POOLS[pool_name])
    initialize_tamper_simulator(pool_name)
    with Pool(processes=min(32, len(width))) as pool: 
        results = pool.map(run_tamper_simulation, width)

# Lazy
def lazy(pool_name, width):
    print("run Lazy simulator for the pool", L.POOLS[pool_name])
    initialize_lazy_simulator(pool_name)
    with Pool(processes=min(32, len(width))) as pool:
        results = pool.map(run_lazy_simulation, width)

def debug_tamper(pool_name, width):
    print("run tamper simulator for the pool", L.POOLS[pool_name])
    initialize_tamper_simulator(pool_name)
    run_tamper_simulation(width)

def debug_lazy(pool_name, width):
    print("run Lazy simulator for the pool", L.POOLS[pool_name])
    initialize_lazy_simulator(pool_name)
    run_lazy_simulation(width)

if __name__ == "__main__":
    # velodrome pools
    lazy('USDC-WETH_OPT', list(range(1000, 1001, 1000)))
    #tamper('WSTETH-WETH_OPT', list(range(20, 341, 40)))
    #lazy('WETH-OP_OPT', list(range(1000, 8001, 1000)))

    # aerodrome pools
    #lazy('WETH-USDC_BASE', list(range(1000, 8001, 1000)))
    #tamper('WETH-WSTETH_BASE', list(range(20, 341, 40)))
    #tamper('EURC-USDC_BASE', list(range(20, 341, 40)))
    #lazy('WETH-CBBTC_BASE', list(range(1000, 8001, 1000)))
