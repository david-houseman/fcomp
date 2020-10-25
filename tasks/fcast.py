import pandas as pd
import numpy as np
import datetime as dt

from fnmatch import fnmatch
import os

from statsmodels.tsa.holtwinters import ExponentialSmoothing
from statsmodels.tsa.statespace.sarimax import SARIMAX

from util import is_sorted

submission_day = "Fri"
aemo_dir = "../data/aemo/"
forecasts_file = "../data/forecasts.csv"

def read_data():
    its = pd.DataFrame()
    for fname in sorted(os.listdir(aemo_dir)):
        file = os.path.join(aemo_dir, fname)
        if not fnmatch(file, "*.csv"):
            continue

        frag = pd.read_csv(
            file, index_col="SETTLEMENTDATE", parse_dates=True, dayfirst=True
        )
        its = its.append(frag)

    assert is_sorted(its.index)
    print(its)

    if its.index[-1].time() == dt.time(0, 0, 0):
        its = its[:-1]

    ts = its.resample("1d").mean()
    y = ts["TOTALDEMAND"]
    
    print(y)
    return y


def fcast_seasonalrw(y):
    # Can't use y[j] partial day of data, so use y[j-7]
    return np.append(y[-6:], y[-7])


def fcast_ses(y):
    fit = ExponentialSmoothing(
        y, trend="Add", seasonal="Add", seasonal_periods=7
    ).fit()
    fc = fit.forecast(8)
    return fc[1:8]


def fcast_sarima(y):
    p, d, q = 3, 1, 3
    P, D, Q = 0, 1, 1
    m = 7

    fit = SARIMAX(y, order=(p, d, q), seasonal_order=(P, D, Q, m)).fit()
    fc = fit.forecast(8)
    return fc[1:8]    
    

def write_fcast(f, now, snumber, name, fcasts):

    date_str = now.strftime(format="%Y-%m-%d")
    time_str = now.strftime(format="%H:%M:%S")
    method = "B"

    assert(len(fcasts) == 7 )
    
    record = [date_str, time_str, snumber, name, method] + [
        str(round(f,0)) for f in fcasts
    ]
    f.write("|".join(record) + "\n")

    
def main(): 
    now = dt.datetime.now()
    y = read_data()

    with open(forecasts_file, "w") as f:    
        if now.strftime("%a") == submission_day:
            write_fcast(f, now, "000000100", "Seasonal RW", fcast_seasonalrw(y))
            write_fcast(f, now, "000000101", "SES", fcast_ses(y))
            write_fcast(f, now, "000000102", "SARIMA", fcast_sarima(y))
            return

        for j in range(len(y) - 13, len(y) - 7):
            now = dt.datetime.combine(y.index[j], dt.time())
            if now.strftime("%a") == submission_day:
                break
        write_fcast(f, now, "000000000", "Actual", y[j + 1 : j + 8])

    
if __name__ == "__main__":
    main()
