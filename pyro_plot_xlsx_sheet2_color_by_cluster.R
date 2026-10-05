#!/usr/bin/env Rscript

# Run from the directory containing the workbook, or supply its path:
#   Rscript pyro_plot_xlsx_sheet2_color_by_cluster.R --xlsx workbook.xlsx --sheet Sheet2
# Use --help for all options. Relative input paths resolve from the cwd.
# PDF and PNG outputs use the same path and basename as the HTML output.
# Install dependencies once if needed:
# install.packages(c("optparse", "readxl", "ggplot2", "plotly", "htmlwidgets"))

if (!requireNamespace("optparse", quietly = TRUE)) {
  stop("Install required package: optparse", call. = FALSE)
}
parser <- optparse::OptionParser(
  description = "Plot workbook data with interactive selection downloads.",
  option_list = list(
    optparse::make_option(c("-x", "--xlsx"), dest = "input_file",
                          default = "data/export_v02_2ab_popgen1.mapv2.batch_corrected_norm.logit.curatedv1.xlsx",
                          metavar = "FILE",
                          help = "Input workbook [default: %default]"),
    optparse::make_option(c("-i", "--in"), dest = "input_file",
                          metavar = "FILE", help = "Input workbook (alias)"),
    optparse::make_option(c("-s", "--sheet"), dest = "sheet_name",
                          default = "Sheet2", metavar = "NAME",
                          help = "Worksheet name [default: %default]"),
    optparse::make_option(c("-w", "--worksheet"), dest = "sheet_name",
                          metavar = "NAME", help = "Worksheet name (alias)"),
    optparse::make_option(c("-o", "--outdir"), dest = "outdir",
                          default = "./figures/", metavar = "DIR",
                          help = "Output directory [default: %default]")
  ),
  epilogue = paste(
    "Relative paths resolve from the current working directory.",
    "Reads columns A:R, with headers in row 2.",
    "Saves Plotly HTML, PDF, and PNG files in the output directory."
  )
)
options <- optparse::parse_args(parser)
input_file <- options$input_file
sheet_name <- options$sheet_name
outdir <- options$outdir

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

# A:R includes the required columns and the 3A and 3B hover columns.
# Row 2 contains headers, and row 3 starts the observations.
data <- readxl::read_excel(
  input_file,
  sheet = sheet_name,
  range = readxl::cell_limits(c(2, 1), c(NA, 18)),
  col_names = TRUE
)
required_columns <- c("sampleID", "ave_per_2a", "ave_per_2b", "ave_per_3a", "GENERICID", "CNR", "PacBio", "CNRgrid", "3A", "3B")
missing_columns <- setdiff(required_columns, names(data))
if (length(missing_columns)) {
  stop("Missing required columns: ", paste(missing_columns, collapse = ", "))
}
if (!is.numeric(data$ave_per_2a) || !is.numeric(data$ave_per_2b)) {
  stop("ave_per_2a and ave_per_2b must contain numeric values.")
}

# Treat CNR as a categorical grouping, including when encoded as numbers.
data$CNR <- factor(data$CNR)
# Edit these named colors to change the color of any CNR value. Also support
# the earlier "cendtroid" spelling if it appears in a workbook.
cnr_colors <- c(
  "0" = "#808080",            # medium gray
  "centroid" = "#123B7A",     # dark blue
  "cendtroid" = "#123B7A",    # earlier spelling
  "cnr1_3xdup" = "#0072B2",
  "comphet-25-40" = "#E69F00",
  "phi" = "#009E73",
  "cnr2_homodup" = "#D55E00",
  "comphet40-25" = "#CC79A7",
  "comphet50-33" = "#7F3C8D",
  "comhet-75-50" = "#11A579",
  "comphet33-50" = "#3969AC",
  "cnr2_hetdel" = "#F2B701",
  "cnr1_homodel" = "#E73F74",
  "protective" = "#80BA5A",
  "cnr2_hetdup" = "#E68310",
  "cnr1_hetdup" = "#008695",
  "cnr1_hetdel" = "#CF1C90"
)
cnr_levels <- levels(data$CNR)
plot_colors <- stats::setNames(
  grDevices::hcl.colors(length(cnr_levels), palette = "Dark 3"), cnr_levels
)
named_levels <- intersect(cnr_levels, names(cnr_colors))
plot_colors[named_levels] <- cnr_colors[named_levels]
valid <- is.finite(data$ave_per_2a) & is.finite(data$ave_per_2b)
if (any(!valid)) {
  warning("Omitting ", sum(!valid), " rows with missing/non-finite coordinates.")
}
data <- data[valid, ]
if (!nrow(data)) stop("No rows with finite x and y coordinates to plot.")

p <- ggplot2::ggplot(
  data, ggplot2::aes(x = ave_per_2a, y = ave_per_2b, color = CNR,
                     key = sampleID, shape = PacBio)
) +
  ggplot2::geom_point(size = 2, alpha = 0.75) +
  ggplot2::scale_color_manual(values = plot_colors) +
  ggplot2::labs(
    title = paste0(basename(input_file), "\nSheet: ", sheet_name),
    x = "ave_per_2a", y = "ave_per_2b", color = "CNR"
  ) +
  ggplot2::theme_minimal(base_size = 12)

# Carry numeric 3A averages separately from the displayed 3A copy-number column.
hover_plot <- p + ggplot2::aes(customdata = ave_per_3a, text = paste0(
  "sampleID: ", sampleID,
  "<br>GENERICID: ", GENERICID,
  "<br>PacBio: ", PacBio,
  "<br>ave_per_2a: ", ave_per_2a,
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
