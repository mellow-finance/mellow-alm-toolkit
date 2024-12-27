from multiprocessing import Pool

# Import necessary modules
import lazy_simulator as S
import tamper_simulator as T
import loader as L

# Initialize globally
lazy_simulator = None
tamper_simulator = None

# Define initialization function for the simulator
def initialize_lazy_simulator():
    global lazy_simulator
    if lazy_simulator is None:
        lazy_simulator = S.LazySimulator(L.POOLS['WETH_CBBTC_BASE'])

# Define the function to run the simulation for a given N
def run_lazy_simulation(N):
    global lazy_simulator
    if lazy_simulator is None:
        initialize_lazy_simulator()  # Ensure simulator is initialized in each process
    return lazy_simulator.simulate(N, update=False)

# Define initialization function for the simulator
def initialize_tamper_simulator():
    global tamper_simulator
    if tamper_simulator is None:
        tamper_simulator = T.TamperSimulator(L.POOLS['WETH-WSTETH_BASE'])

# Define the function to run the simulation for a given N
def run_tamper_simulation(N):
    global tamper_simulator
    if lazy_simulator is None:
        initialize_tamper_simulator()  # Ensure simulator is initialized in each process
    return tamper_simulator.simulate(N, update=False)

# Lazy
if __name__ == "__main__":
    initialize_tamper_simulator()
    #run_tamper_simulation(40)
    N_values = [10, 20, 40, 60, 80, 100, 120, 140, 160, 180, 200, 220, 240]
    with Pool(processes=min(16, len(N_values))) as pool: 
        results = pool.map(run_tamper_simulation, N_values)
