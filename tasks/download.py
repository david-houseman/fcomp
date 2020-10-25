from datetime import datetime
import requests
import os

def fetch_months(now):
    end_year = now.year
    end_month = now.month

    start_year = 2019
    for j in range(start_year, end_year):
        for k in range(12):
            yield "{:04d}{:02d}".format(j, k + 1)
    for k in range(end_month):
        yield "{:04d}{:02d}".format(end_year, k + 1)


def download_month(yyyymm, data_dir):
    baseurl = "https://aemo.com.au/aemo/data/nem/priceanddemand/"
    filename = "PRICE_AND_DEMAND_{}_NSW1.csv".format(yyyymm)

    # AEMO currently rejects requests that use the default User-Agent
    # (python-urllib/3.x.y). Set the header manually to pretend to be
    # a 'real' browser.
    r = requests.get(baseurl + filename, headers={"User-Agent": "Mozilla/5.0"})

    print("Downloaded: ", filename)
    with open(os.path.join(data_dir,filename), "wb") as f:
        f.write(r.content)

        
def download(now, data_dir):
    for yyyymm in fetch_months(now):
        download_month(yyyymm, data_dir)
          

if __name__ == "__main__":
    download(datetime.now(), "../data/aemo/")
