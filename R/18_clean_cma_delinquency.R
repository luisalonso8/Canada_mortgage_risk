library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(cansim)

# 1. CMHC: read the whole sheet, find the header row (quarters like 2012Q3)
raw <- read_excel(file.path("data", "raw", "cmhc_delinquency.xlsx"),
                  sheet = "Mortgage delinquency rate", col_names = FALSE)

is_quarter <- function(x) grepl("^[0-9]{4} ?Q[1-4]$", as.character(x))
header_row <- which(apply(raw, 1, function(r) sum(is_quarter(r)) > 10))[1]
stopifnot(!is.na(header_row))

quarters  <- as.character(unlist(raw[header_row, ]))
keep_cols <- which(is_quarter(quarters))

body <- raw[(header_row + 1):nrow(raw), c(1, keep_cols)]
names(body) <- c("geography", gsub(" ", "", quarters[keep_cols]))
body <- body |>
  filter(!is.na(geography)) |>
  mutate(across(-geography, ~ suppressWarnings(as.numeric(.)))) |>
  filter(rowSums(!is.na(across(-geography))) > 10)

# 2. name normalization used for matching (drops ", Province", accents, punctuation)
norm <- function(x) {
  x <- sub(",.*$", "", x)
  x <- tolower(iconv(x, to = "ASCII//TRANSLIT"))
  gsub("[^a-z0-9]", "", x)
}

non_cma <- c("canada", "newfoundland", "newfoundlandandlabrador", "princeedwardisland",
             "novascotia", "newbrunswick", "quebec", "ontario", "manitoba",
             "saskatchewan", "alberta", "britishcolumbia", "yukon",
             "northwestterritories", "nunavut")

# 3. Labour Force Survey CMAs (names with a comma; skip the Ottawa-Gatineau parts)
lfs_cma <- get_cansim("14-10-0459-01") |>
  distinct(GEO) |>
  mutate(GEO = as.character(GEO)) |>
  filter(grepl(",", GEO), !grepl("part,", GEO)) |>
  mutate(key = norm(GEO))

cma <- body |>
  mutate(key = norm(geography)) |>
  filter(!key %in% non_cma) |>
  # CMHC says "Québec City", the survey says "Québec"
  mutate(key = if_else(key == "quebeccity", "quebec", key))

cat("\n=== CMHC CMAs found:", nrow(cma), "===\n")
cat("\n=== CMHC CMAs without survey data (dropped) ===\n")
print(cma$geography[!cma$key %in% lfs_cma$key])
cat("\n=== Survey CMAs not in CMHC (not used) ===\n")
print(lfs_cma$GEO[!lfs_cma$key %in% cma$key])

cma <- filter(cma, key %in% lfs_cma$key)
stopifnot(nrow(cma) == 33)

# 4. long panel of CMA delinquency (same units as the provincial panel)
cma_panel <- cma |>
  pivot_longer(-c(geography, key), names_to = "quarter", values_to = "delinquency_rate") |>
  mutate(year = as.integer(substr(quarter, 1, 4)),
         q    = as.integer(substr(quarter, 6, 6)),
         date = as.Date(sprintf("%d-%02d-01", year, 3 * (q - 1) + 1))) |>
  select(cma = geography, key, date, delinquency_rate)

stopifnot(nrow(cma_panel) == 33 * 54, !anyNA(cma_panel$delinquency_rate))
cat("\nCMA panel:", n_distinct(cma_panel$cma), "CMAs,", nrow(cma_panel), "rows\n")
write_csv(cma_panel, file.path("data", "processed", "cma_delinquency_panel.csv"))
message("Script finished")