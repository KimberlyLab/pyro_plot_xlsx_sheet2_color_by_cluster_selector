#!/usr/bin/env Rscript

# Run from the directory containing the workbook, or supply its path:
#   Rscript pyro_plot_xlsx_sheet2_color_by_cluster.R --xlsx workbook.xlsx --sheet Sheet2
# Use --help for all options. Relative input paths resolve from the cwd.
# PDF and PNG outputs use the same path and basename as the HTML output.
# All outputs go to --outdir (default: ./figures/).
# Install dependencies once if needed:
# install.packages(c("readxl", "ggplot2", "plotly", "htmlwidgets"))

args <- commandArgs(trailingOnly = TRUE)
if (any(args %in% c("-h", "--help"))) {
  cat(paste0(
    "Usage: Rscript pyro_plot_xlsx_sheet2_color_by_cluster.R [options]\n\n",
    "  --in, --xlsx, -x, -i FILE     Input workbook\n",
    "    Default: export_v02_2ab_popgen1.mapv2.batch_corrected_norm.logit.xlsx\n",
    "  -s, --sheet, --worksheet, -w NAME\n",
    "                              Worksheet name (default: Sheet2)\n",
    "  -o, --outdir DIR            Output directory (default: ./figures/)\n",
    "  -h, --help                  Show this help and exit\n\n",
    "Relative input paths resolve from the current working directory.\n",
    "Reads columns A:P, with headers in row 2 and data starting in row 3.\n",
    "Outputs in DIR: {input_basename}-{sheet}.plotly.html, .plotly.pdf, .plotly.png\n",
    "The output directory is created if it does not exist.\n",
    "Without Pandoc, HTML assets are saved in an adjacent _files directory.\n",
    "The HTML includes selection downloads of sample IDs.\n"
  ))
  quit(status = 0)
}
input_file <- "export_v02_2ab_popgen1.mapv2.batch_corrected_norm.logit.xlsx"
sheet_name <- "Sheet2"
outdir <- "./figures/"
input_flags <- c("--in", "--xlsx", "-x", "-i")
sheet_flags <- c("-s", "--sheet", "--worksheet", "-w")
outdir_flags <- c("-o", "--outdir")
i <- 1L
while (i <= length(args)) {
  flag <- args[i]
  if (!flag %in% c(input_flags, sheet_flags, outdir_flags)) {
    stop("Unknown argument: ", flag, ". Use --help for usage.", call. = FALSE)
  }
  if (i == length(args) || !nzchar(args[i + 1L]) ||
      startsWith(args[i + 1L], "-")) {
    stop("Missing value for ", flag, ". Use --help for usage.", call. = FALSE)
  }
  if (flag %in% input_flags) input_file <- args[i + 1L]
  if (flag %in% sheet_flags) sheet_name <- args[i + 1L]
  if (flag %in% outdir_flags) outdir <- args[i + 1L]
  i <- i + 2L
}

packages <- c("readxl", "ggplot2", "plotly", "htmlwidgets")
missing_packages <- packages[!vapply(packages, requireNamespace,
                                     logical(1), quietly = TRUE)]
if (length(missing_packages)) {
  stop("Install required packages: ", paste(missing_packages, collapse = ", "))
}

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_dir <- if (length(script_arg)) {
  dirname(normalizePath(sub("^--file=", "", script_arg[1])))
} else {
  getwd()
}
# Keep all outputs in outdir, retaining the input workbook's extension.
output_file <- file.path(outdir, paste0(basename(input_file), "-", sheet_name,
                                      ".plotly.html"))

if (!file.exists(input_file)) stop("Workbook not found: ", input_file)

sheets <- readxl::excel_sheets(input_file)
if (!sheet_name %in% sheets) {
  stop("Workbook has no sheet named '", sheet_name, "'. Available sheets: ",
       paste(sheets, collapse = ", "))
}

# A:P includes the 3A and 3B hover columns in O:P.
# Row 2 contains headers, and row 3 starts the observations.
data <- readxl::read_excel(
  input_file,
  sheet = sheet_name,
  range = readxl::cell_limits(c(2, 1), c(NA, 16)),
  col_names = TRUE
)
required_columns <- c("sampleID", "ave_per_2a", "ave_per_2b", "ave_per_3a", "CNR", "3A", "3B")
missing_columns <- setdiff(required_columns, names(data))
if (length(missing_columns)) {
  stop("Missing required columns: ", paste(missing_columns, collapse = ", "))
}
if (!is.numeric(data$ave_per_2a) || !is.numeric(data$ave_per_2b)) {
  stop("ave_per_2a and ave_per_2b must contain numeric values.")
}

# Treat CNR as a categorical grouping, including when encoded as numbers.
data$CNR <- factor(data$CNR)
valid <- is.finite(data$ave_per_2a) & is.finite(data$ave_per_2b)
if (any(!valid)) {
  warning("Omitting ", sum(!valid), " rows with missing/non-finite coordinates.")
}
data <- data[valid, ]
if (!nrow(data)) stop("No rows with finite x and y coordinates to plot.")

p <- ggplot2::ggplot(
  data, ggplot2::aes(x = ave_per_2a, y = ave_per_2b, color = CNR,
                     key = sampleID)
) +
  ggplot2::geom_point(size = 2, alpha = 0.75) +
  ggplot2::labs(
    title = paste0(basename(input_file), "\nSheet: ", sheet_name),
    x = "ave_per_2a", y = "ave_per_2b", color = "CNR"
  ) +
  ggplot2::theme_minimal(base_size = 12)

# Carry numeric 3A averages separately from the displayed 3A copy-number column.
hover_plot <- p + ggplot2::aes(customdata = ave_per_3a, text = paste0(
  "ave_per_2a: ", ave_per_2a,
  "<br>ave_per_2b: ", ave_per_2b,
  "<br>CNR: ", CNR,
  "<br>3A: ", `3A`,
  "<br>3B: ", `3B`
))
interactive_plot <- plotly::ggplotly(hover_plot, tooltip = "text")
# Embed selection downloads in the HTML; no DevTools setup is needed.
selection_js <- paste(readLines(file.path(script_dir, "plotly_save_select_ids.js"),
                               warn = FALSE), collapse = "\n")
interactive_plot <- htmlwidgets::onRender(
  interactive_plot, paste0("function(el, x) {\n", selection_js, "\n}")
)
# Prefer a single portable HTML file; otherwise keep assets beside it.
if (!dir.exists(outdir)) {
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(outdir)) stop("Could not create output directory: ", outdir)
}
selfcontained <- requireNamespace("rmarkdown", quietly = TRUE) &&
  rmarkdown::pandoc_available()
if (!selfcontained) {
  message("Pandoc unavailable: saving HTML with a companion _files directory. ",
          "Keep that directory with the HTML when moving or sharing it.")
}
htmlwidgets::saveWidget(interactive_plot, output_file,
                        selfcontained = selfcontained)
output_stem <- tools::file_path_sans_ext(output_file)
ggplot2::ggsave(paste0(output_stem, ".pdf"), plot = p,
                width = 12, height = 8, units = "in", bg = "white")
ggplot2::ggsave(paste0(output_stem, ".png"), plot = p,
                width = 12, height = 8, units = "in", dpi = 300, bg = "white")
if (interactive()) print(p)
message("Saved interactive plot: ", normalizePath(output_file))
message("Saved PDF: ", normalizePath(paste0(output_stem, ".pdf")))
message("Saved PNG: ", normalizePath(paste0(output_stem, ".png")))
