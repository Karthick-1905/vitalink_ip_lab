import pandas as pd
file_path = './ml_pipeline/data/iwpc_warfarin.xls'
df = pd.read_excel(file_path, sheet_name='Subject Data')
print(f"--- Dataset Shape: {df.shape} ---")
print("\n--- Columns ---")
print(df.columns.tolist())

print("\n--- Missing Values (%) ---")
missing = (df.isnull().sum() / len(df) * 100).sort_values(ascending=False)
print(missing[missing > 0].head(30)) # print top 30 missing

print("\n--- First Row ---")
for col in df.columns:
    print(f"{col}: {df.loc[0, col]}")

