library(dplyr)
library(readr)
library(fixest)
library(ggplot2)

panel <- read_csv(file.path("data", "processed", "model_panel.csv"),
                  show_col_types = FALSE) |>
  mutate(covid = as.integer(date >= as.Date("2020-04-01") &
                              date <= as.Date("2021-10-01")))

rate <- read_csv(file.path("data", "processed", "policy_rate_quarterly.csv"),
                 show_col_types = FALSE) |>
  arrange(date)

# policy rate lags 0 to 10 quarters, computed on the full series
for (k in 0:10) rate[[paste0("r_l", k)]] <- lag(rate$policy_rate, k)

panel <- left_join(panel, select(rate, date, starts_with("r_l")), by = "date")
stopifnot(!anyNA(select(panel, starts_with("r_l"))))

# one model per lag, same controls and same sample for every lag
fit_lag <- function(k) {
  f <- as.formula(paste0("log_delinquency ~ unemployment_l1 + covid + r_l", k,
                         " | province + qtr"))
  m <- feols(f, data = panel, cluster = ~province)
  ct <- coeftable(m)[paste0("r_l", k), ]
  tibble(lag = k, estimate = ct[["Estimate"]], se = ct[["Std. Error"]])
}

profile <- bind_rows(lapply(0:10, fit_lag)) |>
  mutate(lower = estimate - 1.96 * se, upper = estimate + 1.96 * se)

print(profile, n = Inf)

p <- ggplot(profile, aes(lag, estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_pointrange(aes(ymin = lower, ymax = upper)) +
  scale_x_continuous(breaks = 0:10) +
  labs(title = "Association between the policy rate and delinquency, by lag",
       subtitle = "Coefficient on the policy rate (log delinquency), 95% interval, clustered by province",
       x = "Lag (quarters)", y = "Coefficient") +
  theme_minimal()

ggsave(file.path("outputs", "figures", "rate_lag_profile.png"), p,
       width = 10, height = 4.5, dpi = 150)
print(p)
message("Script finished")