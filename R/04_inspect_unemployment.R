library(cansim)
library(dplyr)

# Labour Force Survey, monthly, seasonally adjusted, by province
lfs <- get_cansim("14-10-0287-01")

cat("Columns:\n")
print(names(lfs))

cat("\nGeographies:\n")
print(unique(lfs$GEO))

for (col in c("Labour force characteristics", "Data type", "Statistics",
              "Age group", "Gender", "Sex")) {
  if (col %in% names(lfs)) {
    cat("\n", col, ":\n", sep = "")
    print(unique(lfs[[col]]))
  }
}

cat("\nDate range:", as.character(min(lfs$REF_DATE)), "to",
    as.character(max(lfs$REF_DATE)), "\n")
message("Script finished")