library(dplyr); library(tidyr); library(readr); library(ggplot2)
library(brms); library(posterior)

# ---- Inputs ----
panel <- read_csv(file.path("data", "processed", "model_panel.csv"),
                  show_col_types = FALSE) |>
  tidyr::drop_na(log_delinquency, unemployment_l1, rate_l4, hpi_yoy_l1) |>
  group_by(province) |>
  mutate(unemp_mean = mean(unemployment_l1),
         hpi_mean   = mean(hpi_yoy_l1)) |>
  ungroup()

fit_dyn <- readRDS(file.path("outputs", "bayes_model_dyn.rds"))

# ---- Starting point: last observed quarter ----
start_date <- max(panel$date)
last <- panel |> filter(date == start_date) |> arrange(province)
stopifnot(nrow(last) == 10)
provs <- last$province
P  <- length(provs)
um <- last$unemp_mean
hm <- last$hpi_mean
hpi_hold  <- last$hpi_yoy   # house price growth held at last observed value
rate_hold <- last$rate_l4   # policy rate lag held at last observed value

# ---- Posterior draws ----
draws <- as_draws_df(fit_dyn)
D <- nrow(draws)
b <- function(nm) draws[[paste0("b_", nm)]]
re <- function(p, term) {
  cand <- paste0("r_province[", c(p, make.names(p)), ",", term, "]")
  nm <- cand[cand %in% names(draws)][1]
  stopifnot(!is.na(nm))
  draws[[nm]]
}
re_int   <- sapply(provs, re, term = "Intercept")      # draws x provinces
re_slope <- sapply(provs, re, term = "unemp_within")
rep_row  <- function(v) matrix(rep(v, each = D), nrow = D)

# ---- Scenarios: same design as v1 ----
horizon      <- 8
future_dates <- seq(start_date, by = "quarter", length.out = horizon + 1)[-1]
qtr_of <- function(d) as.numeric((as.integer(format(d, "%m")) - 1) %/% 3 + 1)
scenarios <- tibble(scenario = c("Baseline", "Moderate stress", "Severe stress"),
                    shock    = c(0, 2, 4))
probs <- c(0.1, 0.5, 0.9)   # 80% interval

set.seed(123)
by_prov <- list(); avg <- list()
for (s in seq_len(nrow(scenarios))) {
  prev <- rep_row(last$log_delinquency)
  start_rate <- exp(last$log_delinquency)
  by_prov[[length(by_prov) + 1]] <- tibble(
    scenario = scenarios$scenario[s], province = provs, date = start_date,
    lower = start_rate, median = start_rate, upper = start_rate)
  avg[[length(avg) + 1]] <- tibble(
    scenario = scenarios$scenario[s], date = start_date,
    lower = mean(start_rate), median = mean(start_rate), upper = mean(start_rate))
  
  for (h in seq_len(horizon)) {
    u_prev <- last$unemployment_rate + scenarios$shock[s] * min(h - 1, 4) / 4
    uw <- u_prev - um
    hw <- hpi_hold - hm
    q  <- qtr_of(future_dates[h])
    qeff <- if (q == 1) 0 else b(paste0("qtr", q))
    
    mu <- b("Intercept") + re_int +
      b("log_delinq_l1") * prev +
      (b("unemp_within") + re_slope) * rep_row(uw) +
      b("unemp_mean") * rep_row(um) +
      b("hpi_within") * rep_row(hw) +
      b("hpi_mean")   * rep_row(hm) +
      b("rate_l4")    * rep_row(rate_hold) +
      qeff                                   # covid = 0 in the future
    new_log <- mu + matrix(rnorm(D * P, 0, rep(draws$sigma, times = P)), nrow = D)
    rate_sim <- exp(new_log)
    
    qs <- apply(rate_sim, 2, quantile, probs = probs)
    by_prov[[length(by_prov) + 1]] <- tibble(
      scenario = scenarios$scenario[s], province = provs, date = future_dates[h],
      lower = qs[1, ], median = qs[2, ], upper = qs[3, ])
    qa <- quantile(rowMeans(rate_sim), probs = probs)
    avg[[length(avg) + 1]] <- tibble(
      scenario = scenarios$scenario[s], date = future_dates[h],
      lower = qa[[1]], median = qa[[2]], upper = qa[[3]])
    prev <- new_log
  }
}
by_prov <- bind_rows(by_prov); avg <- bind_rows(avg)
stopifnot(!anyNA(by_prov$median), !anyNA(avg$median))

write_csv(by_prov, file.path("outputs", "bayes_scenario_bands_by_province.csv"))
write_csv(avg,     file.path("outputs", "bayes_scenario_bands_average.csv"))

# End of horizon: average delinquency with 80% interval
print(avg |> filter(date == max(date)) |> mutate(across(c(lower, median, upper), ~ round(.x, 3))))

# ---- Figure: average across provinces ----
cols <- c("Baseline" = "#4C78A8", "Moderate stress" = "#F58518", "Severe stress" = "#E45756")
history_avg <- panel |> group_by(date) |>
  summarise(delinquency_rate = mean(delinquency_rate), .groups = "drop")

p <- ggplot() +
  geom_line(data = filter(history_avg, date >= as.Date("2018-01-01")),
            aes(date, delinquency_rate), color = "black") +
  geom_ribbon(data = avg, aes(date, ymin = lower, ymax = upper, fill = scenario), alpha = 0.2) +
  geom_line(data = avg, aes(date, median, color = scenario), linewidth = 0.9) +
  scale_color_manual(values = cols) + scale_fill_manual(values = cols) +
  labs(title = "Average delinquency under unemployment scenarios, with uncertainty",
       subtitle = "Median and 80% interval; house price growth and policy rate held at last observed values",
       x = NULL, y = "90+ days past due (%)", color = NULL, fill = NULL) +
  theme_minimal() + theme(legend.position = "bottom")
ggsave(file.path("outputs", "figures", "bayes_scenarios_average.png"), p,
       width = 8, height = 4.5, dpi = 150)
print(p)