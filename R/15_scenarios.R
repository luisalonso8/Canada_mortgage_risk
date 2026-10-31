library(dplyr)
library(readr)
library(fixest)
library(ggplot2)

panel <- read_csv(file.path("data", "processed", "model_panel.csv"),
                  show_col_types = FALSE) |>
  arrange(province, date) |>
  group_by(province) |>
  mutate(log_delinq_l1 = lag(log_delinquency, 1)) |>
  ungroup() |>
  mutate(covid = as.integer(date >= as.Date("2020-04-01") &
                              date <= as.Date("2021-10-01"))) |>
  filter(!is.na(log_delinq_l1))

# persistence + unemployment model (ar_macro), fit on all available data
m <- feols(log_delinquency ~ log_delinq_l1 + unemployment_l1 + covid | province + qtr,
           data = panel)

# starting point: last observed quarter
start_date <- max(panel$date)
last <- panel |>
  filter(date == start_date) |>
  select(province, log_delinquency, unemployment_rate)
stopifnot(nrow(last) == 10)

horizon <- 8
future_dates <- seq(start_date, by = "quarter", length.out = horizon + 1)[-1]
qtr_of <- function(d) as.numeric((as.integer(format(d, "%m")) - 1) %/% 3 + 1)

# unemployment rises by `shock` points over 4 quarters, then stays there
scenarios <- tibble(
  scenario = c("Baseline", "Moderate stress", "Severe stress"),
  shock    = c(0, 2, 4)
)

paths <- list()
for (s in seq_len(nrow(scenarios))) {
  prev_log <- setNames(last$log_delinquency, last$province)
  
  # starting point of each line = last observed value
  paths[[length(paths) + 1]] <- tibble(
    scenario = scenarios$scenario[s], province = last$province,
    date = start_date, delinquency_rate = exp(last$log_delinquency)
  )
  
  for (h in seq_len(horizon)) {
    u_prev <- last$unemployment_rate + scenarios$shock[s] * min(h - 1, 4) / 4
    newdata <- tibble(
      province = last$province,
      qtr = qtr_of(future_dates[h]),
      log_delinq_l1 = unname(prev_log[last$province]),
      unemployment_l1 = u_prev,
      covid = 0L
    )
    pred <- as.numeric(predict(m, newdata = newdata))
    prev_log <- setNames(pred, last$province)
    
    paths[[length(paths) + 1]] <- tibble(
      scenario = scenarios$scenario[s], province = last$province,
      date = future_dates[h], delinquency_rate = exp(pred)
    )
  }
}
paths <- bind_rows(paths)
stopifnot(!anyNA(paths$delinquency_rate))

# summary: average delinquency at the end of the horizon, by scenario
end_summary <- paths |>
  filter(date == max(date)) |>
  group_by(scenario) |>
  summarise(mean_rate = round(mean(delinquency_rate), 3), .groups = "drop")
print(end_summary)

write_csv(paths, file.path("outputs", "scenario_paths.csv"))

# figures
history <- panel |> select(province, date, delinquency_rate)
cols <- c("Baseline" = "#4C78A8", "Moderate stress" = "#F58518", "Severe stress" = "#E45756")

p1 <- ggplot() +
  geom_line(data = filter(history, date >= as.Date("2018-01-01")),
            aes(date, delinquency_rate), color = "black") +
  geom_line(data = paths, aes(date, delinquency_rate, color = scenario), linewidth = 0.8) +
  facet_wrap(~ province, ncol = 5) +
  scale_x_date(breaks = as.Date(c("2018-01-01", "2022-01-01", "2026-01-01")),
               date_labels = "%Y") +
  labs(title = "Delinquency under unemployment scenarios, by province",
       subtitle = "Conditional projections from the persistence + unemployment model, not forecasts",
       x = NULL, y = "90+ days past due (%)", color = NULL) +
  theme_minimal() + theme(legend.position = "bottom")

avg_hist  <- history |> group_by(date) |>
  summarise(delinquency_rate = mean(delinquency_rate), .groups = "drop")
avg_paths <- paths |> group_by(scenario, date) |>
  summarise(delinquency_rate = mean(delinquency_rate), .groups = "drop")

p2 <- ggplot() +
  geom_line(data = filter(avg_hist, date >= as.Date("2018-01-01")),
            aes(date, delinquency_rate), color = "black") +
  geom_line(data = avg_paths, aes(date, delinquency_rate, color = scenario), linewidth = 0.9) +
  scale_color_manual(values = cols) +
  labs(title = "Average delinquency across the ten provinces under unemployment scenarios",
       subtitle = "Simple average, not weighted by number of mortgages",
       x = NULL, y = "90+ days past due (%)", color = NULL) +
  theme_minimal() + theme(legend.position = "bottom")

out <- file.path("outputs", "figures")
ggsave(file.path(out, "scenarios_by_province.png"), p1, width = 11, height = 5, dpi = 150)
ggsave(file.path(out, "scenarios_average.png"), p2, width = 8, height = 4.5, dpi = 150)
print(p1); print(p2)
message("Script finished")