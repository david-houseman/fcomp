import pandas as pd
import numpy as np
from datetime import datetime, timedelta, date, time
import math

from common import read_config, competition_days

def deduplicate(full_df):
    return(
        full_df.sort_values(by=["fcast_date", "fcast_time", "snumber"])
        .groupby(["fcast_date", "snumber"])
        .tail(1)
        .drop(columns="fcast_time")
    )


def auto_trim(full_df, comp_start, comp_end):
    week_df = full_df[full_df["fcast_date"] == comp_start]
    participants = dict(zip(week_df["snumber"], week_df["name"]))

    trim_df = pd.DataFrame()
    for index, row in full_df.iterrows():
        if row["snumber"] in participants.keys():
            trim_df = trim_df.append(row)

    return trim_df


def auto_fill(week_df, prev_df):
    if prev_df.empty:
        return week_df

    for t in competition_days(comp_start, comp_end):
        if s == 0 or s in week_df.index:
            continue
        auto_df = pd.DataFrame(prev_df.loc[s].to_dict(), index=[s])
        week_df = week_df.append(auto_df)

    return week_df


def rmsfe(fcasts, actuals):
    err = fcasts - np.outer(np.ones(len(fcasts)), actuals)
    return np.sqrt(np.diag(np.matmul(err, err.transpose())) / 7)


def append_rmsfe(week_df):
    if 0 in week_df.index:
        actual_df = week_df.loc[0]
        week_df["rmsfe"] = np.round(rmsfe(week_df.values, actual_df.values), 2)
        return week_df.sort_values(by=["rmsfe"])
    week_df["rmsfe"] = math.nan
    return week_df


def clean(config_file, submissions_file, forecasts_file):

    comp_start, comp_end = read_config(config_file)

    horizon_cols = [
        (comp_start + timedelta(days=h + 1)).strftime("%a") for h in range(7)
    ]

    read_cols = ["fcast_date", "fcast_time", "snumber", "name", "method"] + horizon_cols

    full_df = pd.read_csv(
        submissions_file,
        sep="|",
        names=read_cols,
        parse_dates=["fcast_date"],
    )

    full_df = deduplicate(full_df)
    print(full_df)

    full_df = auto_trim(full_df, comp_start, comp_end)
    print(full_df)
    
    fcast_df = pd.DataFrame()
    prev_df = pd.DataFrame()
    for t in competition_days(comp_start, comp_end):
        if not t in full_df.index:
            continue
        week_df = full_df.loc[t]

        week_df = auto_trim(week_df, participants)

        if not prev_df.empty:
            week_df = auto_fill(week_df, prev_df)

        prev_df = week_df.copy()

        week_df = week_df.reindex([(t,s) for s in week_df.index])
        
        fcast_df = fcast_df.append(week_df)
       
        
    fcast_df = append_rmsfe(fcast_df)
    print(fcast_df)



if __name__ == "__main__":
    clean("../config/config.json", "../data/submissions.csv", "../data/forecasts.csv")
