ssolibrary(readxl)

path <- file.path("data", "raw", "cmhc_delinquency.xlsx")

cat("Sheets:\n")
print(excel_sheets(path))

raw <- read_excel(path, sheet = "Mortgage delinquency rate",
                  col_names = FALSE, .name_repair = "minimal")

cat("\nTitle cells (A1, A2):\n")
print(raw[[1]][1:2])

cat("\nHeader row (row 4), all columns:\n")
print(as.character(unlist(raw[4, ])))

cat("\nFirst column, all rows:\n")
print(raw[[1]])

cat("\nLast 12 rows, first 6 columns (footnotes):\n")
print(tail(raw[, 1:6], 12), width = 200)