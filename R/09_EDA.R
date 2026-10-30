library(dplyr)
library(readr)

panel <- read_csv(file.path("data", "processed", "model_panel.csv"),
                  show_col_types = FALSE)

by_province <- panel |>
  group_by(province) |>
  summarise(
    delinq_mean = mean(delinquency_rate),
    delinq_min  = min(delinquency_rate),
    delinq_max  = max(delinquency_rate),
    unemp_mean  = mean(unemployment_rate),
    unemp_min   = min(unemployment_rate),
    unemp_max   = max(unemployment_rate),
    .groups = "drop"
  ) |>
  arrange(desc(delinq_mean)) |>
  mutate(across(where(is.numeric), ~ round(., 2)))

print(by_province, width = Inf)

# average delinquency by quarter of the year (seasonality check)
by_quarter <- panel |>
  group_by(qtr) |>
  summarise(delinq_mean = round(mean(delinquency_rate), 3), .groups = "drop")
print(by_quarter)

write_csv(by_province, file.path("outputs", "descriptive_by_province.csv"))
message("Script finished")