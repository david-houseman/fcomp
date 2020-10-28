SET client_min_messages TO WARNING;

DROP SCHEMA IF EXISTS fc CASCADE;
CREATE SCHEMA fc;
SET search_path TO fc;

----------------------------------------------------------------------------------

CREATE TABLE participants
(
	participant INTEGER PRIMARY KEY,
	fullname VARCHAR NOT NULL
);

CREATE TABLE forecasts
(
	forecast_date DATE NOT NULL,
	participant INTEGER NOT NULL,
	sat REAL NOT NULL,
	sun REAL NOT NULL,
	mon REAL NOT NULL,
	tue REAL NOT NULL,
	wed REAL NOT NULL,
	thu REAL NOT NULL,
	fri REAL NOT NULL,
	PRIMARY KEY( forecast_date, participant ),
	FOREIGN KEY( participant ) REFERENCES participants
);

----------------------------------------------------------------------------------

\copy participants FROM forecasts/participants.csv WITH CSV HEADER
\copy forecasts FROM forecasts/forecasts.csv WITH CSV HEADER

----------------------------------------------------------------------------------

SELECT * FROM participants;

-- Round all forecasts to specified precision
UPDATE forecasts
SET
sat = ROUND( sat ),
sun = ROUND( sun ),
mon = ROUND( mon ),
tue = ROUND( tue ),
wed = ROUND( wed ),
thu = ROUND( thu ),
fri = ROUND( fri )
WHERE true;

CREATE VIEW forecasts_view AS
SELECT *
FROM forecasts
NATURAL JOIN participants
ORDER BY forecast_date ASC, participant ASC;

--SELECT * FROM forecasts_view;

----------------------------------------------------------------------------------

CREATE VIEW forecasts_group_mean AS
SELECT
forecast_date,
300 AS participant,
ROUND( SUM( sat ) / COUNT( sat ) ) AS sat,
ROUND( SUM( sun ) / COUNT( sun ) ) AS sun,
ROUND( SUM( mon ) / COUNT( mon ) ) AS mon,
ROUND( SUM( tue ) / COUNT( tue ) ) AS tue,
ROUND( SUM( wed ) / COUNT( wed ) ) AS wed,
ROUND( SUM( thu ) / COUNT( thu ) ) AS thu,
ROUND( SUM( fri ) / COUNT( fri ) ) AS fri
FROM forecasts
WHERE participant >= 1000
GROUP BY forecast_date;

INSERT INTO forecasts
SELECT * FROM forecasts_group_mean;

CREATE VIEW forecasts_group_median AS
SELECT
forecast_date,
301 AS participant,
ROUND( percentile_disc( 0.5 ) WITHIN GROUP( ORDER BY sat ) ) AS sat,
ROUND( percentile_disc( 0.5 ) WITHIN GROUP( ORDER BY sun ) ) AS sun,
ROUND( percentile_disc( 0.5 ) WITHIN GROUP( ORDER BY mon ) ) AS mon,
ROUND( percentile_disc( 0.5 ) WITHIN GROUP( ORDER BY tue ) ) AS tue,
ROUND( percentile_disc( 0.5 ) WITHIN GROUP( ORDER BY wed ) ) AS wed,
ROUND( percentile_disc( 0.5 ) WITHIN GROUP( ORDER BY thu ) ) AS thu,
ROUND( percentile_disc( 0.5 ) WITHIN GROUP( ORDER BY fri ) ) AS fri
FROM forecasts
WHERE participant >= 1000
GROUP BY forecast_date;

--INSERT INTO forecasts
--SELECT * FROM forecasts_group_median;


CREATE VIEW forecasts_combination AS
SELECT
forecast_date,
302 AS participant,
ROUND( SUM( sat ) / COUNT( sat ) ) AS sat,
ROUND( SUM( sun ) / COUNT( sun ) ) AS sun,
ROUND( SUM( mon ) / COUNT( mon ) ) AS mon,
ROUND( SUM( tue ) / COUNT( tue ) ) AS tue,
ROUND( SUM( wed ) / COUNT( wed ) ) AS wed,
ROUND( SUM( thu ) / COUNT( thu ) ) AS thu,
ROUND( SUM( fri ) / COUNT( fri ) ) AS fri
FROM forecasts
WHERE participant in ( 201, 202, 205 )
GROUP BY forecast_date;

--INSERT INTO forecasts
--SELECT * FROM forecasts_combination;


----------------------------------------------------------------------------------

CREATE VIEW errors AS
SELECT
a.forecast_date,
b.participant,
( b.sat - a.sat ) AS sat,
( b.sun - a.sun ) AS sun,
( b.mon - a.mon ) AS mon,
( b.tue - a.tue ) AS tue,
( b.wed - a.wed ) AS wed,
( b.thu - a.thu ) AS thu,
( b.fri - a.fri ) AS fri
FROM forecasts a
JOIN forecasts b
USING( forecast_date )
WHERE a.participant = 100;

CREATE VIEW errors_view AS
SELECT * FROM errors
NATURAL JOIN participants
ORDER BY forecast_date ASC, participant ASC;

--SELECT * FROM errors_view;

----------------------------------------------------------------------------------

CREATE VIEW week_errors AS
SELECT
forecast_date,
participant,
sqrt( ( sat*sat + sun*sun + mon*mon + tue*tue + wed*wed + thu*thu + fri*fri ) / 7 )
  ::NUMERIC(16,4) AS rmsfe
FROM errors;

CREATE VIEW week_errors_view AS
SELECT * FROM forecasts
LEFT JOIN week_errors
USING( forecast_date, participant )
NATURAL JOIN participants
ORDER BY forecast_date ASC, rmsfe ASC, participant ASC;

SELECT * FROM week_errors_view;
\copy ( SELECT * FROM week_errors_view ) TO 'QBUS3850_week_results.csv' WITH CSV HEADER

----------------------------------------------------------------------------------

CREATE VIEW overall_errors AS
SELECT participant,
COUNT( forecast_date ),
sqrt( SUM( rmsfe * rmsfe ) / COUNT( rmsfe ) )::NUMERIC(16,4) AS rmsfe
FROM week_errors
GROUP BY participant;

CREATE VIEW overall_errors_view AS
SELECT * FROM overall_errors
NATURAL JOIN participants
ORDER BY rmsfe ASC;


SELECT * FROM overall_errors_view;
\copy ( SELECT * FROM overall_errors_view ) TO 'QBUS3850_overall_results.csv' WITH CSV HEADER


----------------------------------------------------------------------------------

CREATE VIEW horizon_errors AS
SELECT participant,
COUNT( forecast_date ),
sqrt( SUM( sat*sat ) / COUNT( sat ) )::NUMERIC(16,4) AS sat,
sqrt( SUM( sun*sun ) / COUNT( sun ) )::NUMERIC(16,4) AS sun,
sqrt( SUM( mon*mon ) / COUNT( mon ) )::NUMERIC(16,4) AS mon,
sqrt( SUM( tue*tue ) / COUNT( tue ) )::NUMERIC(16,4) AS tue,
sqrt( SUM( wed*wed ) / COUNT( wed ) )::NUMERIC(16,4) AS wed,
sqrt( SUM( thu*thu ) / COUNT( thu ) )::NUMERIC(16,4) AS thu,
sqrt( SUM( fri*fri ) / COUNT( fri ) )::NUMERIC(16,4) AS fri
FROM errors
GROUP BY participant;

CREATE VIEW horizon_errors_view AS
SELECT * FROM horizon_errors
NATURAL JOIN participants
ORDER BY sat ASC;

SELECT * FROM horizon_errors_view;
\copy ( SELECT * FROM horizon_errors_view ) TO 'QBUS3850_horizon_results.csv' WITH CSV HEADER

----------------------------------------------------------------------------------

CREATE VIEW horizon_combined AS
SELECT COUNT( forecast_date ),
sqrt( SUM( sat*sat ) / COUNT( sat ) )::NUMERIC(16,4) AS sat,
sqrt( SUM( sun*sun ) / COUNT( sun ) )::NUMERIC(16,4) AS sun,
sqrt( SUM( mon*mon ) / COUNT( mon ) )::NUMERIC(16,4) AS mon,
sqrt( SUM( tue*tue ) / COUNT( tue ) )::NUMERIC(16,4) AS tue,
sqrt( SUM( wed*wed ) / COUNT( wed ) )::NUMERIC(16,4) AS wed,
sqrt( SUM( thu*thu ) / COUNT( thu ) )::NUMERIC(16,4) AS thu,
sqrt( SUM( fri*fri ) / COUNT( fri ) )::NUMERIC(16,4) AS fri
FROM errors
WHERE participant >= 1000;

SELECT * FROM horizon_combined;
\copy ( SELECT * FROM horizon_combined ) TO 'QBUS3850_horizon_combined.csv' WITH CSV HEADER


----------------------------------------------------------------------------------

CREATE VIEW unpivot AS
SELECT participant, forecast_date, 1 AS horizon, sat AS forecast FROM forecasts
UNION ALL
SELECT participant, forecast_date, 2 AS horizon, sun FROM forecasts
UNION ALL
SELECT participant, forecast_date, 3 AS horizon, mon FROM forecasts
UNION ALL
SELECT participant, forecast_date, 4 AS horizon, tue FROM forecasts
UNION ALL
SELECT participant, forecast_date, 5 AS horizon, wed FROM forecasts
UNION ALL
SELECT participant, forecast_date, 6 AS horizon, thu FROM forecasts
UNION ALL
SELECT participant, forecast_date, 7 AS horizon, fri FROM forecasts
ORDER BY forecast_date, horizon, participant
;

CREATE VIEW unpivot_three_col AS
SELECT
participant,
fullname,
CONCAT( forecast_date, '+', horizon ) AS forecast_date,
forecast
FROM unpivot
NATURAL JOIN participants
ORDER BY forecast_date, participant;

--SELECT * FROM unpivot_three_col;
\copy ( SELECT * FROM unpivot_three_col ) TO 'QBUS3850_unpivot.csv' WITH CSV HEADER


-- Couldn't get this to work. Not sure it improves on the simple CASE implementation.
-- CREATE EXTENSION tablefunc;
-- SELECT * FROM public.crosstab( '' );

-- Generate query from query. Yuk.
CREATE VIEW pivot_query AS
SELECT CONCAT( 'SUM( CASE WHEN participant = ', participant, ' THEN forecast END ) AS "', fullname, '",' )
FROM participants
ORDER BY participant;

--SELECT * FROM pivot_query;

-- Pivot table
CREATE VIEW pivot AS
SELECT forecast_date, horizon,
 SUM( CASE WHEN participant = 100 THEN forecast END ) AS "**Oracle**",
 SUM( CASE WHEN participant = 200 THEN forecast END ) AS "**AEMO**",
 SUM( CASE WHEN participant = 201 THEN forecast END ) AS "**Seasonal RW**",
 SUM( CASE WHEN participant = 202 THEN forecast END ) AS "**Holt-Winters**",
 SUM( CASE WHEN participant = 205 THEN forecast END ) AS "**SARIMA**",
 SUM( CASE WHEN participant = 300 THEN forecast END ) AS "**Group Mean**",
 SUM( CASE WHEN participant = 301 THEN forecast END ) AS "**Group Median**",
 SUM( CASE WHEN participant = 302 THEN forecast END ) AS "**Combination**",
 SUM( CASE WHEN participant = 480001881 THEN forecast END ) AS "Anita Chen",
 SUM( CASE WHEN participant = 470352731 THEN forecast END ) AS "Darius Zhu",
 SUM( CASE WHEN participant = 470352672 THEN forecast END ) AS "Eric Manolev",
 SUM( CASE WHEN participant = 460061939 THEN forecast END ) AS "Huang Lica",
 SUM( CASE WHEN participant = 470423307 THEN forecast END ) AS "Hugh Dawson",
 SUM( CASE WHEN participant = 470415771 THEN forecast END ) AS "Josh Rizk",
 SUM( CASE WHEN participant = 450226944 THEN forecast END ) AS "Jue Shen",
 SUM( CASE WHEN participant = 500294615 THEN forecast END ) AS "Justin Cavanaugh",
 SUM( CASE WHEN participant = 480384980 THEN forecast END ) AS "Leo F",
 SUM( CASE WHEN participant = 460299842 THEN forecast END ) AS "Matilda Measday",
 SUM( CASE WHEN participant = 199315748 THEN forecast END ) AS "Matthew Chircop",
 SUM( CASE WHEN participant = 470375383 THEN forecast END ) AS "Pavel Suvorov",
 SUM( CASE WHEN participant = 460295453 THEN forecast END ) AS "Peter Axiotis",
 SUM( CASE WHEN participant = 480354352 THEN forecast END ) AS "Quang Tran",
 SUM( CASE WHEN participant = 470398197 THEN forecast END ) AS "Vivien Huang"
FROM unpivot
GROUP BY forecast_date, horizon
ORDER BY forecast_date, horizon;

--SELECT * FROM unpivot_three_col;
\copy ( SELECT * FROM pivot ) TO 'QBUS3850_pivot.csv' WITH CSV HEADER
