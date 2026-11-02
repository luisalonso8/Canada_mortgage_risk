library(dplyr)
library(readr)
library(cansim)

norm <- function(x) {
  x <- sub(",.*$", "", x)
  x <- tolower(iconv(x, to = "ASCII//TRANSLIT"))
  gsub("[^a-z0-9]", "", x)
}

# 1. unemployment rate (seasonally adjusted, 3-month moving average), monthly
lfs <- get_cansim("14-10-0459-01") |>
  filter(`Labour force characteristics` == "Unemployment rate",
         `Data type` == "Seasonally adjusted",
         Statistics == "Estimate") |>
  mutate(GEO = as.character(GEO),
         month = as.Date(paste0(REF_DATE, "-01"))) |>
  select(GEO, month, unemployment_rate = VALUE)

# 2. one value per quarter: the quarter-end month (Mar, Jun, Sep, Dec)
quarterly <- lfs |>
  filter(as.integer(format(month, "%m")) %in% c(3, 6, 9, 12)) |>
  mutate(date = as.Date(cut(month, "quarter"))) |>
  filter(date >= as.Date("2012-04-01"), date <= as.Date("2025-10-01"))

# 3. check against the provincial panel (quarterly average of monthly data)
panel <- read_csv(file.path("data", "processed", "model_panel.csv"),
                  show_col_types = FALSE) |>
  select(province, date, unemployment_rate)

prov_check <- quarterly |>
  filter(GEO %in% c("Ontario", "Alberta", "British Columbia")) |>
  inner_join(panel, by = c("GEO" = "province", "date"),
             suffix = c("_ma3", "_panel"))
stopifnot(nrow(prov_check) > 0)
cat("\n=== Check vs provincial panel (mean absolute difference, points) ===\n")
print(prov_check |>
        group_by(GEO) |>
        summarise(mean_abs_diff = round(mean(abs(unemployment_rate_ma3 - unemployment_rate_panel)), 3),
                  max_abs_diff  = round(max(abs(unemployment_rate_ma3 - unemployment_rate_panel)), 3)))

# 4. CMAs that are in the delinquency panel
cma_delinq <- read_csv(file.path("data", "processed", "cma_delinquency_panel.csv"),
                       show_col_types = FALSE)
cma_keys <- unique(cma_delinq$key)

cma_unemp <- quarterly |>
  filter(grepl(",", GEO), !grepl("part,", GEO)) |>
  mutate(key = norm(GEO)) |>
  filter(key %in% cma_keys) |>
  select(key, date, unemployment_rate)

stopifnot(n_distinct(cma_unemp$key) == 33,
          nrow(cma_unemp) == 33 * 55,
          !anyNA(cma_unemp$unemployment_rate))

cat("\nCMA unemployment:", n_distinct(cma_unemp$key), "CMAs,", nrow(cma_unemp), "rows\n")
write_csv(cma_unemp, file.path("data", "processed", "cma_unemployment_quarterly.csv"))
message("Script finished")