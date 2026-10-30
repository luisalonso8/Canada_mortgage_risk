library(dplyr)
library(readr)
library(ggplot2)

panel <- read_csv(file.path("data", "processed", "model_panel.csv"),
                  show_col_types = FALSE)

p1 <- ggplot(panel, aes(date, delinquency_rate)) +
  geom_line() +
  facet_wrap(~ province, ncol = 5) +
  labs(title = "Mortgage delinquency rate by province",
       x = NULL, y = "90+ days past due (%)") +
  theme_minimal()

p2 <- ggplot(panel, aes(date, unemployment_rate)) +
  geom_line() +
  facet_wrap(~ province, ncol = 5) +
  labs(title = "Unemployment rate by province (seasonally adjusted)",
       x = NULL, y = "Unemployment rate (%)") +
  theme_minimal()

p3 <- panel |>
  distinct(date, policy_rate) |>
  ggplot(aes(date, policy_rate)) +
  geom_line() +
  labs(title = "Bank of Canada policy interest rate (quarterly average)",
       x = NULL, y = "Policy rate (%)") +
  theme_minimal()

out <- file.path("outputs", "figures")
ggsave(file.path(out, "delinquency_by_province.png"), p1, width = 11, height = 5, dpi = 150)
ggsave(file.path(out, "unemployment_by_province.png"), p2, width = 11, height = 5, dpi = 150)
ggsave(file.path(out, "policy_rate.png"), p3, width = 7, height = 4, dpi = 150)

print(p1); print(p2); print(p3)
message("Script finished")