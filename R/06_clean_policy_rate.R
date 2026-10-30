library(jsonlite)
library(dplyr)
library(tidyr)
library(readr)

url <- "https://www.bankofcanada.ca/valet/observations/V39079/json?start_date=2005-01-01"
obs <- fromJSON(url)$observations

daily <- tibble(
  date = as.Date(obs$d),
  policy_rate = as.numeric(obs$V39079$v)
)

# fill every calendar day with the last known rate
all_days <- tibble(date = seq(min(daily$date), max(daily$date), by = "day")) |>
  left_join(daily, by = "date") |>
  fill(policy_rate, .direction = "down")

quarterly <- all_days |>
  mutate(
    year = as.integer(format(date, "%Y")),
    qtr  = (as.integer(format(date, "%m")) - 1) %/% 3 + 1,
    date = as.Date(paste0(year, "-", (qtr - 1) * 3 + 1, "-01"))
  ) |>
  group_by(year, qtr, date) |>
  summarise(policy_rate = mean(policy_rate), .groups = "drop") |>
  arrange(date)

# checks
cat("Missing rates:", sum(is.na(quarterly$policy_rate)), "\n")
cat("Date range:", format(min(quarterly$date)), "to", format(max(quarterly$date)), "\n")
cat("\nSanity checks (average policy rate per quarter):\n")
print(quarterly |> filter(date %in% as.Date(c("2012-01-01", "2021-01-01",
                                              "2023-10-01", "2025-10-01"))))

write_csv(quarterly, file.path("data", "processed", "policy_rate_quarterly.csv"))
message("Script finished")