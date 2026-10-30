library(dplyr)
library(readr)

delinq <- read_csv(file.path("data", "processed", "delinquency_panel.csv"))
unemp  <- read_csv(file.path("data", "processed", "unemployment_panel.csv"))
rate   <- read_csv(file.path("data", "processed", "policy_rate_quarterly.csv"))

# lags are computed on the full series, before trimming to the delinquency period
rate <- rate |>
  arrange(date) |>
  mutate(rate_l1 = lag(policy_rate, 1),
         rate_l2 = lag(policy_rate, 2),
         rate_l3 = lag(policy_rate, 3),
         rate_l4 = lag(policy_rate, 4))

unemp <- unemp |>
  arrange(province, date) |>
  group_by(province) |>
  mutate(unemployment_l1 = lag(unemployment_rate, 1)) |>
  ungroup()

panel <- delinq |>
  select(province, date, year, qtr, delinquency_rate) |>
  left_join(select(unemp, province, date, unemployment_rate, unemployment_l1),
            by = c("province", "date")) |>
  left_join(select(rate, date, policy_rate, starts_with("rate_l")),
            by = "date") |>
  mutate(log_delinquency = log(delinquency_rate))

# checks
cat("Rows:", nrow(panel), "(expected 540)\n")
cat("Missing values per column:\n")
print(colSums(is.na(panel)))

vars <- c("log_delinquency", "unemployment_rate", "policy_rate", "rate_l2")

cat("\nPooled correlations:\n")
print(round(cor(panel[vars]), 2))

cat("\nWithin-province correlations (demeaned by province):\n")
within <- panel |>
  group_by(province) |>
  mutate(across(all_of(vars), ~ . - mean(.))) |>
  ungroup()
print(round(cor(within[vars]), 2))

write_csv(panel, file.path("data", "processed", "model_panel.csv"))
message("Script finished")