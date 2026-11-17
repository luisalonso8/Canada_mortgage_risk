# v2: does adding house prices change the v1 results?
# House price growth (New Housing Price Index, year-over-year %) enters lagged,
# so this quarter's delinquency cannot move it. Results are associations.
library(dplyr)
library(tidyr)
library(readr)
library(fixest)
library(broom)

panel <- read_csv(file.path("data", "processed", "model_panel.csv"),
                  show_col_types = FALSE) |>
  mutate(covid = as.integer(date >= as.Date("2020-04-01") &
                              date <= as.Date("2021-10-01"))) |>
  arrange(province, date) |>
  group_by(province) |>
  mutate(log_delinq_l1 = lag(log_delinquency, 1)) |>
  ungroup()

stopifnot(!anyNA(panel$hpi_yoy_l1))

# ---- 1. v1 models with and without house prices ----
# a: static (v1 m3), b: date fixed effects (v1 m5), c: dynamic (v1 m6)
fit <- function(f, data = panel) feols(f, data = data, cluster = ~province)

models <- list(
  a_v1  = fit(log_delinquency ~ unemployment_l1 + rate_l4 + covid | province + qtr),
  a_v2  = fit(log_delinquency ~ unemployment_l1 + rate_l4 + hpi_yoy_l1 + covid |
                province + qtr),
  b_v1  = fit(log_delinquency ~ unemployment_l1 | province + date),
  b_v2  = fit(log_delinquency ~ unemployment_l1 + hpi_yoy_l1 | province + date),
  c_v1  = fit(log_delinquency ~ log_delinq_l1 + unemployment_l1 + covid |
                province + qtr, data = filter(panel, !is.na(log_delinq_l1))),
  c_v2  = fit(log_delinquency ~ log_delinq_l1 + unemployment_l1 + hpi_yoy_l1 + covid |
                province + qtr, data = filter(panel, !is.na(log_delinq_l1)))
)

etable(models, digits = 3)

tidy_models <- bind_rows(lapply(names(models), function(n) {
  mutate(tidy(models[[n]]), model = n)
}))
write_csv(tidy_models, file.path("outputs", "house_price_models.csv"))

# how much the unemployment coefficient moves once house prices are added
shift <- tidy_models |>
  filter(term == "unemployment_l1") |>
  mutate(spec = substr(model, 1, 1), version = substr(model, 3, 4)) |>
  select(spec, version, estimate) |>
  pivot_wider(names_from = version, values_from = estimate) |>
  mutate(change_pct = round(100 * (v2 / v1 - 1), 1))
cat("\nUnemployment coefficient, v1 vs v2:\n")
print(shift)
write_csv(shift, file.path("outputs", "house_price_unemployment_shift.csv"))

# ---- 2. lag profile: which house price lag matters ----
lags <- c("hpi_yoy", "hpi_yoy_l1", "hpi_yoy_l2", "hpi_yoy_l4")
lag_profile <- bind_rows(lapply(lags, function(v) {
  f <- as.formula(paste("log_delinquency ~ unemployment_l1 + rate_l4 +", v,
                        "+ covid | province + qtr"))
  tidy(fit(f)) |> filter(term == v)
}))
cat("\nHouse price lag profile:\n")
print(lag_profile)
write_csv(lag_profile, file.path("outputs", "house_price_lag_profile.csv"))

# ---- 3. out-of-sample: does house price growth improve forecasts? ----
# same expanding window and 16 test quarters as R/12_validation.R
vpanel <- filter(panel, !is.na(log_delinq_l1))
test_dates <- tail(sort(unique(vpanel$date)), 16)

specs <- list(
  ar           = log_delinquency ~ log_delinq_l1 | province + qtr,
  ar_macro     = log_delinquency ~ log_delinq_l1 + unemployment_l1 + covid |
    province + qtr,
  ar_macro_hpi = log_delinquency ~ log_delinq_l1 + unemployment_l1 + hpi_yoy_l1 +
    covid | province + qtr
)

errors <- bind_rows(lapply(test_dates, function(d) {
  train <- filter(vpanel, date < d)
  test  <- filter(vpanel, date == d)
  bind_rows(lapply(names(specs), function(nm) {
    m <- feols(specs[[nm]], data = train)
    tibble(model = nm, province = test$province, date = d,
           error = test$log_delinquency - as.numeric(predict(m, newdata = test)))
  }))
}))
stopifnot(!anyNA(errors$error), nrow(errors) == 16 * 10 * length(specs))

scores <- errors |>
  group_by(model) |>
  summarise(rmse = sqrt(mean(error^2)), mae = mean(abs(error)), .groups = "drop") |>
  mutate(rmse_vs_ar_pct = round(100 * (rmse / rmse[model == "ar"] - 1), 1)) |>
  arrange(rmse)
print(scores)

# Diebold-Mariano with Harvey-Leybourne-Newbold correction (as in R/23)
by_q <- errors |>
  group_by(model, date) |>
  summarise(mse = mean(error^2), .groups = "drop") |>
  pivot_wider(names_from = model, values_from = mse)

dm_test <- function(baseline, challenger) {
  d <- by_q[[baseline]] - by_q[[challenger]]   # positive: challenger is better
  n <- length(d)
  s <- mean(d) / sqrt(var(d) / n) * sqrt((n - 1) / n)
  tibble(baseline = baseline, challenger = challenger,
         quarters_better = sum(d > 0), statistic = round(s, 3),
         p_value = round(2 * pt(-abs(s), df = n - 1), 4))
}
tests <- bind_rows(dm_test("ar", "ar_macro_hpi"),
                   dm_test("ar_macro", "ar_macro_hpi"))
print(tests)

write_csv(scores, file.path("outputs", "house_price_validation_scores.csv"))
write_csv(tests, file.path("outputs", "house_price_validation_tests.csv"))
message("Script finished")
