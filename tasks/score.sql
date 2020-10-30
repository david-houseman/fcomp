SET client_min_messages TO WARNING;

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

----------------------------------------------------------------------------------

--DELETE FROM submissions;
--\copy submissions FROM ../data/submissions.csv WITH CSV DELIMITER '|'
--SELECT * FROM submissions;

-- Take a backup copy of submissions. This gets written as user pgadmin.
COPY submissions TO '/tmp/submissions.csv' WITH CSV DELIMITER '|';

----------------------------------------------------------------------------------

DROP PROCEDURE IF EXISTS add_participant;
DROP PROCEDURE IF EXISTS main;
DROP PROCEDURE IF EXISTS main_guess_dates;
DROP PROCEDURE IF EXISTS auto_bench;
DROP PROCEDURE IF EXISTS clean;
DROP PROCEDURE IF EXISTS auto_fill;
DROP VIEW IF EXISTS submissions_dedup;
DROP VIEW IF EXISTS submissions_view;
DROP TABLE IF EXISTS forecasts CASCADE;
DROP TABLE IF EXISTS participants CASCADE;


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


CREATE VIEW forecasts_view AS
SELECT *
FROM forecasts
JOIN participants
USING (participant)
ORDER BY forecast_date, participant;

----------------------------------------------------------------------------------

CREATE VIEW submissions_view AS
SELECT *
FROM submissions
ORDER BY forecast_date, forecast_time, participant;


-- Select the most recent forecasts for each (forecast_date, participant).
CREATE VIEW submissions_dedup AS
SELECT DISTINCT ON (forecast_date, participant)
forecast_date, participant, origin, h1, h2, h3, h4, h5, h6, h7
FROM submissions
ORDER BY forecast_date, participant, forecast_time DESC;



-- Use the previous week's forecasts if this week's are missing.
CREATE PROCEDURE auto_fill(curr_date DATE)
LANGUAGE plpgsql
AS $$
BEGIN
	INSERT INTO forecasts
	SELECT curr_date, p.participant, 'A', p.h1, p.h2, p.h3, p.h4, p.h5, p.h6, p.h7
	FROM
	(  	
		SELECT *
		FROM forecasts
		WHERE forecast_date = curr_date - 7
	) p
	LEFT JOIN
	(
		SELECT *	
		FROM forecasts
		WHERE forecast_date = curr_date
	) c
	ON p.participant = c.participant
	WHERE c.participant IS NULL
	AND p.origin != 'B';
END;
$$;

CREATE PROCEDURE clean(comp_start DATE, comp_end DATE)
LANGUAGE plpgsql
AS $$
DECLARE
	d DATE;	
BEGIN
	DELETE FROM forecasts;
	DELETE FROM participants;

	-- Populate the participants table with the (unique) participants of week 1.	
	INSERT INTO participants
	SELECT DISTINCT ON (participant)
	participant, fullname
	FROM submissions
	WHERE forecast_date = comp_start
	ORDER BY participant, forecast_time DESC;		

	-- Populate the forecasts table with the deduplicated submissions,
	-- from known participants only.
	INSERT INTO forecasts
	SELECT forecast_date, participant, origin, h1, h2, h3, h4, h5, h6, h7
	FROM submissions_dedup
	JOIN participants USING (participant);

	-- Call auto_fill() sequentially for each week of the competition.
	d := comp_start;
	LOOP
		d := d + 7;
		EXIT WHEN d > comp_end;
		CALL auto_fill(d);
	END LOOP;

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
END;
$$;


CREATE VIEW forecasts_combination AS
SELECT
forecast_date,
200 AS participant,
'B' AS origin,
ROUND( SUM( h1 ) / COUNT( h1 ) ) AS h1,
ROUND( SUM( h2 ) / COUNT( h2 ) ) AS h2,
ROUND( SUM( h3 ) / COUNT( h3 ) ) AS h3,
ROUND( SUM( h4 ) / COUNT( h4 ) ) AS h4,
ROUND( SUM( h5 ) / COUNT( h5 ) ) AS h5,
ROUND( SUM( h6 ) / COUNT( h6 ) ) AS h6,
ROUND( SUM( h7 ) / COUNT( h7 ) ) AS h7
FROM forecasts
WHERE origin = 'B'
AND participant > 0
GROUP BY forecast_date;


CREATE VIEW forecasts_group_mean AS
SELECT
forecast_date,
400 AS participant,
'B' AS origin,
ROUND( SUM( h1 ) / COUNT( h1 ) ) AS h1,
ROUND( SUM( h2 ) / COUNT( h2 ) ) AS h2,
ROUND( SUM( h3 ) / COUNT( h3 ) ) AS h3,
ROUND( SUM( h4 ) / COUNT( h4 ) ) AS h4,
ROUND( SUM( h5 ) / COUNT( h5 ) ) AS h5,
ROUND( SUM( h6 ) / COUNT( h6 ) ) AS h6,
ROUND( SUM( h7 ) / COUNT( h7 ) ) AS h7
FROM forecasts
WHERE origin = 'M'
GROUP BY forecast_date;


CREATE VIEW forecasts_group_median AS
SELECT
forecast_date,
401 AS participant,
'B' AS origin,
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



CREATE PROCEDURE auto_bench()
LANGUAGE plpgsql
AS $$
BEGIN
	--INSERT INTO participants
	--VALUES (200, '**Combination**');

	--INSERT INTO forecasts
	--SELECT * FROM forecasts_combination;

	INSERT INTO participants
	VALUES (400, '**Group Mean**');

	INSERT INTO forecasts
	SELECT * FROM forecasts_group_mean;
	
	--INSERT INTO participants
	--VALUES (401, 'Group Median');

	--INSERT INTO forecasts
	--SELECT * FROM forecasts_group_median;
END;
$$;


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



------------------------------------------------------------------------------



CREATE PROCEDURE main(comp_start DATE, comp_end DATE)
LANGUAGE plpgsql
AS $$
BEGIN
	CALL clean(comp_start, comp_end);
	CALL auto_bench();
END;
$$;

CREATE PROCEDURE main_guess_dates()
LANGUAGE plpgsql
AS $$
DECLARE
	comp_start DATE;
	comp_end DATE;
BEGIN
	SELECT MIN(forecast_date)
	INTO comp_start
	FROM submissions
	WHERE origin = 'M';

	SELECT MAX(forecast_date)
	INTO comp_end
	FROM submissions
	WHERE origin = 'M';

	CALL clean(comp_start, comp_end);
	CALL auto_bench();
END;
$$;


CREATE PROCEDURE add_participant(new_participant INTEGER, new_fullname VARCHAR)
LANGUAGE plpgsql
AS $$
DECLARE
	comp_start DATE;
BEGIN
	SELECT MIN(forecast_date)
	INTO comp_start
	FROM submissions
	WHERE origin = 'M';

	INSERT INTO submissions
	SELECT comp_start,'09:00:00', new_participant, new_fullname, 'A',
	       h1, h2, h3, h4, h5, h6, h7
	FROM submissions WHERE forecast_date = comp_start AND participant = 101;
END;
$$;

--CALL add_participant(555555555,'David Q');
--CALL main();

--SELECT * FROM participants;
--SELECT * FROM forecasts_view;
--SELECT * FROM week_errors_view;
--SELECT * FROM overall_errors_view;
--SELECT * FROM horizon_errors_view;
--SELECT * FROM horizon_combined;

--\copy ( SELECT * FROM submissions_view ) TO 'submissions.csv' WITH CSV HEADER DELIMITER '|'
--\copy ( SELECT * FROM forecasts_view ) TO 'forecasts.csv' WITH CSV HEADER DELIMITER '|'
--\copy ( SELECT * FROM week_errors_view ) TO 'week_results.csv' WITH CSV HEADER DELIMITER '|'
--\copy ( SELECT * FROM overall_errors_view ) TO 'overall_results.csv' WITH CSV HEADER DELIMITER '|'
--\copy ( SELECT * FROM horizon_errors_view ) TO 'horizon_results.csv' WITH CSV HEADER DELIMITER '|'
--\copy ( SELECT * FROM horizon_combined ) TO 'horizon_combined.csv' WITH CSV HEADER DELIMITER '|'

