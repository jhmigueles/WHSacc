#' runGGIR
#'
#' @description Main function to run GGIR over the WHS files
#'
#' @param interactive If TRUE (default), the directory selection is interactive
#'
#' @export
#'
#' @import GGIR
runGGIR = function(interactive = TRUE) {

  # before starting, make sure we work with GGIR v.2.8.0 or newer and archive v.1.1.5
  if (packageVersion("GGIR") < "2.8.0" & packageVersion("archive") < "1.1.5") {
    cat("Please, update the GGIR and the archive packages before running WHSacc:\n
         1 - restart the R session\n
         2 - install.packages('GGIR')
         3 - install.packages('archive')\n")
    stop()
  } else if (packageVersion("GGIR") < "2.8.0" | packageVersion("archive") < "1.1.5") {
    package = ifelse(packageVersion("GGIR") < "2.8.0", "GGIR", "archive")
    stop(cat("Please, update", package, "before running WHSacc:\n",
             "1 - restart the R session\n",
             ifelse(package == "GGIR", "2 - install.packages('GGIR')",
                    "2 - install.packages('archive')\n")))
  }

  # 1 - select files ----
  if (interactive) {
    zipfiles = invisible(choose.files(caption = "Select the accelerometer files to process",
                                      multi = TRUE))
    zipfiles = gsub('\\\\', '/', zipfiles)
    zipdir = dirname(zipfiles)
  } else {
    zipdir = readline(prompt = 'Write the path to the directory with your files: ')
    zipdir = gsub('\\"', '', zipdir)
    zipdir = gsub("\\'", "", zipdir)

    zipfiles = dir(zipdir, full.names = TRUE)
    if ("unzipped files" %in% basename(zipfiles)) zipfiles = zipfiles[-which(basename(zipfiles) == "unzipped files")]
  }
  nFiles = length(zipfiles)
  cat(paste0("\nThere are ", nFiles,
             " files to process.\n",ifelse(nFiles > 6, "Here the first 6 file names", "Here are the file names"),
             ", is this correct?\n"))
  print(head(basename(zipfiles)))

  cat("\n1: Yes\n2: No\n")

  moveon = readline(prompt = 'Answer: ')

  if (moveon == "2") stop("Run again the runGGIR function and select the correct files")

  # From here on, run in chunks in case there are more than 100 files
  if (nFiles > 100) {
    f0 = seq(1, nFiles, by = 100)
    f1 = seq(100, nFiles, by = 100)
    if (length(f0) != length(f1)) f1[length(f1) + 1] = nFiles
  } else {
    f0 = 1
    f1 = nFiles
  }

  # This should never occur, but just in case:
  if (length(f0) != length(f1)) stop("Contact Jairo, something went wrong here")

  # 3 - outputdir ----
  cat("\n")
  cat(paste0(rep("_", options()$width), collapse = ""))
  outputdir = unique(dirname(zipdir))

  cat("\nShould the output files and datasets be stored in", paste0(outputdir,"?"))
  cat("\n1: Yes\n2: No\n")
  moveon = readline(prompt = 'Answer: ')
  if (moveon == "2") {
    outputdir = readline(prompt = 'Write the path to the directory to save the output files and datasets: ')
    outputdir = gsub('\\"', '', outputdir)
    outputdir = gsub("\\'", "", outputdir)
  }

  # 4 - should the files be removed at the end of the process? ----
  cat("\n")
  cat(paste0(rep("_", options()$width), collapse = ""))
  cat("\nDo you want to remove the unzipped files generated at the end of the process?")
  cat("\n1: Yes\n2: No\n")
  removeFiles = readline(prompt = 'Answer: ')
  cat("\n")

  for (chunk in 1:length(f0)) {
    # backup of all selected files
    if (chunk == 1) zipfiles_all = zipfiles

    # files to process in this loop
    zipfiles = zipfiles_all[f0[chunk]:f1[chunk]]

    # 1 - unzip files ----
    datadir = unzipWHSfiles(zipfiles)

    # 2 - run GGIR ----
    # set overwrite to FALSE in case this is an iteration of the for loop
    if (chunk > 1) overwrite = FALSE

    GGIR::GGIR(mode = 1:5,

               #BASIC SETTINGS
               datadir = datadir,
               outputdir = outputdir,
               studyname = "WHS_acc",
               overwrite = FALSE,
               desiredtz = "US/Eastern",
               idloc = 6,

               # Dealing with nonwear during nights
               do.imp = FALSE,
               ignorenonwear = FALSE,
               windowsizes = c(5, 300, 3600), # higher resolution in the nonwear detection

               # data cleaning
               includedaycrit = 8,
               includenightcrit = 0,
               includedaycrit.part5 = 8,

               # descriptive variables
               qlevels = c((1440 - 60)/1440,   # M60
                           (1440 - 30)/1440,   # M30
                           (1440 - 15)/1440,   # M15
                           (1440 - 10)/1440,   # M10
                           (1440 - 5)/1440),   # M5
               mvpathreshold = 70,

               #G.PART3-4: SLEEP CLASSIFICATION
               constrain2range = TRUE,
               possible_nap_window = c(9, 18),
               possible_nap_dur = c(30, 180),

               #G.PART5: MERGE SLEEP AND PHYSICAL ACTIVITY DATA (DEFINITIVE DATASET)
               part5_agg2_60seconds = TRUE,
               threshold.lig = 20, threshold.mod = 70, threshold.vig = 260,
               boutdur.mvpa = c(5, 10), boutdur.in = c(30, 60), boutdur.lig = c(10, 30),
               boutcriter.mvpa = 0.8, boutcriter.in = 0.9, boutcriter.lig = 0.8,
               timewindow = c("MM"),
               save_ms5rawlevels = TRUE, save_ms5raw_without_invalid = FALSE,
               save_ms5raw_format = "csv",
               week_weekend_aggregate.part5 = TRUE,

               #REPORTS
               do.report = c(2,4,5),
               visualreport = TRUE,
               do.parallel = FALSE)

    # 6 - remove processed files? ----
    if (removeFiles == "1") {
      cat("\n\nRemoving generated files...")
      remove = unique(dirname(datadir))
      remove = remove[which(basename(remove) == "unzipped files")]
      unlink(remove, recursive = TRUE)
    }

    # END!!
    cat("\n\nDone!\n\n")
  }

  # 7 - Clean dataset ----
  resultsdir = paste0(outputdir, "/output_", "WHS_acc/results/QC/")
  datasets = dir(resultsdir, full.names = TRUE)
  daypath = grep("daysummary_full_MM", datasets, value = TRUE)
  daysummary = read.csv(daypath)

  # make average week report based in clean data
  cleanReports = aggregate_per_file(fullreport = daysummary, includenightcrit = 0, includedaycrit = 10,
                                    include24hcrit = 10, data_cleaning_file = c())

  # Save clean reports
  write.csv(cleanReports$person, paste0(outputdir, "/personsummary.csv"), row.names = F)
  write.csv(cleanReports$day, paste0(outputdir, "/daysummary.csv"), row.names = F)
  write.csv(cleanReports$cleaning, paste0(outputdir, "/cleaning_report.csv"), row.names = F)
}
