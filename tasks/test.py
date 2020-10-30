import psycopg2

connection = psycopg2.connect(user="postgres", port="5433", database="david")
cursor = connection.cursor()

#cursor.execute("SELECT version();")
#record = cursor.fetchone()
#print("Connected to: ", record)

cursor.execute("SELECT COUNT(*) FROM submissions;")
records = cursor.fetchone()
print( "Count:", records )

date_str = "2020-10-19"
time_str = "00:00:00"
participant = 555555555
fullname = "David G"
origin = "M"

h1 = 1.1
h2 = 2.2
h3 = 3.3
h4 = 4.4
h5 = 5.5
h6 = 6.6
h7 = 7.7

cursor.execute("""
INSERT INTO submissions 
VALUES( %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s );
""",(date_str, time_str, participant, fullname, origin, h1, h2, h3, h4, h5, h6, h7)
)

cursor.execute("SELECT COUNT(*) FROM submissions;")
records = cursor.fetchone()
print( "Count:", records )

cursor.execute("CALL main();")

cursor.execute("SELECT * FROM forecasts_view;")
records = cursor.fetchall()

for r in records:
    print(*r)

connection.commit()

connection.close()
