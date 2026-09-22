-- ============================================================================
-- NYC Rodent Resolution Analysis
-- Step 2: Underreporting Score Analysis
-- 
-- Compares rat sightings (311 complaints) vs restaurant inspections (04K violations)
-- to identify ZIP codes with potential underreporting.
-- 
-- Positive score = inspectors finding rats residents aren't reporting
-- Negative score = residents reporting what inspections miss
-- ============================================================================

WITH rat_zip AS (
  SELECT
    TRIM(CAST(incident_zip AS STRING)) AS zipcode,
    COUNT(*) AS total_rat_sightings
  FROM read_files(
    '/Volumes/workspace/default/rat_investigation/rat_sightings.csv',
    format => 'csv',
    header => true,
    inferSchema => true
  )
  WHERE LOWER(TRIM(descriptor)) = 'rat sighting'
    AND incident_zip IS NOT NULL
    AND TRY_CAST(created_date AS DATE) >= DATE '2025-01-01'
    AND TRIM(CAST(incident_zip AS STRING)) RLIKE '^[0-9]{5}$'
  GROUP BY TRIM(CAST(incident_zip AS STRING))
),

restaurant_clean AS (
  SELECT
    TRIM(CAST(zipcode AS STRING)) AS zipcode,
    camis,
    TRY_CAST(inspection_date AS DATE) AS inspection_day,
    UPPER(TRIM(violation_code)) AS violation_code
  FROM read_files(
    '/Volumes/workspace/default/rat_investigation/restaurant_inspections.csv',
    format => 'csv',
    header => true,
    inferSchema => true
  )
  WHERE zipcode IS NOT NULL
    AND camis IS NOT NULL
    AND TRY_CAST(inspection_date AS DATE) >= DATE '2025-01-01'
    AND TRIM(CAST(zipcode AS STRING)) RLIKE '^[0-9]{5}$'
),

restaurant_inspection_level AS (
  SELECT
    zipcode,
    camis,
    inspection_day,
    MAX(CASE WHEN violation_code = '04K' THEN 1 ELSE 0 END) AS had_04k_violation
  FROM restaurant_clean
  GROUP BY zipcode, camis, inspection_day
),

restaurant_zip AS (
  SELECT
    zipcode,
    COUNT(*) AS represented_inspections,
    COUNT(DISTINCT camis) AS inspected_restaurants,
    SUM(had_04k_violation) AS inspections_with_04k,
    100.0 * SUM(had_04k_violation) / NULLIF(COUNT(*), 0) AS percent_inspections_with_04k
  FROM restaurant_inspection_level
  GROUP BY zipcode
),

combined AS (
  SELECT
    i.zipcode,
    COALESCE(r.total_rat_sightings, 0) AS total_rat_sightings,
    i.represented_inspections,
    i.inspected_restaurants,
    i.inspections_with_04k,
    i.percent_inspections_with_04k
  FROM restaurant_zip AS i
  LEFT JOIN rat_zip AS r ON i.zipcode = r.zipcode
  WHERE i.represented_inspections >= 20
),

ranked AS (
  SELECT
    *,
    PERCENT_RANK() OVER (ORDER BY total_rat_sightings) AS complaint_percentile,
    PERCENT_RANK() OVER (ORDER BY percent_inspections_with_04k) AS inspection_evidence_percentile
  FROM combined
),

scored AS (
  SELECT
    *,
    100.0 * (inspection_evidence_percentile - complaint_percentile) AS potential_underreporting_score
  FROM ranked
)

SELECT
  zipcode,
  total_rat_sightings,
  represented_inspections,
  inspected_restaurants,
  inspections_with_04k,
  ROUND(percent_inspections_with_04k, 2) AS percent_inspections_with_04k,
  ROUND(100.0 * complaint_percentile, 1) AS complaint_percentile,
  ROUND(100.0 * inspection_evidence_percentile, 1) AS inspection_evidence_percentile,
  ROUND(potential_underreporting_score, 1) AS potential_underreporting_score,
  CASE
    WHEN potential_underreporting_score >= 40 THEN 'High potential under-reporting signal'
    WHEN potential_underreporting_score >= 20 THEN 'Moderate potential under-reporting signal'
    WHEN potential_underreporting_score <= -40 THEN 'Reporting exceeds restaurant evidence'
    ELSE 'Datasets broadly similar'
  END AS interpretation
FROM scored
ORDER BY potential_underreporting_score DESC;
