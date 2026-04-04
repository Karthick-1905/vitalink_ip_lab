import numpy as np
import pandas as pd
import os

DATASET_URL = "https://raw.githubusercontent.com/ankmathur96/warfarin-bandits/master/data/warfarin.csv"


def _parse_age_band(value):
    if pd.isna(value):
        return np.nan
    text = str(value).strip()
    if "-" in text:
        parts = text.split("-")
        try:
            return (float(parts[0].strip()) + float(parts[1].strip())) / 2.0
        except (ValueError, TypeError):
            return np.nan
    if text.endswith("+"):
        try:
            return float(text.replace("+", ""))
        except (ValueError, TypeError):
            return np.nan
    try:
        return float(text)
    except (ValueError, TypeError):
        return np.nan


def _parse_inr(value):
    if pd.isna(value):
        return np.nan
    text = str(value).strip()
    if "-" in text:
        parts = text.split("-")
        try:
            return (float(parts[0].strip()) + float(parts[1].strip())) / 2.0
        except (ValueError, TypeError):
            return np.nan
    try:
        return float(text)
    except (ValueError, TypeError):
        return np.nan


def _to_yes_no(series):
    def mapper(value):
        if pd.isna(value):
            return np.nan
        if isinstance(value, (int, float, np.integer, np.floating)):
            return "Yes" if float(value) >= 1 else "No"
        text = str(value).strip().lower()
        if text in {"1", "yes", "y", "true"}:
            return "Yes"
        if text in {"0", "no", "n", "false"}:
            return "No"
        return np.nan

    return series.map(mapper)


def _normalize_vkorc1(series):
    def mapper(value):
        if pd.isna(value):
            return np.nan
        text = str(value).strip().upper().replace(" ", "")
        text = text.replace("/", "")
        if text in {"AA", "AG", "GA", "GG"}:
            return "GA" if text == "AG" else text
        return np.nan

    return series.map(mapper)


def _normalize_cyp4f2(series):
    def mapper(value):
        if pd.isna(value):
            return np.nan
        text = str(value).strip().upper().replace(" ", "")
        text = text.replace("/", "")
        if text in {"CC", "CT", "TC", "TT"}:
            return "CT" if text == "TC" else text
        return np.nan

    return series.map(mapper)


def _normalize_cyp2c9(series):
    def mapper(value):
        if pd.isna(value):
            return np.nan
        text = str(value).strip().upper().replace(" ", "")
        if text in {"NA", ""}:
            return np.nan
        return text

    return series.map(mapper)


def _find_column(columns, candidates):
    lowered = {c.lower(): c for c in columns}
    for candidate in candidates:
        if candidate.lower() in lowered:
            return lowered[candidate.lower()]
    return None


def _generate_rule_based_data(n=2000, random_seed=12321):
    np.random.seed(random_seed)

    age = np.clip(np.round(np.random.normal(62, 14, n)), 18, 90)
    height = np.round(np.random.normal(170, 8, n))
    weight = np.clip(np.round(75 + 0.65 * (height - 170) + np.random.normal(0, 10, n)), 40, 150)
    bmi = weight / ((height / 100) ** 2)
    gender = np.random.choice(["Male", "Female"], n, p=[0.55, 0.45])

    cyp2c9 = np.random.choice(["*1/*1", "*1/*2", "*1/*3"], n, p=[0.70, 0.20, 0.10])
    vkorc1 = np.random.choice(["GG", "GA", "AA"], n, p=[0.40, 0.40, 0.20])
    cyp4f2 = np.random.choice(["CC", "CT", "TT"], n, p=[0.50, 0.40, 0.10])

    amiodarone = np.random.binomial(1, 0.15, n)
    aspirin = np.random.binomial(1, 0.25, n)
    target_inr = np.random.uniform(2.0, 3.5, n)
    renal_function = np.clip(np.round(np.random.normal(85, 25, n)), 15, 120)
    smoker = np.random.binomial(1, 0.25, n)

    base_dose = 0.4 * weight - 0.02 * age + 25

    cyp2c9_effect = np.where(cyp2c9 == "*1/*1", 0, np.where(cyp2c9 == "*1/*2", -8, -12))
    vkorc1_effect = np.where(vkorc1 == "GG", 0, np.where(vkorc1 == "GA", -6, -14))
    cyp4f2_effect = np.where(cyp4f2 == "CC", 0, np.where(cyp4f2 == "CT", 2, 4))

    gender_effect = np.where(gender == "Male", 3, -2)
    age_effect = -0.15 * (age - 50)
    bmi_effect = 0.2 * (bmi - 25)
    amiodarone_effect = np.where(amiodarone == 1, -5, 0)
    aspirin_effect = np.where(aspirin == 1, -2, 0)
    inr_effect = 2 * (target_inr - 2.5)
    renal_effect = 0.03 * (renal_function - 85)
    smoker_effect = np.where(smoker == 1, 1.5, 0)

    age_bmi_interaction = 0.02 * (age - 50) * (bmi - 25)
    genetic_interaction = 0.1 * cyp2c9_effect * vkorc1_effect
    smoking_genetic_interaction = 0.5 * smoker_effect * (cyp2c9_effect + vkorc1_effect)

    noise = np.random.normal(0, 3.5, n)
    warfarin_dose = (
        base_dose + cyp2c9_effect + vkorc1_effect + cyp4f2_effect + gender_effect + age_effect +
        bmi_effect + amiodarone_effect + aspirin_effect + inr_effect + renal_effect + smoker_effect +
        age_bmi_interaction + genetic_interaction + smoking_genetic_interaction + noise
    )
    warfarin_dose = np.round(np.clip(warfarin_dose, 5, 70), 1)

    base_days = 21
    genetic_delay = np.where(vkorc1 != "GG", 7, 0) + np.where(cyp2c9 != "*1/*1", 7, 0)
    age_delay = np.clip((age - 60) * 0.2, 0, None)
    days_to_stable = base_days + genetic_delay + age_delay + np.random.normal(0, 5, n)
    days_to_stable = np.round(np.clip(days_to_stable, 7, 120))

    return pd.DataFrame({
        "Age": age,
        "Weight": weight,
        "Height": height,
        "BMI": np.round(bmi, 1),
        "Gender": gender,
        "CYP2C9": cyp2c9,
        "VKORC1": vkorc1,
        "CYP4F2": cyp4f2,
        "Amiodarone": np.where(amiodarone == 1, "Yes", "No"),
        "Aspirin": np.where(aspirin == 1, "Yes", "No"),
        "Smoker": np.where(smoker == 1, "Yes", "No"),
        "Target_INR": np.round(target_inr, 2),
        "Renal_Function": renal_function,
        "WarfarinDose": warfarin_dose,
        "Days_To_Stable": days_to_stable,
    })


def _build_gan_training_frame(source_df, random_seed):
    amiodarone_col = _find_column(source_df.columns, ["Amiodarone (Cordarone)", "Amiodarone"])
    smoker_col = _find_column(source_df.columns, ["Current Smoker", "Smoker"])
    cyp4f2_col = _find_column(source_df.columns, ["CYP4F2 consensus", "CYP4F2"])

    mapped = pd.DataFrame({
        "Age": source_df["Age"].map(_parse_age_band),
        "Weight": pd.to_numeric(source_df["Weight (kg)"], errors="coerce"),
        "Height": pd.to_numeric(source_df["Height (cm)"], errors="coerce"),
        "Gender": source_df["Gender"].astype(str).str.title(),
        "CYP2C9": _normalize_cyp2c9(source_df["Cyp2C9 genotypes"]),
        "VKORC1": _normalize_vkorc1(source_df["VKORC1 -1639 consensus"]),
        "CYP4F2": _normalize_cyp4f2(source_df[cyp4f2_col]) if cyp4f2_col else np.nan,
        "Amiodarone": _to_yes_no(source_df[amiodarone_col]) if amiodarone_col else "No",
        "Aspirin": _to_yes_no(source_df["Aspirin"]),
        "Smoker": _to_yes_no(source_df[smoker_col]) if smoker_col else "No",
        "Target_INR": source_df["Target INR"].map(_parse_inr),
        "WarfarinDose": pd.to_numeric(source_df["Therapeutic Dose of Warfarin"], errors="coerce"),
    })

    mapped["Age"] = mapped["Age"].clip(18, 95)
    mapped["Height"] = mapped["Height"].clip(130, 220)
    mapped["Weight"] = mapped["Weight"].clip(30, 220)
    mapped["Target_INR"] = mapped["Target_INR"].clip(1.5, 4.5)
    mapped["WarfarinDose"] = mapped["WarfarinDose"].clip(3, 90)

    mapped = mapped.dropna(subset=["WarfarinDose"])

    for col in ["Age", "Weight", "Height", "Target_INR"]:
        mapped[col] = mapped[col].fillna(mapped[col].median())

    for col in ["Gender", "CYP2C9", "VKORC1", "CYP4F2", "Amiodarone", "Aspirin", "Smoker"]:
        mode_value = mapped[col].mode(dropna=True)
        mapped[col] = mapped[col].fillna(mode_value.iloc[0] if not mode_value.empty else "Unknown")

    age_centered = mapped["Age"] - 45
    renal = 110 - (0.75 * age_centered) + np.random.default_rng(random_seed).normal(0, 10, len(mapped))
    mapped["Renal_Function"] = np.clip(np.round(renal), 15, 130)

    genotype_delay = np.where(mapped["VKORC1"].isin(["GA", "AA"]), 5, 0) + np.where(mapped["CYP2C9"] != "*1/*1", 6, 0)
    base_days = 18 + 0.12 * (mapped["Age"] - 50)
    mapped["Days_To_Stable"] = np.round(np.clip(base_days + genotype_delay + np.random.default_rng(random_seed + 1).normal(0, 4, len(mapped)), 7, 120))

    mapped["BMI"] = np.round(mapped["Weight"] / ((mapped["Height"] / 100) ** 2), 1)
    mapped["BMI"] = mapped["BMI"].clip(14, 60)

    return mapped

def generate_warfarin_data(n=2000, random_seed=12321):
    print(f"Generating realistic warfarin cohort ({n} patients)...")
    np.random.seed(random_seed)

    source_url = os.getenv("WARFARIN_SOURCE_URL", DATASET_URL)
    try:
        from sdv.metadata import SingleTableMetadata
        from sdv.single_table import CTGANSynthesizer

        source_df = pd.read_csv(source_url)
        gan_train_df = _build_gan_training_frame(source_df, random_seed=random_seed)

        metadata = SingleTableMetadata()
        metadata.detect_from_dataframe(gan_train_df)

        synthesizer = CTGANSynthesizer(
            metadata=metadata,
            enforce_rounding=True,
            epochs=300,
            verbose=False,
        )
        synthesizer.fit(gan_train_df)
        sampled = synthesizer.sample(num_rows=n)

        sampled["Age"] = sampled["Age"].clip(18, 95).round()
        sampled["Height"] = sampled["Height"].clip(130, 220).round(1)
        sampled["Weight"] = sampled["Weight"].clip(30, 220).round(1)
        sampled["Target_INR"] = sampled["Target_INR"].clip(1.5, 4.5).round(2)
        sampled["WarfarinDose"] = sampled["WarfarinDose"].clip(3, 90).round(1)
        sampled["Renal_Function"] = sampled["Renal_Function"].clip(15, 130).round(1)

        sampled["Gender"] = sampled["Gender"].astype(str).str.title().where(
            sampled["Gender"].astype(str).str.title().isin(["Male", "Female"]), "Male"
        )
        sampled["VKORC1"] = _normalize_vkorc1(sampled["VKORC1"]).fillna("GG")
        sampled["CYP4F2"] = _normalize_cyp4f2(sampled["CYP4F2"]).fillna("CC")
        sampled["CYP2C9"] = _normalize_cyp2c9(sampled["CYP2C9"]).fillna("*1/*1")
        sampled["Amiodarone"] = _to_yes_no(sampled["Amiodarone"]).fillna("No")
        sampled["Aspirin"] = _to_yes_no(sampled["Aspirin"]).fillna("No")
        sampled["Smoker"] = _to_yes_no(sampled["Smoker"]).fillna("No")
        sampled["BMI"] = np.round(sampled["Weight"] / ((sampled["Height"] / 100) ** 2), 1).clip(14, 60)

        if "Days_To_Stable" not in sampled.columns:
            genotype_delay = np.where(sampled["VKORC1"].isin(["GA", "AA"]), 5, 0) + np.where(sampled["CYP2C9"] != "*1/*1", 6, 0)
            base_days = 18 + 0.12 * (sampled["Age"] - 50)
            sampled["Days_To_Stable"] = np.round(np.clip(base_days + genotype_delay + np.random.normal(0, 4, len(sampled)), 7, 120))
        else:
            sampled["Days_To_Stable"] = sampled["Days_To_Stable"].clip(7, 120).round()

        print(f"Using CTGAN with source data: {source_url}")
        return sampled[
            [
                "Age", "Weight", "Height", "BMI", "Gender", "CYP2C9", "VKORC1", "CYP4F2",
                "Amiodarone", "Aspirin", "Smoker", "Target_INR", "Renal_Function",
                "WarfarinDose", "Days_To_Stable"
            ]
        ]
    except Exception as error:
        print(f"CTGAN generation unavailable ({error}). Falling back to rule-based generator.")
        return _generate_rule_based_data(n=n, random_seed=random_seed)

if __name__ == "__main__":
    df = generate_warfarin_data(2500)
    os.makedirs("warfarin_pipeline/data", exist_ok=True)
    out_path = "warfarin_pipeline/data/warfarin_cohort.csv"
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
