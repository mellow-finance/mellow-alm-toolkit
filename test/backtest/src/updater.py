import loader as L

for name in L.POOLS:
    pool = L.POOLS[name]
    print(pool)
    loader = L.SwapLogLoader(pool)
    loader.loadSwaps()