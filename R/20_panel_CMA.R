library(dplyr)
library(readr)
library(cansim)

norm <- function(x) {
  x <- sub(",.*$", "", x)
  x <- tolower(iconv(x, to = "ASCII//TRANSLIT"))
  gsub("[^a-z0-9]", "", x)
}

delinq <- read_csv(file.path("data", "processed", "cma_delinquency_panel.csv"),
                   show_col_types = FALSE)
unemp  <- read_csv(file.path("data", "processed", "cma_unemployment_quarterly.csv"),
                   show_col_types = FALSE)

# province of each CMA (used to cluster the standard errors)
cma_prov <- get_cansim("14-10-0459-01") |>
  distinct(GEO) |>
  mutate(GEO = as.character(GEO)) |>
  filter(grepl(",", GEO), !grepl("part,", GEO)) |>
  mutate(key = norm(GEO),
         province = trimws(sub("^.*,", "", GEO)),
         province = case_when(province == "Ontario/Quebec" ~ "Ontario",
                              province == "Québec" ~ "Quebec",
                              TRUE ~ province)) |>
  select(key, province)

# policy rate lags, computed on the full quarterly series
rate <- read_csv(file.path("data", "processed", "policy_rate_quarterly.csv"),
                 show_col_types = FALSE) |>
  arrange(date)
for (k in 1:4) rate[[paste0("rate_l", k)]] <- lag(rate$policy_rate, k)
rate <- select(rate, date, policy_rate, starts_with("rate_l"))

# unemployment with its lag (includes 2012Q2, so the first model quarter has a lag)
unemp <- unemp |>
  arrange(key, date) |>
  group_by(key) |>
  mutate(unemployment_l1 = lag(unemployment_rate, 1)) |>
  ungroup()

cma_model_panel <- delinq |>
  inner_join(unemp, by = c("key", "date")) |>
  left_join(cma_prov, by = "key") |>
  left_join(rate, by = "date") |>
  mutate(log_delinquency = log(delinquency_rate),
         qtr = ((as.integer(format(date, "%m")) - 1) %/% 3) + 1,
         covid = as.integer(date >= as.Date("2020-04-01") &
                              date <= as.Date("2021-10-01"))) |>
  arrange(cma, date)

stopifnot(
  nrow(cma_model_panel) == 33 * 54,
  n_distinct(cma_model_panel$cma) == 33,
  n_distinct(cma_model_panel$date) == 54,
  !anyNA(cma_model_panel$province),
  !anyNA(cma_model_panel$unemployment_l1),
  !anyNA(cma_model_panel$rate_l4),
  !anyDuplicated(cma_model_panel[c("cma", "date")]),
  all(cma_model_panel$delinquency_rate > 0)
)

cat("\nCMA model panel:", n_distinct(cma_model_panel$cma), "CMAs,",
    nrow(cma_model_panel), "rows,", n_distinct(cma_model_panel$province), "provinces\n")
print(count(distinct(cma_model_panel, cma, province), province))
print(summary(cma_model_panel$delinquency_rate))

write_csv(cma_model_panel, file.path("data", "processed", "cma_model_panel.csv"))
message("Script finished")