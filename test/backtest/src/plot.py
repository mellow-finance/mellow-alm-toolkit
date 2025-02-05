import os
import math
import pandas as pd
import matplotlib.pyplot as plt
from datetime import datetime, timedelta
import loader as L
import csv

ROOT_PATH="../data/"
DAY_SECONDS = 3600 * 24
LINE_WIDTH = 2.0

font = {'size'   : 20}

plt.rc('font', **font)

class PlotStrategyResult():
    def __init__(self, pool, strategy, cool_down, showInToken, daysBack):
        self.pool = pool
        self.strategy = strategy
        self.cool_down = cool_down
        self.showInToken = showInToken
        self.daysBack = daysBack

        self.chain_id = str(self.pool["chainId"])
        self.address = pool["address"]
        self.token0 = pool["token0"]
        self.token1 = pool["token1"]
        
        self.pathImg = ROOT_PATH+"img/"+str(self.chain_id)+"/"+self.token0+"-"+self.token1+"/"
        os.makedirs(self.pathImg, exist_ok=True)

        self.pathData = ROOT_PATH+str(self.chain_id)+"/"+self.address+"/"+self.strategy+"/"+str(self.cool_down//L.ONE_MINUTE)
        self.csv_files = [file for file in os.listdir(self.pathData) if file.endswith("_result.csv")]
        self.csv_files.sort(key=lambda x: int(''.join(filter(str.isdigit, x)) or 0))

    def get_label_price(self):
        if self.showInToken == 0:
            return self.token1+"-"+self.token0
        else:
            return self.token0+"-"+self.token1
        
    def block_to_datetime(self, block_column):
        reference_block = L.BLOCK_TIMESTAMP[self.chain_id][0]
        reference_timestamp = L.BLOCK_TIMESTAMP[self.chain_id][1]
        block_duration = L.BLOCK_DURATION[self.chain_id]

        date_time = []
        for block_number in block_column:
            time_difference = (block_number//1000 - reference_block) * block_duration
            date_time.append(datetime.fromtimestamp(reference_timestamp + time_difference))
        return date_time

    def get_block_daysback(self):
        reference_block = L.BLOCK_TIMESTAMP[self.chain_id][0]
        reference_timestamp = L.BLOCK_TIMESTAMP[self.chain_id][1]
        block_duration = L.BLOCK_DURATION[self.chain_id]
        timestamp_now = datetime.now().timestamp()
        timestamp_back = int(timestamp_now - self.daysBack * DAY_SECONDS)
        return (reference_block + (timestamp_back-reference_timestamp)//block_duration) * 1000

    # fields ['block', 'tick', 'tickLower', 'tickUpper', 'price', 'liquidity', 'amount0', 'amount1', 'fee0', 'fee1', 'cost0', 'cost1']
    def plot_profit(self, show):
        ax1, ax2 = self.new_plot()
        for file in self.csv_files:
            file_path = os.path.join(self.pathData, file)
            try:
                data = pd.read_csv(file_path)
                data = data.loc[data["block"] >= self.get_block_daysback()]

                date_time = self.block_to_datetime(data["block"])
                cost_column = data["cost0"] if self.showInToken == 0 else data["cost1"]
                initial_value =  cost_column.iloc[0]
                activity = int(data["activity"].iloc[len(data)-1])

                if "block" in data.columns and "cost0" in data.columns and "cost1" in data.columns:
                    label = ''.join(filter(str.isdigit, file.split('_result.csv')[0]))
                    label += ' (act ~ '+str(activity)+"%)"
                    ax1.plot(date_time, (cost_column/initial_value - 1.0)*100, label=f"{label}",linewidth=LINE_WIDTH)
                    
                else:
                    print(f"Skipping {file}: Required columns not found.")
            except Exception as e:
                print(f"Error processing {file}: {e}")

        tokenShow = self.token0 if self.showInToken else self.token1

        ax1.set_title("Absolute cost position change nominated in " + tokenShow + " for different width, price " + self.get_label_price())
        ax1.set_xlabel("Date")
        ax1.set_ylabel("Total change in " + tokenShow + ", %")

        self.plot_price(data, ax1, ax2)
        self.save_and_show("absolute", show)

    def plot_fee_apr(self, show):
        ax1, ax2 = self.new_plot()
        for file in self.csv_files:
            file_path = os.path.join(self.pathData, file)
            try:
                data = pd.read_csv(file_path)
                data = data.loc[data["block"] >= self.get_block_daysback()]

                date_time = self.block_to_datetime(data["block"])
                cost_column = data["cost0"] if self.showInToken == 0 else data["cost1"]
                initial_value =  cost_column.iloc[0]

                fee_column = (data["fee0"]*data["price"] + data["fee1"]) if self.showInToken == 1 else (data["fee0"] + data["fee1"]/data["price"])

                if "block" in data.columns and "cost0" in data.columns and "cost1" in data.columns:
                    label = ''.join(filter(str.isdigit, file.split('_result.csv')[0]))
                    ax1.plot(date_time, (fee_column/initial_value)*100, label=f"{label}",linewidth=LINE_WIDTH)
                    
                else:
                    print(f"Skipping {file}: Required columns not found.")
            except Exception as e:
                print(f"Error processing {file}: {e}")

        tokenShow = self.token0 if self.showInToken else self.token1
        ax1.set_title("Absolute cost position change nominated in " + tokenShow + " for different width, price " + self.get_label_price())
        ax1.set_xlabel("Date")
        ax1.set_ylabel("Total change in " + tokenShow + ", %")

        self.plot_price(data, ax1, ax2)
        self.save_and_show("fee_apr", show)

    def plot_relative(self, show):
        ax1, ax2 = self.new_plot()
        
        count_files = len(self.csv_files)
        data_sources = [None]*count_files
        labeles = [None]*count_files
        index = 0

        for file in self.csv_files:
            file_path = os.path.join(self.pathData, file)
            data_next = pd.read_csv(file_path)
            data_next = data_next.loc[data_next["block"] >= self.get_block_daysback()]
            labeles[index] = ''.join(filter(str.isdigit, file.split('_result.csv')[0]))
            data_sources[index] = data_next
            index += 1

        X_axis = None
        Y_axis = [None]*count_files
        Y_avg = None

        index = 0
        for data in data_sources:
            if X_axis is None:
                X_axis = self.block_to_datetime(data["block"])

            cost_column = data["cost0"] if self.showInToken == 0 else data["cost1"]
            initial_value =  cost_column.iloc[0]
            Y_axis[index] = (cost_column/initial_value - 1.0)*100
            if Y_avg is None:
                Y_avg = Y_axis[index]
            else:
                Y_avg = Y_avg + Y_axis[index]
            index += 1

        Y_avg /= count_files

        index = 0
        for Y in Y_axis:
            ax1.plot(X_axis, Y - Y_avg, label=f"{labeles[index]}",linewidth=LINE_WIDTH)
            index += 1

        tokenShow = self.token0 if self.showInToken else self.token1
        ax1.set_title("Realative strategy performance (F_i-<F_i>) nominated in " + tokenShow + " for different width, price " + self.get_label_price())
        ax1.set_xlabel("Date")
        ax1.set_ylabel("Relative performance deviation from average, %")

        self.plot_price(data_sources[0], ax1, ax2)
        self.save_and_show("relative", show)

    def plot_price(self, data, ax1, ax2):
        ax1.legend(loc="upper left")
        ax1.grid(True)

        data = data.loc[data["block"] >= self.get_block_daysback()]
        date_time = self.block_to_datetime(data["block"])
        price_column = 1/data["price"] if self.showInToken == 0 else data["price"]
        ax2.plot(date_time, price_column, color='black', linewidth=LINE_WIDTH, linestyle='dashed' ,label=self.get_label_price())

        ax2.set_ylabel("Price "+ self.get_label_price())
        ax2.legend(loc="upper right")
        
    def save_and_show(self, postfix_name, show):

        show_token = self.token0 if self.showInToken == 0 else self.token1
    
        filePath = self.pathImg + show_token + "_" + self.strategy+"_"+str(self.cool_down//L.ONE_MINUTE)+"min_"+postfix_name+".png"
        plt.savefig(filePath, dpi=300, bbox_inches='tight')
        plt.tight_layout()
        if show:
            plt.show()

        print("plot img saved at", filePath)

    def new_plot(self):
        fig, ax1 = plt.subplots(figsize=(32, 18))
        ax2 = ax1.twinx()
        return ax1, ax2

"""
    1 2 4 8 width
5  [apr/act]
10
20
min
"""
def tableTotal(pool, strategy, showInToken):
    chain_id = str(pool["chainId"])
    address = pool["address"]
    token0 = pool["token0"]
    token1 = pool["token1"]

    folder_file_paths = {}

    path = ROOT_PATH+str(chain_id)+"/"+address+"/"+strategy
    print("path", path)
    for subfolder in os.listdir(path):
        print("subfolder", subfolder)
        subfolder_path = os.path.join(path, subfolder)
        if os.path.isdir(subfolder_path):
            files = [f for f in os.listdir(subfolder_path) if f.endswith("_result.csv")]
            print("files", files)

            n_to_path = {}
            for file in files:
                n = int(file.split('_')[0]) 
                n_to_path[n] = os.path.join(subfolder_path, file)
            folder_file_paths[subfolder] = n_to_path

    width = sorted({key for map in folder_file_paths.values() for key in map.keys()})
    cool_down = sorted({int(key) for key in folder_file_paths.keys()})

    token = token0 if showInToken == 0 else token1
    csvFileResult = open(path + "/" + token + "_" + strategy+"_total.csv", 'w')
    csvWriter = csv.writer(csvFileResult)
    csvWriter.writerow(["CD/width"]+width)
    csvFileResult.flush()

    for cd in cool_down:
        row = [str(cd)]
        for w in width:
            file = path + "/" + str(cd) + "/"+str(w) + "_result.csv"
            try:
                data = pd.read_csv(file)
                act = data["activity"].iloc[len(data)-1]
                cost_column = data["cost0"] if showInToken == 0 else data["cost1"]
                
                initial_block = data["block"].iloc[0]//1000 
                last_block = data["block"].iloc[len(data)-1]//1000 
                initial_value =  cost_column.iloc[0]
                last_value = cost_column.iloc[len(data)-1]
                days = (last_block - initial_block) * L.BLOCK_DURATION[chain_id] / L.ONE_DAY
                apr = 100 * (last_value-initial_value)/initial_value * 365 / days
                row += [str(int(apr*100)/100) + " (" + str(int(act))+")"]
            except:
                print("width data for cool down {cool_down} not found - skip")
            finally:
                pass

        print(row)
        csvWriter.writerow(row)

    csvFileResult.flush()

def plot(pool, strategy, cool_down, showInToken, daysBack):
    plotResult = PlotStrategyResult(pool, strategy, cool_down, showInToken, daysBack)

    plotResult.plot_profit(False)
    plotResult.plot_fee_apr(False)
    plotResult.plot_relative(False)
