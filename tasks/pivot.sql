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
