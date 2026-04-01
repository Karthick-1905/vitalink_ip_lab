import pandas as pd
import numpy as np

# Load the dataset
file_path = './ml_pipeline/data/iwpc_warfarin.xls'
try:
    df = pd.read_excel(file_path, sheet_name=0) # often it's in the first sheet
    print(f"--- Dataset Shape: {df.shape} ---")
    print("\n--- Columns ---")
    print(df.columns.tolist())
    
    print("\n--- Missing Values (%) ---")
    missing = (df.isnull().sum() / len(df) * 100).sort_values(ascending=False)
    print(missing[missing > 0].head(20)) # print top 20 missing
    
    print("\n--- Data Types ---")
    print(df.dtypes.value_counts())
    
    print("\n--- Sample (First 2 Rows) ---")
    print(df.head(2).T)
    
    # Try to identify the target variable. Usually it's 'Therapeutic Dose of Warfarin'
    target_cols = [col for col in df.columns if 'dose' in col.lower() or 'warfarin' in col.lower()]
    print("\n--- Potential Target Columns ---")
    print(target_cols)
    
except Exception as e:
    print(f"Error reading file: {e}")
