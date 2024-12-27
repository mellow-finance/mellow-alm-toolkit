from collections import deque 
import math

class PricePoint:
    def __init__(self, tick, timestamp):
        self.tick = tick
        self.timestamp = timestamp
        pass

class Oracle:
    def __init__(self, look_back, max_age, max_delta):
        self.__look_back = look_back
        self.__max_age = max_age
        self.__max_delta = max_delta
        self.__history = deque()
        pass

    def push(self, tick, timestamp):
        self.__history.append(PricePoint(tick, timestamp))
        
        if len(self.__history) > self.__look_back:
            self.__history.popleft()
        
        self.__remove_old(timestamp)
        
    def ensure_no_mev(self, tick):
        max_delta = 0
        for point in self.__history:
            delta = math.fabs(point.tick - tick)
            if delta > max_delta:
                max_delta = delta

        if max_delta > self.__max_delta:
           # self.print()
            return False
        
        return True

    def print(self):
        print("=========== Oracle data ===========")
        for point in self.__history:
            print(point.tick, point.timestamp)

    def __remove_old(self, timestamp):
        for i in range(len(self.__history)-1, 0, -1):
            point = self.__history[i]
            if timestamp - point.timestamp > self.__max_age:
                self.__history.popleft()