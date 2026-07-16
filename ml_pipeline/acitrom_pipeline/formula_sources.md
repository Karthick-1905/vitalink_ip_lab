
## Primary Literature Sources

1. North-Indian acenocoumarol pharmacogenetic model (full coefficient equation):
   - https://pmc.ncbi.nlm.nih.gov/articles/PMC3358293/
2. Spanish acenocoumarol pharmacogenetic model (variables and clinical relevance):
   - https://pmc.ncbi.nlm.nih.gov/articles/PMC3401172/
3. Acenocoumarol AGS (genotype score concept and cutoffs):
   - https://pmc.ncbi.nlm.nih.gov/articles/PMC2887839/

## Formula Provenance Used in Code

### A) Literature-Derived Regression Core

Implemented from the North-Indian model (PMC3358293), where dose is modeled in mg/day with these terms:

- Intercept
- smoking
- sex
- age
- indication term (DVR or AVR)
- height
- weight
- BSA
- VKORC1 genotype indicators
- CYP2C9 genotype indicators
- CYP4F2 genotype indicators
- GGCX genotype indicators

Code location:
- formula implementation: [ml_pipeline/acitrom_pipeline/predict_acitrom_cold_start.py](ml_pipeline/acitrom_pipeline/predict_acitrom_cold_start.py#L42-L100)
- BSA helper (Mosteller): [ml_pipeline/acitrom_pipeline/predict_acitrom_cold_start.py](ml_pipeline/acitrom_pipeline/predict_acitrom_cold_start.py#L18-L22)

### B) AGS-Inspired Dose Tendency

An AGS-like score is computed from available genotype inputs to provide low/intermediate/high dose tendency tags.

Code location:
- AGS-like scoring: [ml_pipeline/acitrom_pipeline/predict_acitrom_cold_start.py](ml_pipeline/acitrom_pipeline/predict_acitrom_cold_start.py#L145-L173)

## Engineering Logic (Not Direct Coefficients From Papers)

These are intentional product safety choices for deployment-time decision support:

1. Blend strategy for cold start:
   - 60% paper-formula estimate + 40% conservative clinical rule estimate.
2. Follow-up INR adjustment mode:
   - proportional adjustment from current INR to target midpoint.
3. Safety cap on each dose-step change:
   - max ±20% change per adjustment.
4. Hard output bounds:
   - constrained minimum/maximum daily recommendations.

Code location:
- clinical rule baseline: [ml_pipeline/acitrom_pipeline/predict_acitrom_cold_start.py](ml_pipeline/acitrom_pipeline/predict_acitrom_cold_start.py#L103-L122)
- INR follow-up and ±20% cap: [ml_pipeline/acitrom_pipeline/predict_acitrom_cold_start.py](ml_pipeline/acitrom_pipeline/predict_acitrom_cold_start.py#L125-L143)
- blending and final strategy selection: [ml_pipeline/acitrom_pipeline/predict_acitrom_cold_start.py](ml_pipeline/acitrom_pipeline/predict_acitrom_cold_start.py#L176-L210)

## Variable Encoding Notes

- Sex is encoded as male indicator in the imported equation logic.
- Indication term supports DVR and AVR as explicit coded categories.
- Genotype strings are normalized before mapping to indicator features.
- If genotype fields are missing, indicator terms default to 0.

## Unit Conventions

- Core equation predicts daily dose (mg/day).
- Final output includes daily and weekly dose.
- Weekly dose = daily dose × 7.

