-- ============================================================================
-- NYC Rodent Resolution Analysis
-- Step 1: Create normalized tables from raw CSV sources
-- 
-- Creates three tables in workspace.default:
--   1. rat_sightings_normalized  — NYC 311 rodent complaints
--   2. restaurant_inspections_normalized  — NYC DOH restaurant inspections
--   3. zip_rodent_index  — Pre-aggregated summary, one row per ZIP code
-- 
-- Source CSVs: /Volumes/workspace/default/rat_investigation/
-- ============================================================================

-- ============================================================================
-- 1. NORMALIZED RAT SIGHTINGS TABLE
--    ZIP codes normalized to 5-digit zero-padded strings for joining.
--    All rows have complaint_type = 'Rodent' and are retained as rodent complaints.
--    Descriptors: Rat Sighting, Mouse Sighting, Signs of Rodents, Condition Attracting Rodents.
-- ============================================================================
CREATE OR REPLACE TABLE workspace.default.rat_sightings_normalized AS
SELECT
  unique_key,
  created_date,
  closed_date,
  status,
  complaint_type,
  descriptor,
  location_type,
  LPAD(CAST(incident_zip AS STRING), 5, '0') AS zip_code,
  borough,
  latitude,
  longitude
FROM read_files(
  '/Volumes/workspace/default/rat_investigation/rat_sightings.csv',
  format => 'csv',
  header => true
)
WHERE incident_zip IS NOT NULL
  AND incident_zip > 0
  AND incident_zip <= 99999;

-- ============================================================================
-- 2. NORMALIZED RESTAURANT INSPECTIONS TABLE
--    ZIP codes normalized to 5-digit zero-padded strings for joining.
--    Rodent-related violations flagged: 04K (rats), 04L (mice), 08A (conditions conducive to rodents).
-- ============================================================================
CREATE OR REPLACE TABLE workspace.default.restaurant_inspections_normalized AS
SELECT
  camis,
  dba,
  boro,
  LPAD(CAST(zipcode AS STRING), 5, '0') AS zip_code,
  cuisine_description,
  inspection_date,
  violation_code,
  violation_description,
  critical_flag,
  TRY_CAST(score AS INT) AS score,
  grade,
  CASE
    WHEN violation_code IN ('04K', '04L', '08A') THEN true
    ELSE false
  END AS is_rodent_violation
FROM read_files(
  '/Volumes/workspace/default/rat_investigation/restaurant_inspections.csv',
  format => 'csv',
  header => true
)
WHERE zipcode IS NOT NULL
  AND zipcode > 0
  AND zipcode <= 99999;

-- ============================================================================
-- 3. ZIP CODE RODENT INDEX TABLE
--    One row per ZIP code. Aggregates rodent complaints and restaurant rodent violations.
--    Built by FULL OUTER JOIN on normalized ZIP code.
-- ============================================================================
CREATE OR REPLACE TABLE workspace.default.zip_rodent_index AS
WITH rat_agg AS (
  SELECT
    zip_code,
    ANY_VALUE(borough) AS borough,
    COUNT(*) AS rat_sightings_total,
    SUM(CASE WHEN descriptor = 'Rat Sighting'              THEN 1 ELSE 0 END) AS rat_sightings_rat,
    SUM(CASE WHEN descriptor = 'Mouse Sighting'            THEN 1 ELSE 0 END) AS rat_sightings_mouse,
    SUM(CASE WHEN descriptor = 'Signs of Rodents'         THEN 1 ELSE 0 END) AS rat_sightings_signs,
    SUM(CASE WHEN descriptor = 'Condition Attracting Rodents' THEN 1 ELSE 0 END) AS rat_sightings_conditions
  FROM workspace.default.rat_sightings_normalized
  GROUP BY zip_code
),
rest_agg AS (
  SELECT
    zip_code,
    ANY_VALUE(boro) AS boro,
    COUNT(*) AS restaurant_inspections_total,
    SUM(CASE WHEN is_rodent_violation THEN 1 ELSE 0 END) AS restaurant_rodent_violations,
    SUM(CASE WHEN violation_code = '04K' THEN 1 ELSE 0 END) AS restaurant_rats_violations,
    SUM(CASE WHEN violation_code = '04L' THEN 1 ELSE 0 END) AS restaurant_mice_violations,
    SUM(CASE WHEN violation_code = '08A' THEN 1 ELSE 0 END) AS restaurant_rodent_conditions,
    COUNT(DISTINCT CASE WHEN is_rodent_violation THEN camis END) AS restaurants_with_rodent_violations
  FROM workspace.default.restaurant_inspections_normalized
  GROUP BY zip_code
)
SELECT
  COALESCE(r.zip_code, ri.zip_code) AS zip_code,
  COALESCE(r.borough, ri.boro) AS borough,
  COALESCE(r.rat_sightings_total, 0) AS rat_sightings_total,
  COALESCE(r.rat_sightings_rat, 0) AS rat_sightings_rat,
  COALESCE(r.rat_sightings_mouse, 0) AS rat_sightings_mouse,
  COALESCE(r.rat_sightings_signs, 0) AS rat_sightings_signs,
  COALESCE(r.rat_sightings_conditions, 0) AS rat_sightings_conditions,
  COALESCE(ri.restaurant_inspections_total, 0) AS restaurant_inspections_total,
  COALESCE(ri.restaurant_rodent_violations, 0) AS restaurant_rodent_violations,
  COALESCE(ri.restaurant_rats_violations, 0) AS restaurant_rats_violations,
  COALESCE(ri.restaurant_mice_violations, 0) AS restaurant_mice_violations,
  COALESCE(ri.restaurant_rodent_conditions, 0) AS restaurant_rodent_conditions,
  COALESCE(ri.restaurants_with_rodent_violations, 0) AS restaurants_with_rodent_violations
FROM rat_agg r
FULL OUTER JOIN rest_agg ri ON r.zip_code = ri.zip_code;

-- ============================================================================
-- 4. TABLE DESCRIPTIONS
-- ============================================================================
COMMENT ON TABLE workspace.default.rat_sightings_normalized IS 'NYC 311 rodent complaints (rat sightings, mouse sightings, signs of rodents, conditions attracting rodents) with ZIP codes normalized to 5-digit zero-padded strings. Source: /Volumes/workspace/default/rat_investigation/rat_sightings.csv';

COMMENT ON TABLE workspace.default.restaurant_inspections_normalized IS 'NYC DOH restaurant inspection records with ZIP codes normalized to 5-digit zero-padded strings. Includes a boolean flag is_rodent_violation for violation codes 04K (rats), 04L (mice), and 08A (conditions conducive to rodents). Source: /Volumes/workspace/default/rat_investigation/restaurant_inspections.csv';

COMMENT ON TABLE workspace.default.zip_rodent_index IS 'One row per ZIP code summarizing rodent complaints from 311 and rodent-related restaurant inspection violations. Built by FULL OUTER JOIN on normalized ZIP codes between rat_sightings_normalized and restaurant_inspections_normalized.';

-- ============================================================================
-- 5. COLUMN DESCRIPTIONS — rat_sightings_normalized
-- ============================================================================
COMMENT ON COLUMN workspace.default.rat_sightings_normalized.unique_key IS 'Unique identifier for the 311 service request.';
COMMENT ON COLUMN workspace.default.rat_sightings_normalized.created_date IS 'Date and time the complaint was filed.';
COMMENT ON COLUMN workspace.default.rat_sightings_normalized.closed_date IS 'Date and time the complaint was closed (null if still open).';
COMMENT ON COLUMN workspace.default.rat_sightings_normalized.status IS 'Status of the complaint (e.g., In Progress, Closed).';
COMMENT ON COLUMN workspace.default.rat_sightings_normalized.complaint_type IS 'Type of 311 complaint. All rows are Rodent.';
COMMENT ON COLUMN workspace.default.rat_sightings_normalized.descriptor IS 'Specific complaint descriptor: Rat Sighting, Mouse Sighting, Signs of Rodents, or Condition Attracting Rodents.';
COMMENT ON COLUMN workspace.default.rat_sightings_normalized.location_type IS 'Location where the rodent was reported (e.g., Sidewalk, Commercial Building, 1-2 Family Dwelling).';
COMMENT ON COLUMN workspace.default.rat_sightings_normalized.zip_code IS 'NYC ZIP code normalized to a 5-digit zero-padded string for joining with other datasets.';
COMMENT ON COLUMN workspace.default.rat_sightings_normalized.borough IS 'NYC borough where the complaint was reported (Manhattan, Brooklyn, Queens, Bronx, Staten Island).';
COMMENT ON COLUMN workspace.default.rat_sightings_normalized.latitude IS 'Latitude coordinate of the complaint location.';
COMMENT ON COLUMN workspace.default.rat_sightings_normalized.longitude IS 'Longitude coordinate of the complaint location.';

-- ============================================================================
-- 6. COLUMN DESCRIPTIONS — restaurant_inspections_normalized
-- ============================================================================
COMMENT ON COLUMN workspace.default.restaurant_inspections_normalized.camis IS 'Unique restaurant identifier (Critical Area Management Information System ID) assigned by NYC DOH.';
COMMENT ON COLUMN workspace.default.restaurant_inspections_normalized.dba IS 'Doing Business As — the restaurant or food establishment name.';
COMMENT ON COLUMN workspace.default.restaurant_inspections_normalized.boro IS 'NYC borough where the restaurant is located. Note: some records contain 0 for unknown borough.';
COMMENT ON COLUMN workspace.default.restaurant_inspections_normalized.zip_code IS 'Restaurant ZIP code normalized to a 5-digit zero-padded string for joining with other datasets.';
COMMENT ON COLUMN workspace.default.restaurant_inspections_normalized.cuisine_description IS 'Type of cuisine served by the establishment (e.g., Chinese, Pizza, American).';
COMMENT ON COLUMN workspace.default.restaurant_inspections_normalized.inspection_date IS 'Date the restaurant inspection was performed.';
COMMENT ON COLUMN workspace.default.restaurant_inspections_normalized.violation_code IS 'DOH violation code (e.g., 04K for rats, 04L for mice, 08A for conditions conducive to rodents). Null if no violation was cited.';
COMMENT ON COLUMN workspace.default.restaurant_inspections_normalized.violation_description IS 'Full text description of the violation. Null if no violation was cited.';
COMMENT ON COLUMN workspace.default.restaurant_inspections_normalized.critical_flag IS 'Whether the violation is Critical, Not Critical, or Not Applicable.';
COMMENT ON COLUMN workspace.default.restaurant_inspections_normalized.score IS 'Numeric inspection score (lower is better). Cast from source string to integer; null if not applicable.';
COMMENT ON COLUMN workspace.default.restaurant_inspections_normalized.grade IS 'Letter grade assigned by DOH (A, B, C, N, Z, or P). Null if not graded.';
COMMENT ON COLUMN workspace.default.restaurant_inspections_normalized.is_rodent_violation IS 'Boolean flag: true if violation_code is 04K (rats), 04L (mice), or 08A (conditions conducive to rodents). False otherwise.';

-- ============================================================================
-- 7. COLUMN DESCRIPTIONS — zip_rodent_index
-- ============================================================================
COMMENT ON COLUMN workspace.default.zip_rodent_index.zip_code IS '5-digit zero-padded ZIP code. Primary key for this index table.';
COMMENT ON COLUMN workspace.default.zip_rodent_index.borough IS 'NYC borough for this ZIP code. Sourced from rat_sightings_normalized if available, otherwise from restaurant_inspections_normalized.';
COMMENT ON COLUMN workspace.default.zip_rodent_index.rat_sightings_total IS 'Total number of 311 rodent complaints (all descriptors) in this ZIP code.';
COMMENT ON COLUMN workspace.default.zip_rodent_index.rat_sightings_rat IS 'Number of 311 complaints with descriptor Rat Sighting in this ZIP code.';
COMMENT ON COLUMN workspace.default.zip_rodent_index.rat_sightings_mouse IS 'Number of 311 complaints with descriptor Mouse Sighting in this ZIP code.';
COMMENT ON COLUMN workspace.default.zip_rodent_index.rat_sightings_signs IS 'Number of 311 complaints with descriptor Signs of Rodents in this ZIP code.';
COMMENT ON COLUMN workspace.default.zip_rodent_index.rat_sightings_conditions IS 'Number of 311 complaints with descriptor Condition Attracting Rodents in this ZIP code.';
COMMENT ON COLUMN workspace.default.zip_rodent_index.restaurant_inspections_total IS 'Total number of restaurant inspections recorded in this ZIP code.';
COMMENT ON COLUMN workspace.default.zip_rodent_index.restaurant_rodent_violations IS 'Total rodent-related restaurant violations (codes 04K + 04L + 08A) in this ZIP code.';
COMMENT ON COLUMN workspace.default.zip_rodent_index.restaurant_rats_violations IS 'Number of restaurant violations for evidence of rats (code 04K) in this ZIP code.';
COMMENT ON COLUMN workspace.default.zip_rodent_index.restaurant_mice_violations IS 'Number of restaurant violations for evidence of mice (code 04L) in this ZIP code.';
COMMENT ON COLUMN workspace.default.zip_rodent_index.restaurant_rodent_conditions IS 'Number of restaurant violations for conditions conducive to rodents (code 08A) in this ZIP code.';
COMMENT ON COLUMN workspace.default.zip_rodent_index.restaurants_with_rodent_violations IS 'Count of distinct restaurants with at least one rodent violation in this ZIP code.';
