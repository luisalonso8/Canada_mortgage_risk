library(dplyr)
library(readr)
library(ggplot2)

out <- file.path("outputs", "figures")

labels <- c(
  rf_change     = "Random forest (change)",
  ar_macro_rate = "Persistence + unemployment + policy rate",
  naive         = "Last-quarter benchmark",
  ar_macro      = "Persistence + unemployment",
  ar            = "Persistence only",
  rf_level      = "Random forest (level)",
  macro         = "Economy only"
)

# 1. error by model (the economy-only model is left out: its RMSE is 0.45)
scores <- read_csv(file.path("outputs", "validation_scores_all.csv"),
                   show_col_types = FALSE) |>
  filter(model != "macro") |>
  mutate(label = unname(labels[model]))

p1 <- ggplot(scores, aes(rmse, reorder(label, -rmse))) +
  geom_point(size = 3) +
  labs(title = "Out-of-sample error by model",
       subtitle = "RMSE in log points, 16 test quarters (2022Q1 to 2025Q4)",
       caption = "Economy-only model (RMSE 0.45) not shown.",
       x = "RMSE", y = NULL)
  theme_minimal()

# 2. actual vs predicted, four provinces, three models
errs <- read_csv(file.path("outputs", "validation_errors_all.csv"),
                 show_col_types = FALSE)

show_prov <- c("Ontario", "British Columbia", "Alberta", "New Brunswick")
show_mod  <- c("naive", "ar_macro", "rf_change")

pred_df <- errs |>
  filter(province %in% show_prov, model %in% show_mod) |>
  mutate(predicted = exp(prediction), label = unname(labels[model]))
actual_df <- pred_df |> distinct(province, date, actual) |>
  mutate(actual_rate = exp(actual))

p2 <- ggplot() +
  geom_line(data = actual_df, aes(date, actual_rate), color = "black", linewidth = 0.9) +
  geom_line(data = pred_df, aes(date, predicted, color = label), linewidth = 0.6) +
  facet_wrap(~ province, scales = "free_y") +
  labs(title = "Actual (black) and one-quarter-ahead predictions",
       x = NULL, y = "90+ days past due (%)", color = NULL) +
  theme_minimal() + theme(legend.position = "bottom")

# 3. unemployment coefficient across specifications
stopifnot(file.exists(file.path("outputs", "baseline_models.csv")))
coefs <- read_csv(file.path("outputs", "baseline_models.csv"), show_col_types = FALSE) |>
  filter(grepl("unemployment", term), model != "m6") |>
  mutate(lower = estimate - 1.96 * std.error,
         upper = estimate + 1.96 * std.error,
         spec = paste0(model, ": ", term))

p3 <- ggplot(coefs, aes(estimate, spec)) +
  geom_vline(xintercept = 0, linetype = "dashed") +
  geom_pointrange(aes(xmin = lower, xmax = upper)) +
  labs(title = "Association between unemployment and delinquency, by specification",
       subtitle = "Coefficient on log delinquency, 95% interval. Errors clustered by province (10 clusters): intervals are indicative.",
       x = "Coefficient", y = NULL) +
  theme_minimal()

ggsave(file.path(out, "validation_rmse.png"), p1, width = 8, height = 4, dpi = 150)
ggsave(file.path(out, "validation_actual_vs_predicted.png"), p2, width = 10, height = 6, dpi = 150)
ggsave(file.path(out, "unemployment_coefficients.png"), p3, width = 9, height = 4, dpi = 150)
print(p1); print(p2); print(p3)
message("Script finished")