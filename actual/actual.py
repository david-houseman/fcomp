import requests
from datetime import datetime, timedelta 

now = datetime.now()
end_year = now.year
end_month = now.month

def fetches():
    for j in range(2019,end_year):
        for k in range(12):
            yield "{:04d}{:02d}".format(j, k + 1)
    for k in range(end_month):
        yield "{:04d}{:02d}".format(end_year, k + 1)
                
def download(yyyymm):
    baseurl = "https://aemo.com.au/aemo/data/nem/priceanddemand/"
    filename = "PRICE_AND_DEMAND_{}_NSW1.csv".format(yyyymm)

    # AEMO currently rejects requests that use the default User-Agent
    # (python-urllib/3.x.y). Set the header manually to pretend to be
    # a 'real' browser.
    r = requests.get(
        baseurl + filename,
        headers={"User-Agent": "Mozilla/5.0"},
    )

    print("Downloaded: ", filename)
    with open("../data/aemo/" + filename, 'wb') as f:
        f.write(r.content)
        
    
for yyyymm in fetches():
    download(yyyymm)
    

    
