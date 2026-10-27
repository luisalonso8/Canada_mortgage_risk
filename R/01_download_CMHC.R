library(readxl)

path <- file.path("data", "raw", "cmhc_delinquency.xlsx")

if (!file.exists(path)) {
  stop("File not found: ", path, "\nWorking directory: ", getwd())
}

sheets <- excel_sheets(path)
print(sheets)

for (s in sheets) {
  cat("\n=== Sheet:", s, "===\n")
  print(read_excel(path, sheet = s, col_names = FALSE, n_max = 15))
}

message("Script finished")

sheets <- excel_sheets(path)
print(sheets)

# First rows of each sheet, without assuming headers
for (s in sheets) {
  cat("\n=== Sheet:", s, "===\n")
  print(read_excel(path, sheet = s, col_names = FALSE, n_max = 15))
}