#' unzipWHSfiles
#'
#' @description Function to decompress the WHS files (only works with gz or 7z files)
#'
#' @param WHSfiles directory with the files to unzip
#'
#' @return datadir definition for GGIR
#' @export
#'
#' @import archive
#' @import R.utils
#'
unzipWHSfiles = function(WHSfiles) {

  # create new directory to unzip files
  datadir = file.path(dirname(WHSfiles[1]), "unzipped files")
  if (!dir.exists(datadir)) dir.create(datadir)
  cat("Extracting zipped files...\n")
  pb = txtProgressBar(min = 0, max = length(WHSfiles), initial = 0, style = 3)

  # keep unzipped files for new datadir
  keep = c()

  for (i in 1:length(WHSfiles)) {
    # find out file extension
    format = tools::file_ext(x = WHSfiles[i])

    # extract files in case they are gz or 7z
    if (format == "gz") {
      tmp1 = unlist(strsplit(WHSfiles[i], "[.]cs"))
      tmp2 = unlist(strsplit(WHSfiles[i], "[.]gt"))

      if (length(tmp1) > 1) { # then a csv file
        FixPath4GGIR = !grepl(pattern = "csv.gz", x = WHSfiles[i])
        if (FixPath4GGIR) {
          remove = gsub("v", "", tmp1[2])
          remove = gsub(".gz", "", remove)
          newname = gsub(remove, "", WHSfiles[i])
          file.rename(WHSfiles[i], newname)
          keep = c(keep, newname)
          rm(newname); gc()
        } else {
          keep = c(keep, WHSfiles[i])
        }
      } else if (length(tmp2) > 1 ) {
        # then a gt3x file
        # check that file extension is fine
        newname = gsub(".gz", "", WHSfiles[i])
        if (tools::file_ext(newname) != "gt3x") {
          newname = paste0(newname, ".gt3x")
        }
        newfile = file.path(datadir, basename(newname))

        if (!file.exists(newfile)) {
          R.utils::gunzip(WHSfiles[i], remove = FALSE,
                          destname = newfile)
        }
      }
    } else if (format == "7z") {
      archive::archive_extract(WHSfiles[i],
                               dir = datadir)
      # newname = gsub(".7z", "", WHSfiles[i])
      # # check that file extension is fine
      # if (tools::file_ext(newname) != "gt3x") {
      #   newname2 = paste0(newname, ".gt3x")
      #   file.rename(newname, newname2)
      # }
    } else {
      stop("This package only works with gz or 7z files at the moment.")
    }
    setTxtProgressBar(pb,i)
  }

  # define new datadir
  files2process = c(dir(datadir, full.names = TRUE), keep)
  files2process = gsub("\\", "/", files2process, fixed = TRUE)

  cat("\nFiles unzipped\n\n")

  invisible(files2process)

}
