library(cansim)
library(dplyr)
library(readr)

lfs <- get_cansim("14-10-0287-01")

# match province names to the CMHC panel
name_map <- c("Newfoundland and Labrador" = "Newfoundland",
              "Quebec" = "Québec")

monthly <- lfs |>
  filter(
    `Labour force characteristics` == "Unemployment rate",
    `Data type` == "Seasonally adjusted",
    Statistics == "Estimate",
    `Age group` == "15 years and over",
    Gender == "Total - Gender",
    GEO != "Canada"
  ) |>
  transmute(
    province = as.character(GEO),
    date = as.Date(Date),
    unemployment_rate = VALUE
  ) |>
  mutate(province = recode(province, !!!name_map))

# monthly to quarterly average
quarterly <- monthly |>
  mutate(
    year = as.integer(format(date, "%Y")),
    qtr  = (as.integer(format(date, "%m")) - 1) %/% 3 + 1,
    date = as.Date(paste0(year, "-", (qtr - 1) * 3 + 1, "-01"))
  ) |>
  group_by(province, year, qtr, date) |>
  summarise(unemployment_rate = mean(unemployment_rate),
            n_months = n(), .groups = "drop") |>
  arrange(province, date)

# checks
cat("Provinces:", n_distinct(quarterly$province), "(expected 10)\n")
cat("Quarters with fewer than 3 months:", sum(quarterly$n_months < 3), "\n")
cat("Missing rates:", sum(is.na(quarterly$unemployment_rate)), "\n")
cat("Date range:", format(min(quarterly$date)), "to",
    format(max(quarterly$date)), "\n")
print(summary(quarterly$unemployment_rate))
print(sort(unique(quarterly$province)))

write_csv(select(quarterly, -n_months),
          file.path("data", "processed", "unemployment_panel.csv"))
message("Script finished")