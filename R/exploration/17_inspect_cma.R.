library(readxl)
library(dplyr)

raw <- read_excel(file.path("data", "raw", "cmhc_delinquency.xlsx"),
                  sheet = "Mortgage delinquency rate", col_names = FALSE)
geo <- tibble(row = seq_len(nrow(raw)), geography = raw[[1]]) |>
  filter(!is.na(geography))
print(geo, n = Inf)

# 2. Labour Force Survey by CMA: structure and geography names
lfs <- get_cansim("14-10-0459-01")
print(names(lfs))
print(range(lfs$REF_DATE))

lfs |> distinct(GEO) |> print(n = Inf)

lfs |>
  distinct(across(any_of(c("Labour force characteristics", "Data type",
                           "Statistics", "Gender", "Age group")))) |>
  print(n = Inf)