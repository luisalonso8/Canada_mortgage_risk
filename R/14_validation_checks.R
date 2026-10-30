library(dplyr)
library(readr)
library(tidyr)

errs <- read_csv(file.path("outputs", "validation_errors_all.csv"),
                 show_col_types = FALSE)

# rmse by test quarter for the three best models
by_quarter <- errs |>
  filter(model %in% c("rf_change", "ar_macro", "naive")) |>
  group_by(date, model) |>
  summarise(rmse = sqrt(mean(error^2)), .groups = "drop") |>
  pivot_wider(names_from = model, values_from = rmse)
print(by_quarter)

# share of the 80 province-quarters where rf_change is closer to the truth than ar_macro
wide <- errs |>
  filter(model %in% c("rf_change", "ar_macro")) |>
  select(province, date, model, error) |>
  pivot_wider(names_from = model, values_from = error)
cat("rf_change beats ar_macro in",
    round(100 * mean(abs(wide$rf_change) < abs(wide$ar_macro))), "% of cases\n")
message("Script finished")