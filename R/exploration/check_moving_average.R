library(dplyr)
library(cansim)

ma <- get_cansim("14-10-0459-01") |>
  filter(GEO == "Ontario",
         `Labour force characteristics` == "Unemployment rate",
         `Data type` == "Seasonally adjusted",
         Statistics == "Estimate") |>
  transmute(month = as.Date(paste0(REF_DATE, "-01")), ma3 = VALUE)

monthly <- get_cansim("14-10-0287-01") |>
  filter(GEO == "Ontario",
         `Labour force characteristics` == "Unemployment rate",
         Gender == "Total - Gender",
         `Age group` == "15 years and over",
         `Data type` == "Seasonally adjusted") |>
  transmute(month = as.Date(paste0(REF_DATE, "-01")), u = VALUE) |>
  arrange(month)

check <- monthly |>
  left_join(ma, by = "month") |>
  mutate(trailing = (u + lag(u, 1) + lag(u, 2)) / 3,
         centered = (lag(u, 1) + u + lead(u, 1)) / 3)

check |>
  filter(month >= as.Date("2023-01-01")) |>
  summarise(diff_trailing = mean(abs(ma3 - trailing), na.rm = TRUE),
            diff_centered = mean(abs(ma3 - centered), na.rm = TRUE))