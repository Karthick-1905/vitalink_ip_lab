import numpy as np
import pandas as pd
import os

def generate_warfarin_data(n=2000, random_seed=12321):
    print(f"Generating realistic warfarin cohort ({n} patients)...")
    np.random.seed(random_seed)
    
    # Demographics
    age = np.clip(np.round(np.random.normal(62, 14, n)), 18, 90)
    height = np.round(np.random.normal(170, 8, n))
    weight = np.clip(np.round(75 + 0.65 * (height - 170) + np.random.normal(0, 10, n)), 40, 150)
    bmi = weight / ((height / 100) ** 2)
    gender = np.random.choice(["Male", "Female"], n, p=[0.55, 0.45])
    
    # Genetic variants
    cyp2c9 = np.random.choice(["*1/*1", "*1/*2", "*1/*3"], n, p=[0.70, 0.20, 0.10])
    vkorc1 = np.random.choice(["GG", "GA", "AA"], n, p=[0.40, 0.40, 0.20])
    cyp4f2 = np.random.choice(["CC", "CT", "TT"], n, p=[0.50, 0.40, 0.10])
    
    # Clinical variables
    amiodarone = np.random.binomial(1, 0.15, n)
    aspirin = np.random.binomial(1, 0.25, n)
    target_inr = np.random.uniform(2.0, 3.5, n)
    renal_function = np.clip(np.round(np.random.normal(85, 25, n)), 15, 120)
    smoker = np.random.binomial(1, 0.25, n)
    
    # Calculate warfarin dose with realistic noise
    base_dose = 0.4 * weight - 0.02 * age + 25
    
    # Genetic effects
    cyp2c9_effect = np.where(cyp2c9 == "*1/*1", 0, np.where(cyp2c9 == "*1/*2", -8, -12))
    vkorc1_effect = np.where(vkorc1 == "GG", 0, np.where(vkorc1 == "GA", -6, -14))
    cyp4f2_effect = np.where(cyp4f2 == "CC", 0, np.where(cyp4f2 == "CT", 2, 4))
    
    # Other effects
    gender_effect = np.where(gender == "Male", 3, -2)
    age_effect = -0.15 * (age - 50)
    bmi_effect = 0.2 * (bmi - 25)
    amiodarone_effect = np.where(amiodarone == 1, -5, 0)
    aspirin_effect = np.where(aspirin == 1, -2, 0)
    inr_effect = 2 * (target_inr - 2.5)
    renal_effect = 0.03 * (renal_function - 85)
    smoker_effect = np.where(smoker == 1, 1.5, 0)
    
    # Interaction terms
    age_bmi_interaction = 0.02 * (age - 50) * (bmi - 25)
    genetic_interaction = 0.1 * cyp2c9_effect * vkorc1_effect
    smoking_genetic_interaction = 0.5 * smoker_effect * (cyp2c9_effect + vkorc1_effect)
    
    # Final dose with realistic noise
    noise = np.random.normal(0, 3.5, n)
    warfarin_dose = (base_dose + cyp2c9_effect + vkorc1_effect + cyp4f2_effect + 
                     gender_effect + age_effect + bmi_effect + amiodarone_effect + 
                     aspirin_effect + inr_effect + renal_effect + smoker_effect + 
                     age_bmi_interaction + genetic_interaction + smoking_genetic_interaction + 
                     noise)
    
    warfarin_dose = np.round(np.clip(warfarin_dose, 5, 70), 1)
    
    # Synthetic "Days to Stable" for the secondary upgrade module
    # Older age, higher negative genetic effects will artificially take longer to find stability
    base_days = 21 # Baseline 3 weeks
    genetic_delay = np.where(vkorc1 != "GG", 7, 0) + np.where(cyp2c9 != "*1/*1", 7, 0)
    age_delay = np.clip((age - 60) * 0.2, 0, None)
    
    days_to_stable = base_days + genetic_delay + age_delay + np.random.normal(0, 5, n)
    days_to_stable = np.round(np.clip(days_to_stable, 7, 120))
    
    df = pd.DataFrame({
        'Age': age,
        'Weight': weight,
        'Height': height,
        'BMI': np.round(bmi, 1),
        'Gender': gender,
        'CYP2C9': cyp2c9,
        'VKORC1': vkorc1,
        'CYP4F2': cyp4f2,
        'Amiodarone': np.where(amiodarone == 1, 'Yes', 'No'),
        'Aspirin': np.where(aspirin == 1, 'Yes', 'No'),
        'Smoker': np.where(smoker == 1, 'Yes', 'No'),
        'Target_INR': np.round(target_inr, 2),
        'Renal_Function': renal_function,
        'WarfarinDose': warfarin_dose,
        'Days_To_Stable': days_to_stable
    })
    
    return df

if __name__ == "__main__":
    df = generate_warfarin_data(2500)
    os.makedirs("data", exist_ok=True)
    out_path = "data/warfarin_cohort.csv"
    df.to_csv(out_path, index=False)
    
    print("-" * 50)
    print("DATA GENERATION SUMMARY")
    print("-" * 50)
    print(f"Total Patients: {len(df)}")
    print(f"Mean Dose: {df['WarfarinDose'].mean():.1f} mg/week (SD: {df['WarfarinDose'].std():.1f})")
    print(f"Range: {df['WarfarinDose'].min()} - {df['WarfarinDose'].max()} mg/week")
    print(f"Mean Days To Stable: {df['Days_To_Stable'].mean():.1f} days")
    print("-" * 50)
    print(f"Saved dataset to {out_path}")
