-- ============================================================================
-- NYC Rodent Resolution Analysis
-- Step 3: Resolution Time by ZIP Code
-- 
-- Calculates median and average resolution time (in days) for closed rat
-- sighting complaints, grouped by ZIP code.
-- ============================================================================

WITH closed_rat_sightings AS (
  SELECT
    incident_zip,
    TIMESTAMPDIFF(
      HOUR,
      TRY_CAST(created_date AS TIMESTAMP),
      TRY_CAST(closed_date AS TIMESTAMP)
    ) / 24.0 AS resolution_time_days
  FROM read_files(
    '/Volumes/workspace/default/rat_investigation/rat_sightings.csv',
    format => 'csv',
    header => true,
    inferSchema => true
  )
  WHERE LOWER(TRIM(status)) = 'closed'
    AND LOWER(TRIM(descriptor)) = 'rat sighting'
    AND created_date IS NOT NULL
    AND closed_date IS NOT NULL
)

SELECT
  incident_zip,
  COUNT(*) AS closed_rat_sightings,
  ROUND(MEDIAN(resolution_time_days), 2) AS median_resolution_days,
  ROUND(AVG(resolution_time_days), 2) AS average_resolution_days
FROM closed_rat_sightings
WHERE incident_zip IS NOT NULL
  AND resolution_time_days >= 0
GROUP BY incident_zip
ORDER BY median_resolution_days DESC;
