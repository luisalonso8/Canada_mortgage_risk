library(readxl)
library(dplyr)
library(tidyr)
library(readr)

path <- file.path("data", "raw", "cmhc_delinquency.xlsx")

raw <- read_excel(path, sheet = "Mortgage delinquency rate",
                  col_names = FALSE, .name_repair = "minimal")

header <- as.character(unlist(raw[4, ]))

provinces <- c("Newfoundland", "Prince Edward Island", "Nova Scotia",
               "New Brunswick", "Québec", "Ontario", "Manitoba",
               "Saskatchewan", "Alberta", "British Columbia")

# rows 5 to 16 hold Canada and the provinces
panel <- raw[5:16, ] |>
  setNames(header) |>
  rename(province = Geography) |>
  filter(province %in% provinces) |>
  pivot_longer(-province, names_to = "quarter", values_to = "delinquency_rate") |>
  mutate(
    delinquency_rate = as.numeric(delinquency_rate),
    year = as.integer(substr(quarter, 1, 4)),
    qtr  = as.integer(substr(quarter, 6, 6)),
    date = as.Date(paste0(year, "-", (qtr - 1) * 3 + 1, "-01"))
  ) |>
  arrange(province, date)

# checks
cat("Rows:", nrow(panel), "(expected 540)\n")
cat("Provinces:", n_distinct(panel$province), "\n")
cat("Missing rates:", sum(is.na(panel$delinquency_rate)), "\n")
cat("Date range:", format(min(panel$date)), "to", format(max(panel$date)), "\n")
print(summary(panel$delinquency_rate))

write_csv(panel, file.path("data", "processed", "delinquency_panel.csv"))
message("Script finished")source("R/03_clean_cmhc.R")