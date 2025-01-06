import os
import pandas as pd
import matplotlib.pyplot as plt
import loader as L

def get_path_pool(pool):
    address = pool[0]
    chain_id = pool[2]
    return "../data/"+str(chain_id)+"/"+address

folder_path = get_path_pool(L.POOLS["USDC-WETH_OPT"])
csv_files = [file for file in os.listdir(folder_path) if file.endswith("_result.csv")]
csv_files.sort(key=lambda x: int(''.join(filter(str.isdigit, x)) or 0))
plt.figure(figsize=(12, 8))

for file in csv_files:
    file_path = os.path.join(folder_path, file)
    try:
        data = pd.read_csv(file_path)

        if "block" in data.columns and "IL0_with_fee" in data.columns:
            label = ''.join(filter(str.isdigit, file.split('_result.csv')[0]))
            plt.plot(data["block"], (data["IL0_with_fee"]+data["IL1_with_fee"])/2, label=label)
        else:
            print(f"Skipping {file}: Required columns not found.")
    except Exception as e:
        print(f"Error processing {file}: {e}")

plt.title("Block vs IL+fee")
plt.xlabel("Block")
plt.ylabel("IL_with_fee")
plt.legend(loc="best")
plt.grid(True)

plt.tight_layout()
plt.show()
