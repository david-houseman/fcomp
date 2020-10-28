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


-- Use the previous week's forecasts if this week's are missing.
CREATE OR REPLACE PROCEDURE auto_fill(curr_date DATE)
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
	
	COMMIT;
END;
$$;

CREATE OR REPLACE PROCEDURE clean(comp_start DATE, comp_end DATE)
LANGUAGE plpgsql
AS $$
DECLARE
	d DATE := comp_start;
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

	COMMIT;
END;
$$;

CALL clean('2020-10-19', '2020-10-26');
SELECT * FROM participants;
SELECT * FROM forecasts ORDER BY forecast_date, participant;

