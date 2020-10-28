DROP VIEW forecasts_group_mean;
CREATE VIEW forecasts_group_mean AS
SELECT
forecast_date,
300 AS participant,
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


DROP VIEW forecasts_group_median;
CREATE VIEW forecasts_group_median AS
SELECT
forecast_date,
301 AS participant,
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


DROP VIEW forecasts_combination;
CREATE VIEW forecasts_combination AS
SELECT
forecast_date,
302 AS participant,
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


CREATE OR REPLACE PROCEDURE auto_bench()
LANGUAGE plpgsql
AS $$
BEGIN
	INSERT INTO participants
	VALUES
	(300, 'Group Mean'),
	(301, 'Group Median'),
	(302, 'Combination Benchmark')
	ON CONFLICT DO NOTHING;

	INSERT INTO forecasts
	SELECT * FROM forecasts_group_mean;

	--INSERT INTO forecasts
	--SELECT * FROM forecasts_group_median;

	--INSERT INTO forecasts
	--SELECT * FROM forecasts_combination;

	COMMIT;
END;
$$;

CALL auto_bench();

