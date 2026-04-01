import joblib
import pandas as pd
import numpy as np
import argparse
import sys

# Load the model once
MODEL_PATH = './ml_pipeline/models/best_warfarin_model.joblib'
try:
    model = joblib.load(MODEL_PATH)
except FileNotFoundError:
    print(f"Error: Could not find model at {MODEL_PATH}. Make sure to run train_warfarin_models.py first.")
    sys.exit(1)

def predict_warfarin_dose(patient_data: dict) -> float:
    """
    Predicts the required Warfarin dosage (mg/week) for a patient.
    
    Expected keys in patient_data:
    - 'Age_Num': Numeric (e.g., 6.5 for "60-69", 4.5 for "40-49")
    - 'Height (cm)': Numeric
    - 'Weight (kg)': Numeric
    - 'Amiodarone': 1.0 (taking) or 0.0 (not taking)
    - 'Enzyme_Inducer': 1.0 (taking Carbamazepine, Phenytoin, or Rifampin) or 0.0
    - 'Race_Group': String ('White', 'Black', 'Asian', or 'Other')
    - 'CYP2C9': String ('*1/*1', '*1/*2', '*1/*3', '*2/*2', '*2/*3', '*3/*3', or 'Unknown')
    - 'VKORC1': String ('A/A', 'A/G', 'G/G', or 'Unknown')
    """
    
    # Convert single patient dict to a DataFrame
    df = pd.DataFrame([patient_data])
    
    # The model predicts the square root of the dose
    sqrt_dose_pred = model.predict(df)[0]
    
    # Square it to get mg/week
    dose_mg_week = np.square(np.maximum(sqrt_dose_pred, 0))
    
    return dose_mg_week

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Predict Warfarin Dose (mg/week) based on patient data.")
    
    parser.add_argument('--age', type=float, required=True, help="Decade midpoint (e.g. 6.5 for 60-69)")
    parser.add_argument('--height', type=float, required=True, help="Height in cm")
    parser.add_argument('--weight', type=float, required=True, help="Weight in kg")
    parser.add_argument('--race', type=str, default="Unknown", help="White, Black, Asian, or Other")
    parser.add_argument('--amiodarone', type=float, default=0.0, help="1.0 if taking Amiodarone, else 0.0")
    parser.add_argument('--enzyme_inducer', type=float, default=0.0, help="1.0 if taking Carbamazepine/Phenytoin/Rifampin, else 0.0")
    parser.add_argument('--cyp2c9', type=str, default="Unknown", help="CYP2C9 genotype (e.g. *1/*1)")
    parser.add_argument('--vkorc1', type=str, default="Unknown", help="VKORC1 consensus (e.g. A/G)")
    
    args = parser.parse_args()
    
    patient = {
        'Age_Num': args.age,
        'Height (cm)': args.height,
        'Weight (kg)': args.weight,
        'Race_Group': args.race,
        'Amiodarone': args.amiodarone,
        'Enzyme_Inducer': args.enzyme_inducer,
        'CYP2C9': args.cyp2c9,
        'VKORC1': args.vkorc1
    }
    
    print("\n--- Patient Profile ---")
    for k, v in patient.items():
        print(f"{k}: {v}")
        
    try:
        dose = predict_warfarin_dose(patient)
        print(f"\n=> Predicted Therapeutic Dose: {dose:.2f} mg/week")
    except Exception as e:
        print(f"\nError during prediction: {e}")

