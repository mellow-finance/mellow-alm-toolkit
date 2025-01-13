import os
import math
import pandas as pd
import matplotlib.pyplot as plt
from datetime import datetime, timedelta
import loader as L

ROOT_PATH="../data/"
DAY_SECONDS = 3600 * 24
strategy = L.LAZY_SYNCING
poolName ="WETH-OP_OPT"
days_back = 90 # since today in the past
showInToken = 0

font = {'size'   : 20}

plt.rc('font', **font)

def get_path_pool(pool):
    address = pool[0]
    chain_id = pool[2]
    return ROOT_PATH+str(chain_id)+"/"+address+"/"+strategy

def get_label_price(pool, showInToken):
    if showInToken == 0:
        return pool[4]+"-"+pool[3]
    else:
        return pool[3]+"-"+pool[4]
    
def block_to_datetime(block_column, chain_id):
    reference_block = L.BLOCK_TIMESTAMP[chain_id][0]
    reference_timestamp = L.BLOCK_TIMESTAMP[chain_id][1]
    block_duration = L.BLOCK_DURATION[chain_id]

    date_time = []
    for block_number in block_column:
        time_difference = (block_number//1000 - reference_block) * block_duration
        date_time.append(datetime.fromtimestamp(reference_timestamp + time_difference))
    return date_time

def get_block_daysback(chain_id):
    reference_block = L.BLOCK_TIMESTAMP[chain_id][0]
    reference_timestamp = L.BLOCK_TIMESTAMP[chain_id][1]
    block_duration = L.BLOCK_DURATION[chain_id]
    timestamp_now = datetime.now().timestamp()
    timestamp_back = int(timestamp_now - days_back * DAY_SECONDS)
    return (reference_block + (timestamp_back-reference_timestamp)//block_duration) * 1000

def get_file_name(pool, showInToken):
    file_name = ""
    if pool[2] == L.OPT_CHAIN_ID:
        file_name = "OPT_"
    elif pool[2] == L.BASE_CHAIN_ID:
        file_name = "BASE_"
    show_token = pool[3] if showInToken == 0 else pool[4]

    return file_name + get_label_price(pool, 1)+"_"+strategy+"_"+show_token

pool = L.POOLS[poolName]
chain_id = pool[2]
loader = L.SwapLogLoader(pool)
folder_path = get_path_pool(pool)
csv_files = [file for file in os.listdir(folder_path) if file.endswith("_result.csv")]
csv_files.sort(key=lambda x: int(''.join(filter(str.isdigit, x)) or 0))

fig, ax1 = plt.subplots(figsize=(32, 18))

ax2 = ax1.twinx()

# fields ['block', 'tick', 'tickLower', 'tickUpper', 'price', 'liquidity', 'amount0', 'amount1', 'fee0', 'fee1', 'cost0', 'cost1']
for file in csv_files:
    file_path = os.path.join(folder_path, file)
    try:
        data = pd.read_csv(file_path)
        data = data.loc[data["block"] >= get_block_daysback(chain_id)]

        date_time = block_to_datetime(data["block"], chain_id)
        cost_column = data["cost0"] if showInToken == 0 else data["cost1"]
        initial_value =  cost_column.iloc[0]

        if "block" in data.columns and "cost0" in data.columns and "cost1" in data.columns:
            label = ''.join(filter(str.isdigit, file.split('_result.csv')[0]))
            ax1.plot(date_time, (cost_column/initial_value - 1.0)*100, label=f"{label}",linewidth=1.0)
            
        else:
            print(f"Skipping {file}: Required columns not found.")
    except Exception as e:
        print(f"Error processing {file}: {e}")

ax1.set_title("Total cost in " + pool[3+showInToken] + " for different position width and price " + get_label_price(pool, showInToken))
ax1.set_xlabel("Block")
ax1.set_ylabel("Total cost in " + pool[3+showInToken] + ", change in %")
ax1.legend(loc="upper left")
ax1.grid(True)

data = data.loc[data["block"] >= get_block_daysback(chain_id)]
date_time = block_to_datetime(data["block"], pool[2])
price_column = 1/data["price"] if showInToken == 0 else data["price"]
ax2.plot(date_time, price_column, color='black', linewidth=1.0, linestyle='dashed' ,label=get_label_price(pool, showInToken))

ax2.set_ylabel("Price "+ get_label_price(pool, showInToken))
ax2.legend(loc="best")

plt.savefig(ROOT_PATH+"img/"+get_file_name(pool, showInToken)+".png", dpi=300, bbox_inches='tight')  # Save as PNG with 300 DPI
plt.tight_layout()
plt.show()
