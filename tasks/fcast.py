import pandas as pd
import numpy as np
import datetime as dt
import psycopg2
import fcntl

from fnmatch import fnmatch
import os
from datetime import datetime, date, time, timedelta

from statsmodels.tsa.holtwinters import ExponentialSmoothing
from statsmodels.tsa.statespace.sarimax import SARIMAX

from util import is_sorted
from common import read_config


def read_data():
    aemo_dir = "../data/aemo/"

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
    

def write_fcast(now, snumber, name, fcasts):
    date_str = now.strftime(format="%Y-%m-%d")
    time_str = now.strftime(format="%H:%M:%S")
    origin = "B"

    assert(len(fcasts) == 7 )

    # Write to the database.
    db_config = {"user": "root", "database": "root"}
    conn = psycopg2.connect(**db_config)
    cursor = conn.cursor()
    cursor.execute(
        """
INSERT INTO submissions 
VALUES( %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s );
""",
        (date_str, time_str, snumber, name, origin, *fcasts),
    )
    cursor.execute("CALL main();")
    conn.commit()
    conn.close()
    
    # Write to the backup file.
    submissions_file = "../data/submissions.csv"
    record = [date_str, time_str, str(snumber), name, origin] + [str(f) for f in fcasts]
    with open(submissions_file, "a+") as bfile:        
        fcntl.flock(bfile, fcntl.LOCK_EX)
        bfile.write("|".join(record) + "\n")
        fcntl.flock(bfile, fcntl.LOCK_UN)

    
def fcast():     
    comp_start, comp_end = read_config("../config/config.json")
    y = read_data()

    # If today is submission_day, generate benchmark forecasts.
    now = dt.datetime.now()
    if now.weekday() == comp_start.weekday():
        write_fcast(now, 100, "**Seasonal RW**", fcast_seasonalrw(y))
        write_fcast(now, 101, "**Holt-Winters**", fcast_ses(y))
        write_fcast(now, 102, "**SARIMA**", fcast_sarima(y))
        return
        
    # If today is the day after submission_day, generate actuals.
    if now.weekday() == (comp_start.weekday() + 1) % 7:
        forecast_date = dt.datetime.combine(y.index[-8], dt.time())
        write_fcast(forecast_date, 0, "**Actual**", y[-7:])
        return
    
if __name__ == "__main__":
    fcast()
