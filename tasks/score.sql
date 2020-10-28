DROP VIEW pivot;
DROP VIEW pivot_query;
DROP VIEW unpivot;
DROP VIEW horizon_combined;
DROP VIEW horizon_errors_view;
DROP VIEW horizon_errors;
DROP VIEW overall_errors_view;
DROP VIEW overall_errors;
DROP VIEW week_errors_view;
DROP VIEW week_errors;
DROP VIEW errors_view;
DROP VIEW errors;

CREATE VIEW errors AS
SELECT
a.forecast_date,
b.participant,
( b.h1 - a.h1 ) AS h1,
( b.h2 - a.h2 ) AS h2,
( b.h3 - a.h3 ) AS h3,
( b.h4 - a.h4 ) AS h4,
( b.h5 - a.h5 ) AS h5,
( b.h6 - a.h6 ) AS h6,
( b.h7 - a.h7 ) AS h7
FROM forecasts a
JOIN forecasts b
USING( forecast_date )
WHERE a.participant = 0;

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
sqrt( ( h1*h1 + h2*h2 + h3*h3 + h4*h4 + h5*h5 + h6*h6 + h7*h7 ) / 7 )
  ::NUMERIC(16,4) AS rmsfe
FROM errors;

CREATE VIEW week_errors_view AS
SELECT * FROM forecasts
LEFT JOIN week_errors
USING( forecast_date, participant )
NATURAL JOIN participants
ORDER BY forecast_date ASC, rmsfe ASC, participant ASC;

SELECT * FROM week_errors_view;

\copy ( SELECT * FROM week_errors_view ) TO 'week_results.csv' WITH CSV HEADER DELIMITER '|'

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

\copy ( SELECT * FROM overall_errors_view ) TO 'overall_results.csv' WITH CSV HEADER DELIMITER '|'

----------------------------------------------------------------------------------

CREATE VIEW horizon_errors AS
SELECT participant,
COUNT( forecast_date ),
sqrt( SUM( h1*h1 ) / COUNT( h1 ) )::NUMERIC(16,4) AS h1,
sqrt( SUM( h2*h2 ) / COUNT( h2 ) )::NUMERIC(16,4) AS h2,
sqrt( SUM( h3*h3 ) / COUNT( h3 ) )::NUMERIC(16,4) AS h3,
sqrt( SUM( h4*h4 ) / COUNT( h4 ) )::NUMERIC(16,4) AS h4,
sqrt( SUM( h5*h5 ) / COUNT( h5 ) )::NUMERIC(16,4) AS h5,
sqrt( SUM( h6*h6 ) / COUNT( h6 ) )::NUMERIC(16,4) AS h6,
sqrt( SUM( h7*h7 ) / COUNT( h7 ) )::NUMERIC(16,4) AS h7
FROM errors
GROUP BY participant;

CREATE VIEW horizon_errors_view AS
SELECT * FROM horizon_errors
NATURAL JOIN participants
ORDER BY h1 ASC;

SELECT * FROM horizon_errors_view;

\copy ( SELECT * FROM horizon_errors_view ) TO 'horizon_results.csv' WITH CSV HEADER DELIMITER '|'

----------------------------------------------------------------------------------

CREATE VIEW horizon_combined AS
SELECT COUNT( forecast_date ),
sqrt( SUM( h1*h1 ) / COUNT( h1 ) )::NUMERIC(16,4) AS h1,
sqrt( SUM( h2*h2 ) / COUNT( h2 ) )::NUMERIC(16,4) AS h2,
sqrt( SUM( h3*h3 ) / COUNT( h3 ) )::NUMERIC(16,4) AS h3,
sqrt( SUM( h4*h4 ) / COUNT( h4 ) )::NUMERIC(16,4) AS h4,
sqrt( SUM( h5*h5 ) / COUNT( h5 ) )::NUMERIC(16,4) AS h5,
sqrt( SUM( h6*h6 ) / COUNT( h6 ) )::NUMERIC(16,4) AS h6,
sqrt( SUM( h7*h7 ) / COUNT( h7 ) )::NUMERIC(16,4) AS h7
FROM errors
WHERE participant >= 1000;

SELECT * FROM horizon_combined;
\copy ( SELECT * FROM horizon_combined ) TO 'horizon_combined.csv' WITH CSV HEADER DELIMITER '|'


----------------------------------------------------------------------------------

CREATE VIEW unpivot AS
SELECT participant, forecast_date, 1 AS horizon, h1 AS forecast FROM forecasts
UNION ALL
SELECT participant, forecast_date, 2 AS horizon, h2 FROM forecasts
UNION ALL
SELECT participant, forecast_date, 3 AS horizon, h3 FROM forecasts
UNION ALL
SELECT participant, forecast_date, 4 AS horizon, h4 FROM forecasts
UNION ALL
SELECT participant, forecast_date, 5 AS horizon, h5 FROM forecasts
UNION ALL
SELECT participant, forecast_date, 6 AS horizon, h6 FROM forecasts
UNION ALL
SELECT participant, forecast_date, 7 AS horizon, h7 FROM forecasts
ORDER BY forecast_date, horizon, participant
;

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
\copy ( SELECT * FROM pivot ) TO 'pivot.csv' WITH CSV HEADER DELIMITER '|'
