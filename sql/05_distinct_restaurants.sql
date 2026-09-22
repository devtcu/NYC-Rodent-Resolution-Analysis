-- ============================================================================
-- NYC Rodent Resolution Analysis
-- Step 5: Distinct Restaurant Names
-- 
-- Lists all distinct restaurant names (DBA) from the inspection data.
-- ============================================================================

SELECT DISTINCT dba
FROM read_files(
  '/Volumes/workspace/default/rat_investigation/restaurant_inspections.csv',
  format => 'csv',
  header => true
)
WHERE dba IS NOT NULL
ORDER BY dba;
