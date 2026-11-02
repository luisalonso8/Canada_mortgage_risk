library(dplyr)
library(readr)
library(tidyr)

errors <- read_csv(file.path("outputs", "validation_errors_all.csv"),
                   show_col_types = FALSE)

# average loss per model and test quarter (16 quarters)
by_q <- errors |>
  group_by(model, date) |>
  summarise(mse = mean(error^2), mae = mean(abs(error)), .groups = "drop")

# Diebold-Mariano test against the baseline, one-quarter-ahead forecasts,
# with the Harvey-Leybourne-Newbold small-sample correction
compare <- function(model_name, baseline = "ar", loss = "mse") {
  wide <- by_q |>
    select(model, date, value = all_of(loss)) |>
    filter(model %in% c(model_name, baseline)) |>
    pivot_wider(names_from = model, values_from = value)
  d <- wide[[baseline]] - wide[[model_name]]     # positive: model beats baseline
  n <- length(d)
  dm <- mean(d) / sqrt(var(d) / n) * sqrt((n - 1) / n)
  tibble(model = model_name, loss = loss, n_quarters = n,
         quarters_better = sum(d > 0),
         mean_difference = mean(d),
         statistic = dm,
         p_value = 2 * pt(-abs(dm), df = n - 1))
}

models <- setdiff(unique(errors$model), "ar")
tests <- bind_rows(lapply(models, compare, loss = "mse"),
                   lapply(models, compare, loss = "mae")) |>
  arrange(loss, p_value) |>
  mutate(across(c(mean_difference, statistic, p_value), ~ round(., 4)))

print(tests, n = Inf)
write_csv(tests, file.path("outputs", "validation_tests.csv"))
message("Script finished")