CREATE TABLE IF NOT EXISTS submissions
(
	forecast_date DATE NOT NULL,
	forecast_time TIME NOT NULL,
	participant INTEGER NOT NULL,
	fullname VARCHAR NOT NULL,
	origin CHAR NOT NULL,
	h1 REAL NOT NULL,
	h2 REAL NOT NULL,
	h3 REAL NOT NULL,
	h4 REAL NOT NULL,
	h5 REAL NOT NULL,
	h6 REAL NOT NULL,
	h7 REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS participants
(
	participant INTEGER PRIMARY KEY,
	fullname VARCHAR NOT NULL
);

CREATE TABLE IF NOT EXISTS forecasts
(
	forecast_date DATE NOT NULL,
	participant INTEGER NOT NULL,
	origin CHAR NOT NULL,
	h1 REAL NOT NULL,
	h2 REAL NOT NULL,
	h3 REAL NOT NULL,
	h4 REAL NOT NULL,
	h5 REAL NOT NULL,
	h6 REAL NOT NULL,
	h7 REAL NOT NULL,
	PRIMARY KEY( forecast_date, participant ),
	FOREIGN KEY( participant ) REFERENCES participants
);

DELETE FROM forecasts;
DELETE FROM participants;

----------------------------------------------------------------------------------

DELETE FROM submissions;
\copy submissions FROM ../data/submissions.csv WITH CSV DELIMITER '|'
--SELECT * FROM submissions;

----------------------------------------------------------------------------------

-- Select the last (by forecast_time) forecasts for each (forecast_date, participant).
CREATE OR REPLACE VIEW submissions_dedup AS
SELECT DISTINCT ON (forecast_date, participant)
forecast_date, participant, origin, h1, h2, h3, h4, h5, h6, h7
FROM submissions
ORDER BY forecast_date, participant, forecast_time DESC;

-- Populate the participants table with the (unique) participants of week 1.
CREATE OR REPLACE PROCEDURE declare_participants(comp_start DATE)
LANGUAGE plpgsql
AS $$
BEGIN
	INSERT INTO participants
	SELECT DISTINCT ON (participant)
	participant, fullname
	FROM submissions
	WHERE forecast_date = comp_start
	ORDER BY participant, forecast_time DESC;		

	COMMIT;
END;
$$;

CALL declare_participants('2020-10-19');
SELECT * FROM participants;

-- Populate the forecasts table with the deduplicated submissions,
-- from known participants only.
INSERT INTO forecasts
SELECT forecast_date, participant, origin, h1, h2, h3, h4, h5, h6, h7
FROM submissions_dedup
JOIN participants USING (participant);

SELECT * FROM forecasts;


CREATE OR REPLACE PROCEDURE auto_fill(prev_date DATE, curr_date DATE)
LANGUAGE plpgsql
AS $$
BEGIN

	INSERT INTO forecasts
	SELECT curr_date, p.participant, 'A', p.h1, p.h2, p.h3, p.h4, p.h5, p.h6, p.h7
	FROM
	(  	
		SELECT *
		FROM forecasts
		WHERE forecast_date = prev_date
	) p
	LEFT JOIN
	(
		SELECT *	
		FROM forecasts
		WHERE forecast_date = curr_date
	) c
	ON p.participant = c.participant
	WHERE c.participant IS NULL
	AND p.participant > 0;
	
	COMMIT;
END;
$$;

CALL auto_fill('2020-10-19', '2020-10-26');

\q



-- Round all forecasts to specified precision
UPDATE forecasts
SET
h1 = ROUND( h1 ),
h2 = ROUND( h2 ),
h3 = ROUND( h3 ),
h4 = ROUND( h4 ),
h5 = ROUND( h5 ),
h6 = ROUND( h6 ),
h7 = ROUND( h7 )
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
ROUND( SUM( h1 ) / COUNT( h1 ) ) AS h1,
ROUND( SUM( h2 ) / COUNT( h2 ) ) AS h2,
ROUND( SUM( h3 ) / COUNT( h3 ) ) AS h3,
ROUND( SUM( h4 ) / COUNT( h4 ) ) AS h4,
ROUND( SUM( h5 ) / COUNT( h5 ) ) AS h5,
ROUND( SUM( h6 ) / COUNT( h6 ) ) AS h6,
ROUND( SUM( h7 ) / COUNT( h7 ) ) AS h7
FROM forecasts
WHERE participant >= 1000
GROUP BY forecast_date;

INSERT INTO forecasts
SELECT * FROM forecasts_group_mean;

CREATE VIEW forecasts_group_median AS
SELECT
forecast_date,
301 AS participant,
ROUND( percentile_disc( 0.5 ) WITHIN GROUP( ORDER BY h1 ) ) AS h1,
ROUND( percentile_disc( 0.5 ) WITHIN GROUP( ORDER BY h2 ) ) AS h2,
ROUND( percentile_disc( 0.5 ) WITHIN GROUP( ORDER BY h3 ) ) AS h3,
ROUND( percentile_disc( 0.5 ) WITHIN GROUP( ORDER BY h4 ) ) AS h4,
ROUND( percentile_disc( 0.5 ) WITHIN GROUP( ORDER BY h5 ) ) AS h5,
ROUND( percentile_disc( 0.5 ) WITHIN GROUP( ORDER BY h6 ) ) AS h6,
ROUND( percentile_disc( 0.5 ) WITHIN GROUP( ORDER BY h7 ) ) AS h7
FROM forecasts
WHERE participant >= 1000
GROUP BY forecast_date;

--INSERT INTO forecasts
--SELECT * FROM forecasts_group_median;


CREATE VIEW forecasts_combination AS
SELECT
forecast_date,
302 AS participant,
ROUND( SUM( h1 ) / COUNT( h1 ) ) AS h1,
ROUND( SUM( h2 ) / COUNT( h2 ) ) AS h2,
ROUND( SUM( h3 ) / COUNT( h3 ) ) AS h3,
ROUND( SUM( h4 ) / COUNT( h4 ) ) AS h4,
ROUND( SUM( h5 ) / COUNT( h5 ) ) AS h5,
ROUND( SUM( h6 ) / COUNT( h6 ) ) AS h6,
ROUND( SUM( h7 ) / COUNT( h7 ) ) AS h7
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
\copy ( SELECT * FROM horizon_errors_view ) TO 'QBUS3850_horizon_results.csv' WITH CSV HEADER

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
\copy ( SELECT * FROM horizon_combined ) TO 'QBUS3850_horizon_combined.csv' WITH CSV HEADER


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
