library(dplyr)
library(readr)
library(fixest)
library(broom)

panel <- read_csv(file.path("data", "processed", "model_panel.csv"),
                  show_col_types = FALSE) |>
  arrange(province, date) |>
  group_by(province) |>
  mutate(unemployment_l2 = lag(unemployment_rate, 2)) |>
  ungroup() |>
  mutate(covid = as.integer(date >= as.Date("2020-04-01") &
                              date <= as.Date("2021-10-01")))

# main specifications (province and quarter-of-year fixed effects)
m1 <- feols(log_delinquency ~ unemployment_rate + rate_l2 + covid | province + qtr,
            data = panel, cluster = ~province)

m2 <- feols(log_delinquency ~ unemployment_rate + unemployment_l1 + rate_l2 + covid |
              province + qtr,
            data = panel, cluster = ~province)

m3 <- feols(log_delinquency ~ unemployment_l1 + rate_l4 + covid | province + qtr,
            data = panel, cluster = ~province)

# robustness: drop the COVID quarters
no_covid <- filter(panel, covid == 0)

m4 <- feols(log_delinquency ~ unemployment_l1 + rate_l4 | province + qtr,
            data = no_covid, cluster = ~province)

m5 <- feols(log_delinquency ~ unemployment_l1 | province + date,
            data = panel, cluster = ~province)

etable(m1, m2, m3, m4, digits = 3)


models <- list(m1 = m1, m2 = m2, m3 = m3, m4 = m4, m5=m5)

tidy_models <- bind_rows(lapply(names(models), function(n) {
  mutate(tidy(models[[n]]), model = n)
}))

print(tidy_models, n = Inf)
write_csv(tidy_models, file.path("outputs", "baseline_models.csv"))
message("Script finished")