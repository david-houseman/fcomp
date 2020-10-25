from datetime import datetime

from download import download
from fcast import fcast

if __name__ == "__main__":
    download(datetime.now(), "../data/aemo/")
    fcast("Fri", "../data/aemo/", "../data/forecasts.csv")


