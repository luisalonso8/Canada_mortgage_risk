library(dplyr); library(readr); library(tidyr); library(brms)

# ---- Data: provincial panel with lagged delinquency ----
panel_all <- read_csv(file.path("data", "processed", "model_panel.csv"),
                      show_col_types = FALSE) |>
  arrange(province, date) |>
  group_by(province) |>
  mutate(log_delinq_l1 = lag(log_delinquency, 1)) |>
  ungroup() |>
  mutate(covid = as.integer(date >= as.Date("2020-04-01") &
                              date <= as.Date("2021-10-01")),
         qtr = factor(qtr)) |>
  tidyr::drop_na(log_delinq_l1, unemployment_l1, rate_l4, hpi_yoy_l1)

# ---- Train/test split; province means from the training data only ----
split_date <- as.Date("2022-01-01")
train_raw  <- panel_all |> filter(date <  split_date)
means <- train_raw |> group_by(province) |>
  summarise(unemp_mean = mean(unemployment_l1),
            hpi_mean   = mean(hpi_yoy_l1), .groups = "drop")
add_within <- function(d) {
  d |> left_join(means, by = "province") |>
    mutate(unemp_within = unemployment_l1 - unemp_mean,
           hpi_within   = hpi_yoy_l1 - hpi_mean)
}
train <- add_within(train_raw)
test  <- add_within(panel_all |> filter(date >= split_date))
stopifnot(nrow(test) == 160)

# ---- Two models: with and without house prices ----
f_hpi <- bf(log_delinquency ~ log_delinq_l1 + unemp_within + unemp_mean +
              hpi_within + hpi_mean + rate_l4 + covid + qtr +
              (1 + unemp_within | province))
f_nohpi <- bf(log_delinquency ~ log_delinq_l1 + unemp_within + unemp_mean +
                rate_l4 + covid + qtr + (1 + unemp_within | province))

priors_dyn <- c(
  prior(normal(-1.2, 1),  class = Intercept),
  prior(normal(0, 0.3),   class = b),
  prior(normal(1, 0.5),   class = b, coef = log_delinq_l1),
  prior(exponential(2),   class = sd),
  prior(exponential(2),   class = sigma),
  prior(lkj(2),           class = cor)
)

fit_hpi <- brm(f_hpi, data = train, prior = priors_dyn,
               chains = 4, iter = 2000, warmup = 1000, cores = 4, seed = 123,
               control = list(adapt_delta = 0.95),
               file = file.path("outputs", "bayes_train_hpi"))
fit_nohpi <- brm(f_nohpi, data = train, prior = priors_dyn,
                 chains = 4, iter = 2000, warmup = 1000, cores = 4, seed = 123,
                 control = list(adapt_delta = 0.95),
                 file = file.path("outputs", "bayes_train_nohpi"))

# ---- One-step-ahead predictions on the test window ----
err <- function(fit) test$log_delinquency - colMeans(posterior_epred(fit, newdata = test))
e_hpi <- err(fit_hpi); e_nohpi <- err(fit_nohpi)

metrics <- tibble(
  model = c("With house prices", "Without house prices"),
  rmse  = c(sqrt(mean(e_hpi^2)), sqrt(mean(e_nohpi^2))),
  mae   = c(mean(abs(e_hpi)),    mean(abs(e_nohpi)))
)
print(metrics)

# Quarters in which the house price model has the lower squared error
by_q <- tibble(date = test$date, d = e_nohpi^2 - e_hpi^2) |>
  group_by(date) |> summarise(better = mean(d) > 0, .groups = "drop")
cat("Quarters better with house prices:", sum(by_q$better), "of", nrow(by_q), "\n")

# ---- Expected log predictive density on the test window ----
logmeanexp <- function(x) { m <- max(x); m + log(mean(exp(x - m))) }
elpd_pt <- function(fit) apply(log_lik(fit, newdata = test), 2, logmeanexp)
d_pt <- elpd_pt(fit_hpi) - elpd_pt(fit_nohpi)
cat(sprintf("ELPD difference (with minus without): %.2f, standard error %.2f\n",
            sum(d_pt), sqrt(length(d_pt)) * sd(d_pt)))

write_csv(metrics, file.path("outputs", "bayes_validation_metrics.csv"))