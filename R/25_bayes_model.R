library(dplyr)
library(readr)
library(brms)

# ---- Data: same provincial panel as v2 ----
panel <- read_csv(file.path("data", "processed", "model_panel.csv"),
                  show_col_types = FALSE) |>
  mutate(covid = as.integer(date >= as.Date("2020-04-01") &
                              date <= as.Date("2021-10-01"))) |>
  tidyr::drop_na(log_delinquency, unemployment_l1, rate_l4, hpi_yoy_l1)

# ---- Within-between (Mundlak) terms ----
# The "within" part keeps the fixed-effects interpretation;
# the province mean absorbs differences between provinces.
panel <- panel |>
  group_by(province) |>
  mutate(unemp_mean   = mean(unemployment_l1),
         unemp_within = unemployment_l1 - unemp_mean,
         hpi_mean     = mean(hpi_yoy_l1),
         hpi_within   = hpi_yoy_l1 - hpi_mean) |>
  ungroup() |>
  mutate(qtr = factor(qtr))

# ---- Model: province random intercept and random unemployment slope ----
formula_bayes <- bf(
  log_delinquency ~ unemp_within + unemp_mean + hpi_within + hpi_mean +
    rate_l4 + covid + qtr + (1 + unemp_within | province)
)

# ---- Weakly informative priors (log delinquency is about -1.2 on average) ----
priors <- c(
  prior(normal(-1.2, 1),  class = Intercept),
  prior(normal(0, 0.3),   class = b),
  prior(exponential(2),   class = sd),
  prior(exponential(2),   class = sigma),
  prior(lkj(2),           class = cor)
)

# ---- 1. Prior predictive check (priors only, no data) ----
fit_prior <- brm(formula_bayes, data = panel, prior = priors,
                 sample_prior = "only", chains = 2, iter = 1000,
                 seed = 123, refresh = 0)
pp_check(fit_prior, ndraws = 100)   # should look broad but not absurd

# ---- 2. Fit the model ----
fit <- brm(formula_bayes, data = panel, prior = priors,
           chains = 4, iter = 2000, warmup = 1000, cores = 4,
           seed = 123, control = list(adapt_delta = 0.95),
           file = file.path("outputs", "bayes_model_a"))

# ---- 3. Convergence and fit checks ----
summary(fit)                 # R-hat near 1, bulk/tail ESS above 400
mcmc_plot(fit, type = "trace")
pp_check(fit, ndraws = 100)  # simulated data should resemble the real data

# ---- 4. Results ----
fixef(fit)                          # compare with the v2 fixed effects model
ranef(fit)$province[, , "unemp_within"]   # province-level unemployment slopes

panel <- panel |> arrange(province, date) |>
  group_by(province) |> mutate(t = row_number()) |> ungroup()

formula_ar <- bf(
  log_delinquency ~ unemp_within + unemp_mean + hpi_within + hpi_mean +
    rate_l4 + covid + qtr + (1 + unemp_within | province) +
    ar(time = t, gr = province, p = 1)
)

fit_ar <- brm(formula_ar, data = panel, prior = priors,
              chains = 4, iter = 2000, warmup = 1000, cores = 4,
              seed = 123, control = list(adapt_delta = 0.95),
              file = file.path("outputs", "bayes_model_a_ar"))
summary(fit_ar)

panel_dyn <- panel |> arrange(province, date) |>
  group_by(province) |>
  mutate(log_delinq_l1 = lag(log_delinquency, 1)) |>
  ungroup() |>
  tidyr::drop_na(log_delinq_l1)

formula_dyn <- bf(
  log_delinquency ~ log_delinq_l1 + unemp_within + unemp_mean + hpi_within +
    hpi_mean + rate_l4 + covid + qtr + (1 + unemp_within | province)
)

priors_dyn <- c(priors,summary(fit_dyn, digits = 4)
hypothesis(fit_dyn, "hpi_within / (1 - log_delinq_l1) = 0")
                prior(normal(1, 0.5), class = b, coef = log_delinq_l1))

fit_dyn <- brm(formula_dyn, data = panel_dyn, prior = priors_dyn,
               chains = 4, iter = 2000, warmup = 1000, cores = 4,
               seed = 123, control = list(adapt_delta = 0.95),
               file = file.path("outputs", "bayes_model_dyn"))
summary(fit_dyn)

hypothesis(fit_dyn, "unemp_within / (1 - log_delinq_l1) = 0")