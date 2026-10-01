# Pyro cluster plots

Create a scatter plot from an Excel worksheet with `ave_per_2a` on the x-axis, `ave_per_2b` on the y-axis, and categorical colors from `CNR`. Each run saves an interactive Plotly HTML file, a PDF, and a PNG. The plot title identifies the source workbook and worksheet.

The interactive plot supports box and lasso selections that download the selected sample IDs, with summary statistics in the download filename.

## Setup

Install R and make `Rscript` available on your command-line path. Pandoc is optional: when available to R, it produces a single self-contained HTML file. Otherwise, the script saves HTML with a companion asset directory and continues to generate the PDF and PNG.

Install the R packages once:

```r
install.packages(c("readxl", "ggplot2", "plotly", "htmlwidgets"))
```

Keep these two source files together:

| File | Purpose |
| --- | --- |
| `pyro_plot_xlsx_sheet2_color_by_cluster.R` | Read the workbook, construct the plots, and save outputs. |
| `plotly_save_select_ids.js` | Handle selections and download sample IDs; embedded automatically by the R script. |

Supply your own workbook using a local path. The scripts do not depend on the parent directory or any particular GitHub repository name. An absolute symlink to a workbook on another machine will need to be replaced with a usable local path.

## Usage

From the repository directory:

```sh
Rscript pyro_plot_xlsx_sheet2_color_by_cluster.R \
  --xlsx "data/my_workbook.xlsx" \
  --sheet "Sheet2"
```

Show help:

```sh
Rscript pyro_plot_xlsx_sheet2_color_by_cluster.R --help
```

| Option aliases | Default |
| --- | --- |
| `--in`, `--xlsx`, `-x`, `-i` | `export_v02_2ab_popgen1.mapv2.batch_corrected_norm.logit.xlsx` |
| `-s`, `--sheet`, `--worksheet`, `-w` | `Sheet2` |
| `-o`, `--outdir` | `./figures/` |
| `-h`, `--help` | Print usage and exit. |

Pass option values as separate arguments, and quote paths or worksheet names containing spaces. Relative workbook and output directory paths are resolved from the current working directory. The JavaScript file is located beside the R script, so the script can also be invoked from another directory.

Choose a different output directory with `-o` or `--outdir`:

```sh
Rscript pyro_plot_xlsx_sheet2_color_by_cluster.R \
  --xlsx "data/my_workbook.xlsx" \
  --sheet "Sheet2" \
  --outdir "results/plots"
```

With no arguments, the script reads the default workbook from the current directory, uses `Sheet2`, and saves plots in `./figures/`:

```sh
Rscript pyro_plot_xlsx_sheet2_color_by_cluster.R
```

## Workbook layout

The selected worksheet must have headers in **row 2** and observations starting in **row 3**. Row 1 is ignored. Only columns **A:P** are read; columns are identified by their exact, case-sensitive headers within that range.

| Required header | Use |
| --- | --- |
| `sampleID` | Plotly point key and downloaded sample identifier. |
| `ave_per_2a` | Numeric x-coordinate and selection mean. |
| `ave_per_2b` | Numeric y-coordinate and selection mean. |
| `ave_per_3a` | Numeric selection mean used in download filenames. |
| `CNR` | Categorical point color and most common selected cluster. |
| `3A` | Additional hover value. |
| `3B` | Additional hover value. |

`3A` and `ave_per_3a` are separate columns with different uses. Other columns within A:P are allowed. Rows with missing or non-finite x/y coordinates are omitted with a warning. Missing required headers, nonnumeric x/y columns, or no usable coordinates stop the run.

## Outputs

All plot outputs are saved in `--outdir` (default: `./figures/`). The directory and any missing parent directories are created automatically. The input basename, including `.xlsx`, and the selected worksheet name form the output prefix:

```text
{outdir}/{input_basename}-{sheet}.plotly.html
{outdir}/{input_basename}-{sheet}.plotly.pdf
{outdir}/{input_basename}-{sheet}.plotly.png
```

For `--xlsx data/my_workbook.xlsx --sheet Sheet2`, the HTML is `./figures/my_workbook.xlsx-Sheet2.plotly.html`. Adding `--outdir results/plots` saves it as `results/plots/my_workbook.xlsx-Sheet2.plotly.html`. The PDF and PNG share that prefix. Re-running with the same output directory, input basename, and sheet overwrites these outputs.

- **HTML:** interactive plot; open it in a browser. With Pandoc, this is a single self-contained file. Without Pandoc, a companion `{input_basename}-{sheet}.plotly_files/` directory is saved in the output directory; keep it beside the HTML when moving or sharing the plot. The selection handler is embedded, so browser-console setup and the original `plotly_save_select_ids.js` file are unnecessary when viewing the saved HTML.
- **PDF:** 12 × 8 inches.
- **PNG:** 12 × 8 inches at 300 dpi (3600 × 2400 pixels).

## Download selected sample IDs

1. Open the generated HTML in a browser.
2. Choose **Box Select** or **Lasso Select** from the Plotly toolbar.
3. Select points. Completing a nonempty selection triggers a text-file download using the browser's download settings.

Hover text includes `ave_per_2a`, `ave_per_2b`, `CNR`, `3A`, and `3B`.

Each download contains one `sampleID` per selected point, without a header. Duplicate IDs are retained if multiple selected points share an ID. Empty selections do not trigger downloads; a selection with a missing sample ID is cancelled with a browser-console error.

The download filename summarizes the selection:

```text
selected_2a{mean_2a}_2b{mean_2b}_3a{mean_3a}_CNR{mode}_N{count}.txt
```

For example:

```text
selected_2a64_2b71_3a66_CNRWT_N25.txt
```

- Each mean uses the corresponding `ave_per_*` column and rounds to the nearest integer using JavaScript `Math.round` (halfway values round toward positive infinity).
- Missing or non-finite values are excluded separately from each mean; a mean with no usable values becomes `NA`.
- `CNR` is the most common selected cluster value. Ties use the first label in JavaScript's default string sort order. Filename-unsafe characters are replaced with underscores.
- `N` counts selected points, including points whose `ave_per_3a` is missing.

The script retrieves IDs from the selected trace's `key` array using the point index. After editing the JavaScript, rerun the R script and reload the generated HTML to embed the changes.

## Troubleshooting

- **Workbook not found:** check the input path relative to your current working directory, or pass an absolute path with `--xlsx`.
- **Worksheet not found:** use its exact name with `--sheet`; the error lists available worksheets.
- **Missing required columns:** check row 2 and ensure all required headers fall within A:P.
- **Pandoc unavailable message:** informational; HTML is saved with a companion `_files` directory, and PDF/PNG export continues. To generate a single self-contained HTML file, install Pandoc and ensure `Rscript -e 'rmarkdown::pandoc_available()'` returns `TRUE` in the environment running the script, then rerun it.
- **Selection download does not appear:** use the selection tools rather than zoom, check the browser's download permissions, and inspect its console for missing-ID errors.
