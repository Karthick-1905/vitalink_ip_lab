import pandas as pd
file_path = './ml_pipeline/data/iwpc_warfarin.xls'
excel_file = pd.ExcelFile(file_path)
print("Sheet Names:", excel_file.sheet_names)
