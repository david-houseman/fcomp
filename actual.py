import pandas as pd
import numpy as np
import datetime

from fnmatch import fnmatch
import os

from common import competition_schedule
from util import is_sorted

data_dir = "../data/aemo/"
forecast_dir = "../data/forecasts/"

its = pd.DataFrame()

print("Reading files in ", data_dir)
for fname in sorted(os.listdir(data_dir)):
    file = os.path.join(data_dir,fname)
    if not fnmatch(file, "*.csv"):
        continue

    frag = pd.read_csv(
        file,
        index_col='SETTLEMENTDATE',
        parse_dates=True,
        dayfirst = True,
    )
    its = its.append(frag)

print(its)   
assert(is_sorted(its.index))

if its.index[-1].time() == datetime.time(0,0,0):
    its = its[:-1]

ts = its[:-1].resample("1d").mean()
y = ts["TOTALDEMAND"]

print(y.tail(15))

for today in competition_schedule():
    j = y.index.get_loc(today)
    assert(y[j] == y[today])
    
    fcasts = y[j + 1: j + 8]

    ## Format output
    date_str = today.strftime(format="%Y-%m-%d")
    time_str = today.strftime(format="%H:%M:%S")
    snumber = "000000000"
    name = "Oracle"
    method = "M"

    record = (
        [date_str, time_str, snumber, name, method] +
        [str(int(f)) for f in fcasts]
    )
    print( "|".join(record) + "\n" )
    
