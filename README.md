# WHSacc

<!-- badges: start -->

<!-- badges: end -->

The goal of WHSacc is to automatically and interactively process the [Women's Health Study (WHS)](https://whs.bwh.harvard.edu/) accelerometer data files using the [GGIR](https://cran.r-project.org/web/packages/GGIR/index.html) package.

## Installation and use example

You can install the development version of WHSacc from [GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("jhmigueles/WHSacc")
```

To use the WHSacc package, run the "runGGIR" function and follow the instructions:

``` r
library(WHSacc)
WHSacc::runGGIR()
```

## Accelerometer data collection protocol

This is a brief summary on how the accelerometer data was collected in the WHS:

-   **Device:** ActiGraph GT3X
-   **Attachment site:** hip
-   **Sample frequency:** 30 Hz
-   **Protocol:** devices mailed to participants, who were asked to wear them for 7 consecutive days, removing them for sleep and water-based activities
-   **Files to process:** gt3x files zipped into either ".gz" or ".7z" files.

## How this package works

1.  The user is asked to select the files to process
2.  The files are unzipped and stored in a new directory named "unzipped files"
3.  GGIR is called and the data processing begins
    -   if there are more than 100 files, the files are processed in chunks of 100 with a for loop
    -   Output and datasets are derived at the end of the for loop, so, if the process is interrupted before ending the for loop, you will not see the GGIR datasets and visualizations
4.  If specified by the user, the generated files in the "unzipped files" directory are removed at the end of the process

## GGIR function call

Summary of the settings used:

-   Epoch length of 5 seconds and aggregated to 60 seconds in g.part5
-   At least 10 wear hours to consider a valid day
-   Sleep period time fixed from 11PM to 6AM
-   [Hildebrand et al. cutoffs for hip](https://pubmed.ncbi.nlm.nih.gov/24887173/)
-   Sedentary bouts of \>30 and \>60 min/day
-   MVPA bouts of \>5 and \>10 min/day

This is the function call I use within the WHSacc package:

``` r
GGIR(mode = 1:5,
     #BASIC SETTINGS
     datadir = datadir,         # selected by user
     outputdir = outputdir,     # selected by user
     studyname = "WHS",
     overwrite = overwrite,     # selected by user
     print.filename = T, printsummary = T,
     sensor.location = "hip",
     #G.PART1: GET ENMO VALUES
     windowsizes = c(5, 900, 3600),
     desiredtz = "US/Eastern",
     do.enmo = T, do.mad = F,
     do.anglex = T, do.angley = T, do.anglez = T,
     dayborder = 0,
     acc.metric = "ENMO",
     #G.PART2: FIRST ESTIMATIONS OF PHYSICAL ACTIVITY
     idloc = 6,
     strategy = 1,
     hrs.del.start = 0, hrs.del.end = 0,
     includedaycrit = 10,
     winhr = c(5,10),
     qwindow = c(0, 24),
     qlevels = c((1440 - 60)/1440,   # M60
                 (1440 - 30)/1440,   # M30
                 (1440 - 15)/1440,   # M15
                 (1440 - 10)/1440,   # M10
                 (1440 - 5)/1440),   # M5
     ilevels = c(),
     mvpathreshold = 70,
     boutcriter = 0.8, bout.metric = 6,
     epochvalues2csv = FALSE,
     #G.PART3-4: SLEEP CLASSIFICATION
     def.noc.sleep = c(23, 6),
     relyonguider = TRUE,
     sleepwindowType = "SPT",
     constrain2range = TRUE,
     HASPT.algo = c(),
     longitudinal_axis = 1,
     anglethreshold = 5, timethreshold = 5,
     possible_nap_window = c(9, 18),
     possible_nap_dur = c(30, 180),
     do.visual = TRUE,
     outliers.only = FALSE,
     includenightcrit = 0,
     ignorenonwear = FALSE,
     #G.PART5: MERGE SLEEP AND PHYSICAL ACTIVITY DATA
     part5_agg2_60seconds = TRUE,
     threshold.lig = 20, threshold.mod = 70, threshold.vig = 260, 
     boutdur.mvpa = c(5, 10), boutdur.in = c(30, 60), boutdur.lig = c(10, 30),
     boutcriter.mvpa = 0.8, boutcriter.in = 0.9, boutcriter.lig = 0.8,
     timewindow = c("MM"),
     save_ms5rawlevels = TRUE, save_ms5raw_without_invalid = FALSE,
     save_ms5raw_format = "csv",
     week_weekend_aggregate.part5 = FALSE,
     #REPORTS
     do.report = c(2,4,5),
     visualreport = TRUE,
     do.parallel = TRUE)
```
