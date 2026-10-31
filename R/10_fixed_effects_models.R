library(dplyr)
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

stopifnot(sum(is.na(panel$log_delinq_l1)) == 10)

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

# dynamic specification: persistence + unemployment (same as ar_macro in the validation)
m6 <- feols(log_delinquency ~ log_delinq_l1 + unemployment_l1 + covid | province + qtr,
            data = panel, cluster = ~province)

rho <- coef(m6)[["log_delinq_l1"]]
cat("Persistence coefficient (rho):", round(rho, 3), "\n")
cat("Short-run unemployment effect:", round(coef(m6)[["unemployment_l1"]], 3), "\n")
cat("Long-run unemployment effect:",
    round(coef(m6)[["unemployment_l1"]] / (1 - rho), 3), "\n")

etable(m1, m2, m3, m4, m5, m6, digits = 3)


models <- list(m1 = m1, m2 = m2, m3 = m3, m4 = m4, m5=m5, m6=m6)

tidy_models <- bind_rows(lapply(names(models), function(n) {
  mutate(tidy(models[[n]]), model = n)
}))

print(tidy_models, n = Inf)
write_csv(tidy_models, file.path("outputs", "fixed_effects_models.csv"))
message("Script finished")