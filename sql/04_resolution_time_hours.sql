-- ============================================================================
-- NYC Rodent Resolution Analysis
-- Step 4: Resolution Time in Hours
-- 
-- Calculates resolution time in hours for all closed 311 complaints.
-- ============================================================================

SELECT
  * EXCEPT (_rescued_data),
  TIMESTAMPDIFF(
    HOUR,
    TRY_CAST(created_date AS TIMESTAMP),
    TRY_CAST(closed_date AS TIMESTAMP)
  ) AS resolution_time_hours
FROM read_files(
  '/Volumes/workspace/default/rat_investigation/rat_sightings.csv',
  format => 'csv',
  header => true,
  inferSchema => true
)
WHERE LOWER(TRIM(status)) = 'closed'
  AND closed_date IS NOT NULL;
