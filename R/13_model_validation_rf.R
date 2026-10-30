library(dplyr)
library(tidyr)
library(readr)
library(ranger)

# errors saved by regression models and naive benchmark
errors_old <- read_csv(file.path("outputs", "validation_errors.csv"),
                       show_col_types = FALSE) |>
  filter(!grepl("^rf_", model))

panel <- read_csv(file.path("data", "processed", "model_panel.csv"),
                  show_col_types = FALSE) |>
  arrange(province, date) |>
  group_by(province) |>
  mutate(log_delinq_l1 = lag(log_delinquency, 1)) |>
  ungroup() |>
  mutate(covid = as.integer(date >= as.Date("2020-04-01") &
                              date <= as.Date("2021-10-01"))) |>
  filter(!is.na(log_delinq_l1))

# same test quarters as the regression validation
test_dates <- tail(sort(unique(panel$date)), 16)
prov_levels <- sort(unique(panel$province))

prep_rf <- function(df) {
  df |>
    mutate(province = factor(province, levels = prov_levels),
           qtr = factor(qtr, levels = 1:4),
           delta = log_delinquency - log_delinq_l1)
}
f_level  <- log_delinquency ~ log_delinq_l1 + unemployment_l1 + rate_l4 + covid + province + qtr
f_change <- delta ~ log_delinq_l1 + unemployment_l1 + rate_l4 + covid + province + qtr

results <- list()
for (i in seq_along(test_dates)) {
  d <- test_dates[i]
  tr <- prep_rf(filter(panel, date < d))
  te <- prep_rf(filter(panel, date == d))
  
  rf_level  <- ranger(f_level,  data = tr, num.trees = 500, seed = 123)
  rf_change <- ranger(f_change, data = tr, num.trees = 500, seed = 123)
  
  results[[i]] <- tibble(
    province = as.character(te$province), date = te$date,
    actual = te$log_delinquency,
    rf_level  = predict(rf_level,  data = te)$predictions,
    rf_change = te$log_delinq_l1 + predict(rf_change, data = te)$predictions
  )
}

errors_rf <- bind_rows(results) |>
  pivot_longer(c(rf_level, rf_change), names_to = "model", values_to = "prediction") |>
  mutate(error = actual - prediction)

errors_all <- bind_rows(errors_old, errors_rf)
stopifnot(!anyNA(errors_all$prediction),
          nrow(errors_rf) == 16 * 10 * 2)

scores <- errors_all |>
  group_by(model) |>
  summarise(mse = mean(error^2), rmse = sqrt(mse), mae = mean(abs(error)),
            .groups = "drop") |>
  arrange(rmse) |>
  mutate(across(c(mse, rmse, mae), ~ round(., 4)))

print(scores)
write_csv(errors_all, file.path("outputs", "validation_errors_all.csv"))
write_csv(scores, file.path("outputs", "validation_scores_all.csv"))
message("Script finished")