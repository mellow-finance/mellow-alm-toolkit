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
    global lazy_simulator
    if lazy_simulator is None:
        initialize_lazy_simulator()
    return lazy_simulator.simulate(N, update=False)

def run_tamper_simulation(N):
    global tamper_simulator
    if lazy_simulator is None:
        initialize_tamper_simulator()
    return tamper_simulator.simulate(N, update=False)

# Tamper
def tamper(pool_name):
    print("run Tamper simulator for the pool", L.POOLS[pool_name])
    initialize_tamper_simulator(pool_name)
    N_values = [2, 4, 8, 10, 20, 40, 60, 80, 100, 120, 140, 160, 180, 200, 220, 240, 260, 280, 300, 320]
    with Pool(processes=min(32, len(N_values))) as pool: 
        results = pool.map(run_tamper_simulation, N_values)

# Lazy
def lazy(pool_name):
    print("run Lazy simulator for the pool", L.POOLS[pool_name])
    initialize_lazy_simulator(pool_name)
    N_values = [500, 1000, 1500, 200, 2500, 3000, 4000, 5000, 6000, 7000, 8000]
    with Pool(processes=min(32, len(N_values))) as pool: 
        results = pool.map(run_lazy_simulation, N_values)

if __name__ == "__main__":
    #tamper('EURC-USDC_BASE')
    lazy('USDC-WETH_OPT')
