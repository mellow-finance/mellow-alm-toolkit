
import pandas as pd
import matplotlib.pyplot as plt
import glob
import os

POOL = '0x3241738149B24C9164dA14Fa2040159FFC6Dd237'

def plot_fee1_vs_step():

    file_pattern =  os.path.abspath('test/backtest/data/10/'+POOL+'/result/')
    file_pattern += '/strategy*.csv'
    print(file_pattern)
    files = glob.glob(file_pattern)
    
    plt.figure(figsize=(100, 60))
    
    for file in files:
        data = pd.read_csv(file)
        plt.plot(data['step'], data['fee1'], label=file)
    
    plt.xlabel('Step', fontsize=16)
    plt.ylabel('Fee', fontsize=16)
    plt.title('Fee1 vs Step for different position width')
    plt.grid(True)
    plt.show()
    
plot_fee1_vs_step()