# Runs the full pipeline in order. Before running:
# 1. Download the CMHC delinquency Excel file and save it as
#    data/raw/cmhc_delinquency.xlsx (see README).
# 2. Install the packages listed in the README.
# 3. An internet connection is needed (Statistics Canada and Bank of Canada data).

scripts <- c(
  # provincial panel
  "R/03_clean_cmhc.R",
  "R/05_clean_unemployment.R",
  "R/06_clean_policy_rate.R",
  "R/07_build_panel.R",
  "R/08_EDA_plots.R",
  "R/09_EDA.R",
  # fixed-effects models and validation
  "R/10_fixed_effects_models.R",
  "R/11_rate_lag_profile.R",
  "R/12_validation.R",
  "R/13_model_validation_rf.R",
  "R/14_validation_checks.R",
  "R/15_scenarios.R",
  "R/16_validation_figures.R",
  # census metropolitan areas (robustness) and heterogeneity
  "R/18_clean_cma_delinquency.R",
  "R/19_clean_cma_unemployment.R",
  "R/20_panel_CMA.R",
  "R/21_cma_models.R",
  "R/22_heterogeinity.R"
)

stopifnot(file.exists(file.path("data", "raw", "cmhc_delinquency.xlsx")))

for (s in scripts) {
  message("Running ", s)
  source(s)
}
message("Pipeline finished")