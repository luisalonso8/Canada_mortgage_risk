library(dplyr)
library(readr)
library(fixest)
library(broom)

panel <- read_csv(file.path("data", "processed", "cma_model_panel.csv"),
                  show_col_types = FALSE) |>
  arrange(cma, date) |>
  group_by(cma) |>
  mutate(log_delinq_l1 = lag(log_delinquency, 1)) |>
  ungroup()

no_covid <- filter(panel, covid == 0)

# same specifications as the provincial models, now with CMA fixed effects
c1 <- feols(log_delinquency ~ unemployment_l1 + rate_l4 + covid | cma + qtr,
            data = panel, cluster = ~cma)                     # = provincial m3

c2 <- feols(log_delinquency ~ unemployment_l1 + rate_l4 + covid | cma + qtr,
            data = panel, cluster = ~province)                # same, errors by province

c3 <- feols(log_delinquency ~ unemployment_l1 + rate_l4 | cma + qtr,
            data = no_covid, cluster = ~cma)                  # = provincial m4

c4 <- feols(log_delinquency ~ unemployment_l1 | cma + date,
            data = panel, cluster = ~cma)                     # = provincial m5

c5 <- feols(log_delinquency ~ unemployment_l1 | cma + province^date,
            data = panel, cluster = ~cma)                     # within province, same quarter

c6 <- feols(log_delinquency ~ log_delinq_l1 + unemployment_l1 + covid | cma + qtr,
            data = panel, cluster = ~cma)                     # = provincial m6 (persistence)

print(etable(c1, c2, c3, c4, c5, c6, digits = 3))

rho <- coef(c6)[["log_delinq_l1"]]
cat("\nPersistence coefficient (rho):", round(rho, 3), "\n")
cat("Short-run unemployment effect:", round(coef(c6)[["unemployment_l1"]], 3), "\n")
cat("Long-run unemployment effect:",
    round(coef(c6)[["unemployment_l1"]] / (1 - rho), 3), "\n")

models <- list(c1 = c1, c2 = c2, c3 = c3, c4 = c4, c5 = c5, c6 = c6)
tidy_cma <- bind_rows(lapply(names(models), function(n) {
  mutate(tidy(models[[n]]), model = n, n_obs = nobs(models[[n]]))
}))
write_csv(tidy_cma, file.path("outputs", "cma_models.csv"))

# side by side with the provincial estimates of the unemployment coefficient
prov_file <- c(file.path("outputs", "fixed_effects_models.csv"),
               file.path("outputs", "baseline_models.csv"))
prov_file <- prov_file[file.exists(prov_file)][1]
prov <- read_csv(prov_file, show_col_types = FALSE) |>
  filter(term == "unemployment_l1", model %in% c("m3", "m4", "m5", "m6")) |>
  transmute(spec = c(m3 = "main", m4 = "no COVID", m5 = "date FE", m6 = "persistence")[model],
            provincial = round(estimate, 3))
cma_cmp <- tidy_cma |>
  filter(term == "unemployment_l1", model %in% c("c1", "c3", "c4", "c6")) |>
  transmute(spec = c(c1 = "main", c3 = "no COVID", c4 = "date FE", c6 = "persistence")[model],
            cma = round(estimate, 3))
cat("\n=== Unemployment coefficient: provincial vs CMA ===\n")
print(left_join(prov, cma_cmp, by = "spec"))

fit_stats <- bind_rows(lapply(names(models), function(n) {
  tibble(model = n,
         n_obs = nobs(models[[n]]),
         within_r2 = round(r2(models[[n]], "wr2"), 3))
}))
print(fit_stats)
write_csv(fit_stats, file.path("outputs", "cma_fit.csv"))
message("Script finished")