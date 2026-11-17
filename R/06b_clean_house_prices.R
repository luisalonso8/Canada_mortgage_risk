library(cansim)
library(dplyr)
library(readr)

# Statistics Canada, New Housing Price Index (table 18-10-0205-01), monthly,
# December 2016 = 100. It measures prices of new homes from builders, not
# resale prices, so it is a proxy for local house price conditions.
nhpi <- get_cansim("18-10-0205-01")

provinces <- c("Newfoundland and Labrador", "Prince Edward Island",
               "Nova Scotia", "New Brunswick", "Quebec", "Ontario",
               "Manitoba", "Saskatchewan", "Alberta", "British Columbia")

# match province names to the CMHC panel
name_map <- c("Newfoundland and Labrador" = "Newfoundland",
              "Quebec" = "Québec")

monthly <- nhpi |>
  filter(`New housing price indexes` == "Total (house and land)",
         GEO %in% provinces,
         # the index has gaps before 1995; the panel starts in 2012
         as.Date(Date) >= as.Date("2005-01-01")) |>
  transmute(province = recode(as.character(GEO), !!!name_map),
            date = as.Date(Date),
            hpi = VALUE)

# monthly to quarterly average
quarterly <- monthly |>
  mutate(
    year = as.integer(format(date, "%Y")),
    qtr  = (as.integer(format(date, "%m")) - 1) %/% 3 + 1,
    date = as.Date(paste0(year, "-", (qtr - 1) * 3 + 1, "-01"))
  ) |>
  group_by(province, year, qtr, date) |>
  summarise(hpi = mean(hpi), n_months = n(), .groups = "drop") |>
  arrange(province, date) |>
  # year-over-year growth in percent: removes the seasonal pattern and the
  # common upward trend of the index level
  group_by(province) |>
  mutate(hpi_yoy = 100 * (hpi / lag(hpi, 4) - 1)) |>
  ungroup()

# checks
cat("Provinces:", n_distinct(quarterly$province), "(expected 10)\n")
cat("Quarters with fewer than 3 months:", sum(quarterly$n_months < 3), "\n")
cat("Date range:", format(min(quarterly$date)), "to",
    format(max(quarterly$date)), "\n")
print(summary(quarterly$hpi_yoy))

stopifnot(n_distinct(quarterly$province) == 10,
          !anyNA(quarterly$hpi))

write_csv(select(quarterly, -n_months),
          file.path("data", "processed", "house_price_panel.csv"))
message("Script finished")
