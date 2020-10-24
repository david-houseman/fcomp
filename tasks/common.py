from datetime import datetime, timedelta 

submission_day = "Fri"
competition_start = datetime(2020, 5, 15)
competition_length = 13

def competition_schedule():
    assert(competition_start.strftime("%a") == submission_day)

    for j in range(competition_length):
        yield competition_start + timedelta(days=7) * j    


    
