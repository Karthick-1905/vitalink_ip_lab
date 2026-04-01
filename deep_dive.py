import pandas as pd
file_path = './ml_pipeline/data/iwpc_warfarin.xls'
df = pd.read_excel(file_path, sheet_name='Subject Data')
print("--- Age Categories ---")
print(df['Age'].value_counts(dropna=False))

print("\n--- Target Variable 'Therapeutic Dose of Warfarin' ---")
print(df['Therapeutic Dose of Warfarin'].describe())
print(f"Missing target: {df['Therapeutic Dose of Warfarin'].isnull().sum()}")

print("\n--- CYP2C9 Genotypes ---")
print(df['Cyp2C9 genotypes'].value_counts(dropna=False).head(10))

print("\n--- VKORC1 -1639 consensus ---")
print(df['VKORC1 -1639 consensus'].value_counts(dropna=False))

