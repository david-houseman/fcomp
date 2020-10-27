import json
from datetime import datetime, date, time, timedelta

def read_config(config_path):
    with open(config_path) as f:
        config = json.load(f)

    comp_start = datetime.strptime(config["competition_start"], "%Y-%m-%d")
    comp_end = datetime.strptime(config["competition_end"], "%Y-%m-%d")
    assert comp_start.weekday() == comp_end.weekday()
    assert comp_start <= comp_end

    return comp_start, comp_end


def competition_days(comp_start, comp_end):
    assert comp_start.weekday() == comp_end.weekday()
    assert comp_start <= comp_end  
    
    t = comp_start
    while t <= comp_end:
        yield t
        t += timedelta(days=7)

