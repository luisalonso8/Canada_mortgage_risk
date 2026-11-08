library(dplyr)
library(readr)
library(fixest)
library(broom)
library(ggplot2)

prov_panel <- read_csv(file.path("data", "processed", "model_panel.csv"),
                       show_col_types = FALSE) |>
  mutate(covid = as.integer(date >= as.Date("2020-04-01") &
                              date <= as.Date("2021-10-01")),
         t = as.integer(factor(date)))
cma_panel <- read_csv(file.path("data", "processed", "cma_model_panel.csv"),
                      show_col_types = FALSE) |>
  mutate(t = as.integer(factor(date)))

# one unemployment coefficient per province, Newey-West errors (serial correlation)
h_prov <- feols(log_delinquency ~ i(province, unemployment_l1) + covid | province + qtr,
                data = prov_panel, panel.id = ~province + t, vcov = "NW")
h_cma  <- feols(log_delinquency ~ i(province, unemployment_l1) + covid | cma + qtr,
                data = cma_panel, panel.id = ~cma + t, vcov = "NW")

extract <- function(m, level) {
  tidy(m, conf.int = TRUE) |>
    filter(grepl("unemployment_l1", term)) |>
    mutate(province = sub("^province::(.*):unemployment_l1$", "\\1", term),
           level = level)
}
het <- bind_rows(extract(h_prov, "Provincial panel"),
                 extract(h_cma,  "CMA panel")) |>
  mutate(level = factor(level, levels = c("Provincial panel", "CMA panel")),
         province = recode(province,
                           "Newfoundland and Labrador" = "Newfoundland",
                           "Quebec" = "Québec"))

# same province order in both panels, sorted by the provincial estimate
prov_order <- het |>
  filter(level == "Provincial panel") |>
  arrange(estimate) |>
  pull(province)
het <- het |>
  mutate(province = factor(province, levels = prov_order))

print(select(het, level, province, estimate, std.error, conf.low, conf.high), n = Inf)
write_csv(het, file.path("outputs", "heterogeneity.csv"))

p <- ggplot(het, aes(estimate, province)) +
  geom_vline(xintercept = 0, linetype = "dashed") +
  geom_pointrange(aes(xmin = conf.low, xmax = conf.high)) +
  facet_wrap(~ level, scales = "free_y") +
  scale_x_continuous(breaks = c(0, 0.1, 0.2, 0.3)) +
  labs(title = "Association between unemployment and delinquency, by province",
       subtitle = "Coefficient on log delinquency, 95% interval (Newey-West). Indicative: each estimate uses about 50 quarters of a highly persistent series.",
       caption = "Prince Edward Island has no metropolitan areas in the CMA panel.",
       x = "Coefficient", y = NULL) +
  theme_minimal()

ggsave(file.path("outputs", "figures", "heterogeneity.png"), p,
       width = 10, height = 5, dpi = 150)
print(p)
message("Script finished")