# NYC Rodent Resolution Analysis


> A data-driven investigation into NYC's rodent problem — comparing resident complaints (311) with restaurant inspection evidence (DOH) to identify underreporting, measure resolution times, and visualize service gaps across ZIP codes.
>
> **Built for the Databricks AI Hackathon + Networking NYC** (September 18-20, 2026)  
> Hosted by Databricks, Q Tech Incubator @ Queens College, and WAGMI-Connect

---

## Overview

This project analyzes two public NYC datasets — **311 rodent complaints** and **DOH restaurant inspections** — alongside **census population data** to answer a critical question: *Where is NYC's rodent problem being underreported?*

By cross-referencing where residents report rats (311 complaints) with where inspectors actually find them (violation code 04K), we identify ZIP codes with significant service gaps — areas where the city's inspection evidence suggests a bigger rodent problem than residents are reporting.

### Key Questions

1. **Underreporting:** Which ZIP codes have high inspection evidence of rats but low resident complaints?
2. **Resolution Speed:** How long does it take NYC to resolve rodent complaints, and which ZIP codes are slowest?
3. **Service Equity:** Are rodent complaints and inspection resources distributed proportionally across boroughs and populations?


## Data Sources

| Dataset | File | Description |
| --- | --- | --- |
| NYC 311 Rodent Complaints | `data/rat_sightings.csv` | Resident rodent complaints (rat sightings, mouse sightings, signs of rodents, conditions attracting rodents) with ZIP codes, boroughs, and lat/long |
| NYC DOH Restaurant Inspections | `data/restaurant_inspections.csv` | Restaurant inspection records with violation codes (04K = rats, 04L = mice, 08A = conditions conducive to rodents) |
| NYC Census Demographics | `data/population.csv` | Population, income, age, poverty, and unemployment by ZIP code (Excel format, cleaned via notebook) |
| Cleaned Population Data | `data/population_clean.csv` | Consolidated population CSV with 13 columns (zip_code, population, density, income, poverty rate, etc.) |

### Final Analysis Tables (`data/Final_Tables/`)

| File | Description |
| --- | --- |
| `Final.csv` | Combined per-ZIP analysis: sightings, resolution times, inspection evidence, underreporting scores, and interpretation |
| `inspection and resolution.csv` | Inspection counts and resolution time statistics by ZIP |
| `mean and median rat sightings.csv` | Aggregated rat sighting statistics by ZIP |
| `under_reporting.csv` | Underreporting score analysis results |


## SQL Pipeline

The analysis runs as a 5-step SQL pipeline in Databricks:

### Step 1: Create Normalized Tables (`sql/01_create_normalized_tables.sql`)

Creates three Unity Catalog tables from raw CSV sources:
- `rat_sightings_normalized` — 311 rodent complaints with ZIP codes normalized to 5-digit zero-padded strings
- `restaurant_inspections_normalized` — DOH inspections with a boolean `is_rodent_violation` flag (04K + 04L + 08A)
- `zip_rodent_index` — Pre-aggregated summary table, one row per ZIP (FULL OUTER JOIN of the above)

### Step 2: Underreporting Score Analysis (`sql/02_underreporting_score_analysis.sql`)

The core analysis. For each ZIP code with >=20 restaurant inspections:
- Computes **rats found rate** = % of inspections with 04K violations
- Computes **rats reported** = total 311 rat sighting complaints
- Ranks both metrics via `PERCENT_RANK()` across all ZIP codes
- Calculates **Underreporting Score** = `100 x (inspection_evidence_percentile - complaint_percentile)`
- Classifies results:
  - **Score >= 40:** High potential under-reporting signal
  - **Score 20-39:** Moderate potential under-reporting signal
  - **Score <= -40:** Reporting exceeds restaurant evidence
  - **Otherwise:** Datasets broadly similar

### Step 3: Resolution Time by ZIP (`sql/03_resolution_time_by_zip.sql`)

Calculates median and average resolution time (in days) for closed rat sighting complaints, grouped by ZIP code.

### Step 4: Resolution Time in Hours (`sql/04_resolution_time_hours.sql`)

Computes resolution time in hours for all closed 311 complaints.

### Step 5: Distinct Restaurants (`sql/05_distinct_restaurants.sql`)

Lists all distinct restaurant names (DBA) from the inspection data for reference.


## Notebook

### `notebooks/export_clean_population_csv.py`

A Python notebook that:
1. Reads the population Excel file (disguised as `.csv`) using `openpyxl`
2. Extracts 13 useful columns (population, density, income, poverty rate, etc.)
3. Filters for 5-digit NYC ZIP codes
4. Cleans numeric fields (strips `$` and commas from income columns)
5. Exports a clean `population_clean.csv` for use in the dashboards


## Dashboards

Built with **Databricks AI/BI (Lakeview)** — two interactive dashboards with a combined 4 pages:

### Dashboard 1: NYC Rodent Activity Dashboard (`dashboards/NYC_Rodent_Activity_Dashboard.lvdash.json`)

**Page 1 - Overview**
- KPI counters: Total rat sightings, restaurant inspections, rodent violations, restaurants with rodent violations
- Bar charts by borough: Rat sightings, rodent violations, inspections, restaurants with violations
- ZIP code detail table with **Rodent Index Score** (composite 0-100):
  - Rat sightings: 40%
  - Rodent violations: 30%
  - Signs + conditions: 20%
  - Restaurants with violations: 10%
- Borough and ZIP code filters

**Page 2 - Service Gap Index**

Implements the Service Gap Index design comparing rats found vs rats reported:
- **Rats found** = distinct restaurants with 04K violation / distinct restaurants inspected
- **Rats reported** = distinct rat-sighting locations per 10,000 residents
- **Gap Index** = rats-found percentile - rats-reported percentile
- ZIPs with <10 inspected restaurants get no score
- **Enough-data flag** requires >=10 inspected restaurants AND >=1,000 residents
- KPIs, borough bar charts, and detailed ZIP-level table
- Positive gap = inspectors finding rats residents aren't reporting
- Negative gap = residents reporting what inspections miss (common in residential areas)

**Page 3 - Diagnostic Analysis**
- Inflation factor by borough (inspection intensity effects)
- Closure rate (30+ day) by borough
- Inspections per restaurant by borough
- Rodent violations per inspection by borough
- Scatter plots: inspections vs violation rows, inspection intensity vs rats found rate

### Dashboard 2: NYC Rodent Resolution Analysis (`dashboards/NYC_Rodent_Resolution_Analysis.lvdash.json`)

**Page 1 - Rodent Dashboards**
- Per-ZIP rodent analysis detail table (sightings, inspections, 04K violations, percentiles, underreporting scores)
- Choropleth map: Average % unresolved within 30 days by ZIP code
- Symbol map: Underreporting severity - "Golden Triangles" (ZIPs where rats found >> rats reported)
- ZIP code filter


## Key Metrics

| Metric | Formula | Interpretation |
| --- | --- | --- |
| Rodent Index Score | Weighted composite (0-100) of sightings, violations, signs, and restaurants | Higher = worse rodent problem |
| Service Gap Index | Rats-found percentile - rats-reported percentile | Positive = underreporting; Negative = over-reporting |
| Underreporting Score | 100 x (inspection percentile - complaint percentile) | >=40 = high signal; <=-40 = reporting exceeds evidence |
| Resolution Time | `closed_date - created_date` (days/hours) | Lower = faster service |


## Tech Stack

- **Databricks** — SQL warehouse, Unity Catalog, AI/BI Lakeview dashboards
- **Python** — Data cleaning (pandas, openpyxl)
- **SQL** — Analysis pipeline with `read_files()`, `PERCENT_RANK()`, window functions
- **Data Sources** — NYC Open Data (311 complaints, DOH restaurant inspections, Census demographics)


## Repository Structure

```
NYC-Rodent-Resolution-Analysis/
├── .gitignore
├── README.md
├── data/
│   ├── rat_sightings.csv
│   ├── restaurant_inspections.csv
│   ├── population.csv
│   ├── population_clean.csv
│   └── Final_Tables/
│       ├── Final.csv
│       ├── inspection and resolution.csv
│       ├── mean and median rat sightings.csv
│       └── under_reporting.csv
├── notebooks/
│   └── export_clean_population_csv.py
├── sql/
│   ├── 01_create_normalized_tables.sql
│   ├── 02_underreporting_score_analysis.sql
│   ├── 03_resolution_time_by_zip.sql
│   ├── 04_resolution_time_hours.sql
│   └── 05_distinct_restaurants.sql
└── dashboards/
    ├── NYC_Rodent_Activity_Dashboard.lvdash.json
    └── NYC_Rodent_Resolution_Analysis.lvdash.json
```


## How to Reproduce

1. **Upload data** to a Databricks Unity Catalog volume or workspace folder
2. **Run the SQL pipeline** in order: `01` -> `02` -> `03` -> `04` -> `05`
3. **Run the notebook** `notebooks/export_clean_population_csv.py` to generate `population_clean.csv`
4. **Import dashboards** — Upload the `.lvdash.json` files to Databricks and update the data source paths to match your environment


*Built for the Databricks Hackathon — analyzing NYC's rodent problem through the lens of data equity and service gaps.*