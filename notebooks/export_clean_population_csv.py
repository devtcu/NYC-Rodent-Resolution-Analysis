"""
Export Clean Population CSV

Reads the population xlsx (disguised as .csv) from
/Workspace/Shared/rat_investigation/population.csv,
extracts the useful columns with clean headers, and writes a
consolidated CSV to the same Shared folder.
"""

# Cell 1: Install openpyxl and read xlsx
%pip install openpyxl

import pandas as pd
import os

# Read the xlsx file (disguised as .csv) — first 4 rows are multi-row group headers,
# row 5 (0-indexed row 4) has the actual column names
src_path = "/Workspace/Shared/rat_investigation/population.csv"
df = pd.read_excel(src_path, header=4, engine="openpyxl")

print(f"Raw shape: {df.shape}")
print(f"Columns: {list(df.columns)[:10]}...")
display(df.head(3))

# Cell 2: Clean columns and export CSV
# Select useful columns and rename to clean names
clean_df = df[['name', 'state', 'county', 'city', 'population', 'pop_dens_sq_mi',
               'mhhi', 'avghhi', 'median_age', 'family_poverty_pct',
               'unemployment_pct', 'aland_sq_mi', 'geoid']].copy()

clean_df.columns = ['zip_code', 'state', 'county', 'city', 'population',
                    'population_density', 'median_household_income',
                    'average_household_income', 'median_age', 'poverty_rate',
                    'unemployment_rate', 'land_area_sq_mi', 'geoid']

# Filter for 5-digit NYC ZIP codes only
clean_df = clean_df[clean_df['zip_code'].astype(str).str.match(r'^\d{5}$')].copy()
clean_df['zip_code'] = clean_df['zip_code'].astype(str)

# Clean numeric columns — strip $ and commas from income fields
for col in ['median_household_income', 'average_household_income']:
    if col in clean_df.columns:
        clean_df[col] = clean_df[col].astype(str).str.replace('$', '', regex=False).str.replace(',', '', regex=False)
        clean_df[col] = pd.to_numeric(clean_df[col], errors='coerce')

# Write clean CSV to Shared folder
out_path = "/Workspace/Shared/rat_investigation/population_clean.csv"
clean_df.to_csv(out_path, index=False)

print(f"Clean CSV shape: {clean_df.shape}")
print(f"Written to: {out_path}")
print(f"\nColumns: {list(clean_df.columns)}")
print(f"\nFirst 10 rows:")
display(clean_df.head(10))
