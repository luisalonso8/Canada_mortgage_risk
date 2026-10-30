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

# ---- assertions: the script stops if any of these fail ----
stopifnot(
  nrow(panel) == 540,
  n_distinct(panel$province) == 10,
  n_distinct(panel$date) == 54,
  !anyDuplicated(panel[c("province", "date")]),
  !anyNA(panel),
  all(panel$delinquency_rate > 0)
)

# spot check against the original CMHC Excel (2012Q3)
expected_2012q3 <- c("Newfoundland" = 0.24, "Prince Edward Island" = 0.57,
                     "Nova Scotia" = 0.53, "New Brunswick" = 0.63,
                     "Québec" = 0.33, "Ontario" = 0.31, "Manitoba" = 0.25,
                     "Saskatchewan" = 0.37, "Alberta" = 0.60)

check <- panel |>
  filter(date == as.Date("2012-07-01"), province %in% names(expected_2012q3))

stopifnot(
  nrow(check) == 9,
  all(abs(check$delinquency_rate - expected_2012q3[check$province]) < 0.005)
)

# lag check: rate_l2 in 2024Q2 must equal the policy rate in 2023Q4
rate_2023q4 <- rate$policy_rate[rate$date == as.Date("2023-10-01")]
rate_l2_2024q2 <- unique(panel$rate_l2[panel$date == as.Date("2024-04-01")])
stopifnot(length(rate_l2_2024q2) == 1,
          abs(rate_l2_2024q2 - rate_2023q4) < 1e-9)

# lag check: Alberta unemployment_l1 in 2015Q2 must equal its 2015Q1 value
ab <- unemp |> filter(province == "Alberta")
stopifnot(abs(
  panel$unemployment_l1[panel$province == "Alberta" & panel$date == as.Date("2015-04-01")] -
    ab$unemployment_rate[ab$date == as.Date("2015-01-01")]
) < 1e-9)

message("All checks passed")

write_csv(panel, file.path("data", "processed", "model_panel.csv"))
message("Script finished")