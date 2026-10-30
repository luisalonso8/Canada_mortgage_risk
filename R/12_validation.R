library(dplyr)
library(tidyr)
library(readr)
library(fixest)

panel <- read_csv(file.path("data", "processed", "model_panel.csv"),
                  show_col_types = FALSE) |>
  arrange(province, date) |>
  group_by(province) |>
  mutate(log_delinq_l1 = lag(log_delinquency, 1)) |>
  ungroup() |>
  mutate(covid = as.integer(date >= as.Date("2020-04-01") &
                              date <= as.Date("2021-10-01"))) |>
  filter(!is.na(log_delinq_l1))

test_dates <- tail(sort(unique(panel$date)), 8)

specs <- list(
  ar            = log_delinquency ~ log_delinq_l1 | province + qtr,
  macro         = log_delinquency ~ unemployment_l1 + covid | province + qtr,
  ar_macro      = log_delinquency ~ log_delinq_l1 + unemployment_l1 + covid | province + qtr,
  ar_macro_rate = log_delinquency ~ log_delinq_l1 + unemployment_l1 + rate_l4 + covid |
    province + qtr
)

# expanding window: for each test quarter, fit on all earlier quarters
results <- list()
for (i in seq_along(test_dates)) {
  d <- test_dates[i]
  train <- filter(panel, date < d)
  test  <- filter(panel, date == d)
  
  out <- tibble(province = test$province, date = test$date,
                actual = test$log_delinquency, naive = test$log_delinq_l1)
  
  for (nm in names(specs)) {
    m <- feols(specs[[nm]], data = train)
    out[[nm]] <- as.numeric(predict(m, newdata = test))
  }
  results[[i]] <- out
}

errors <- bind_rows(results) |>
  pivot_longer(c(naive, ar, macro, ar_macro, ar_macro_rate),
               names_to = "model", values_to = "prediction") |>
  mutate(error = actual - prediction)

stopifnot(!anyNA(errors$prediction), nrow(errors) == 8 * 10 * 5)

scores <- errors |>
  group_by(model) |>
  summarise(rmse = sqrt(mean(error^2)), mae = mean(abs(error)), .groups = "drop") |>
  arrange(rmse) |>
  mutate(across(c(rmse, mae), ~ round(., 4)))

print(scores)
write_csv(scores, file.path("outputs", "validation_scores.csv"))
write_csv(errors, file.path("outputs", "validation_errors.csv"))
message("Script finished")