library(dplyr)
library(readr)
library(fixest)
library(broom)
library(ggplot2)

prov_panel <- read_csv(file.path("data", "processed", "model_panel.csv"),
                       show_col_types = FALSE) |>
  mutate(covid = as.integer(date >= as.Date("2020-04-01") &
                              date <= as.Date("2021-10-01")))
cma_panel <- read_csv(file.path("data", "processed", "cma_model_panel.csv"),
                      show_col_types = FALSE)

# one unemployment coefficient per province
h_prov <- feols(log_delinquency ~ i(province, unemployment_l1) + covid | province + qtr,
                data = prov_panel, vcov = "hetero")
h_cma  <- feols(log_delinquency ~ i(province, unemployment_l1) + covid | cma + qtr,
                data = cma_panel, cluster = ~cma)

extract <- function(m, level) {
  tidy(m, conf.int = TRUE) |>
    filter(grepl("unemployment_l1", term)) |>
    mutate(province = sub("^province::(.*):unemployment_l1$", "\\1", term),
           level = level)
}
het <- bind_rows(extract(h_prov, "Provincial panel"),
                 extract(h_cma,  "CMA panel")) |>
  mutate(level = factor(level, levels = c("Provincial panel", "CMA panel")))

print(select(het, level, province, estimate, std.error, conf.low, conf.high), n = Inf)
write_csv(het, file.path("outputs", "heterogeneity.csv"))

p <- ggplot(het, aes(estimate, reorder(province, estimate))) +
  geom_vline(xintercept = 0, linetype = "dashed") +
  geom_pointrange(aes(xmin = conf.low, xmax = conf.high)) +
  facet_wrap(~ level, scales = "free_y") +
  scale_x_continuous(breaks = c(0, 0.1, 0.2, 0.3)) +
  labs(title = "Association between unemployment and delinquency, by province",
       subtitle = "Coefficient on log delinquency, 95% interval. Indicative: each estimate uses few observations.",
       x = "Coefficient", y = NULL) +
  theme_minimal()

ggsave(file.path("outputs", "figures", "heterogeneity.png"), p,
       width = 10, height = 5, dpi = 150)
print(p)
message("Script finished")