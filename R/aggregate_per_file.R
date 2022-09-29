#' Aggregate day summary per file
#'
#' @param fullreport full daysummary report from GGIR
#' @param includenightcrit include night criteria in hours
#' @param includedaycrit include day criteria in hours
#' @param include24hcrit include 24h window criteria in hours
#' @param data_cleaning_file data cleaning csv file as in GGIR
#' @param outputdir output directory
#' @import GGIR
#' @import stats
#' @return save reports
#' @export
aggregate_per_file = function(fullreport = c(), includenightcrit = c(), includedaycrit = c(),
                              include24hcrit = c(), data_cleaning_file = c(),
                              outputdir = "./", LUX_day_segments = c()) {
  # description: function to load the full daysummary report from GGIR and it returns a clean copy
  # based on specified criteria

  # 1 - clean fullreport -----
  dur_day_wear_min = fullreport$dur_day_min * (100 - fullreport$nonwear_perc_day) / 100
  dur_night_wear_min = fullreport$dur_spt_min * (100 - fullreport$nonwear_perc_spt) / 100
  dur_24h_wear_min = fullreport$dur_day_spt_min * (100 - fullreport$nonwear_perc_day_spt) / 100
  cols2add = (ncol(fullreport) + 1):(ncol(fullreport) + 3)
  fullreport[, cols2add] = cbind(dur_day_wear_min, dur_night_wear_min, dur_24h_wear_min)
  colnames(fullreport)[cols2add] = c("dur_day_wear_min", "dur_night_wear_min", "dur_24h_wear_min")

  # conditions
  rm1 = which(is.na(dur_day_wear_min) | dur_day_wear_min < includedaycrit*60)
  rm2 = which(is.na(dur_night_wear_min) | dur_night_wear_min < includenightcrit*60)
  rm3 = which(is.na(dur_24h_wear_min) | dur_24h_wear_min < include24hcrit*60)
  cleancode = data.frame(day = rep(0, nrow(fullreport)),
                         night = rep(0, nrow(fullreport)),
                         fullwindow = rep(0, nrow(fullreport)))
  cleancode$day[rm1] = 1; cleancode$night[rm2] = 1; cleancode$fullwindow[rm3] = 1
  colnames(cleancode) = c("excluded_wear_day", "excluded_wear_night", "excluded_wear_24h")


  #======================================================================

  # split results to different spreadsheets in order to minimize individual filesize and to ease organising dataset
  fullreport$daytype = 0
  fullreport$daytype[which(fullreport$weekday == "Sunday" | fullreport$weekday == "Saturday")] = "WE"
  fullreport$daytype[which(fullreport$weekday == "Monday" | fullreport$weekday == "Tuesday" |
                             fullreport$weekday == "Wednesday" | fullreport$weekday == "Thursday" |
                             fullreport$weekday == "Friday")] = "WD"

  # clean daysummary
  remove = unique(c(rm1, rm2, rm3))
  daysummary_clean = fullreport[-remove,]

  #------------------------------------------------------------------------------------
  # also compute summary per person
  agg = function(df,filename="filename", daytype =" daytype") {
    # function to take both the weighted (by weekday/weekendday) and plain average of all numeric variables
    # df: input data.frame (OF3 outside this function)
    ignorevar = c("daysleeper","cleaningcode","night_number","sleeplog_used","ID","acc_available","window_number",
                  "boutcriter.mvpa", "boutcriter.lig", "boutcriter.in", "bout.metric")
    for (ee in 1:ncol(df)) { # make sure that numeric columns have class numeric
      nr = nrow(df)
      if (nr > 30) nr = 30
      options(warn=-1)
      trynum = as.numeric(as.character(df[1:nr,ee]))
      options(warn=0)
      if (length(which(is.na(trynum) == TRUE)) != nr &
          length(which(ignorevar == names(df)[ee])) == 0) {
        options(warn=-1)
        class(df[,ee]) = "numeric"
        options(warn=0)
      }
    }
    plain_mean = function(x) {
      options(warn=-1)
      plain_mean = mean(x,na.rm=TRUE)
      options(warn=0)
      if (is.na(plain_mean) == TRUE) {
        plain_mean = x[1]
      }
      return(plain_mean)
    }
    # aggregate across all days
    PlainAggregate = aggregate.data.frame(df,by=list(df$filename),FUN=plain_mean)
    PlainAggregate = PlainAggregate[,-1]
    return(PlainAggregate)
  }
  #---------------------------------------------
  # Calculate, weighted and plain mean of all variables
  OF4 = agg(daysummary_clean, filename = "filename", daytype = "daytype")
  # calculate additional variables
  OF3tmp = daysummary_clean[,c("filename","night_number","daysleeper","cleaningcode","sleeplog_used","guider",
                                       "acc_available","nonwear_perc_day","nonwear_perc_spt","daytype","dur_day_min",
                                       "dur_spt_min")]
  foo34 = function(df,aggPerIndividual,nameold,namenew,cval) {
    # function to help with calculating additinal variables
    # related to counting how many days of measurement there are
    # that meet a certain criteria
    # cval is a vector with 0 and 1, indicating whether the criteria is met
    # aggPerIndividual is the aggregate data (per individual)
    # df is the non-aggregated data (days across individuals
    # we want to extra the number of days per individuals that meet the
    # criteria in df, and make it allign with aggPerIndividual.
    df2 = function(x) df2 = length(which(x==cval)) # check which values meets criterion
    mmm = as.data.frame(aggregate.data.frame(df,by=list(df$filename),FUN = df2),
                        stringsAsFactors = TRUE)
    mmm2 = data.frame(filename=mmm$Group.1, cc=mmm[,nameold], stringsAsFactors = TRUE)
    aggPerIndividual = merge(aggPerIndividual, mmm2,by="filename")
    names(aggPerIndividual)[which(names(aggPerIndividual)=="cc")] = namenew
    foo34 = aggPerIndividual
  }
  # # calculate number of valid days (both night and day criteria met)
  OF3tmp$validdays = 1
  # now we have a label for the valid days, we can create a new variable
  # in OF4 that is a count of the number of valid days:
  OF4 = foo34(df=OF3tmp,aggPerIndividual=OF4,nameold="validdays",namenew="Nvaliddays",cval=1)
  # do the same for WE (weekend days):
  OF3tmp$validdays = 0
  OF3tmp$validdays[which(OF3tmp$daytype== "WE")] = 1
  OF4 = foo34(df=OF3tmp,aggPerIndividual=OF4,nameold="validdays",namenew="Nvaliddays_WE",cval=1)
  # do the same for WD (weekdays):
  OF3tmp$validdays = 0
  OF3tmp$validdays[which(OF3tmp$daytype == "WD")] = 1
  OF4 = foo34(df=OF3tmp,aggPerIndividual=OF4,nameold="validdays",namenew="Nvaliddays_WD",cval=1) # create variable from it
  # do the same for daysleeper,cleaningcode, sleeplog_used, acc_available:
  OF3tmp$validdays = 1
  OF4 = foo34(df = OF3tmp, aggPerIndividual = OF4, nameold = "daysleeper", namenew = "Ndaysleeper", cval = 1)
  OF4 = foo34(df = OF3tmp, aggPerIndividual = OF4, nameold = "cleaningcode", namenew = "Ncleaningcodezero", cval = 0)
  for (ccode in 1:6) {
    OF4 = foo34(df = OF3tmp, aggPerIndividual = OF4, nameold = "cleaningcode",
                namenew=paste0("Ncleaningcode", ccode), cval = ccode)
  }
  OF4 = foo34(df = OF3tmp,aggPerIndividual = OF4, nameold = "sleeplog_used", namenew = "Nsleeplog_used", cval = TRUE)
  OF4 = foo34(df = OF3tmp,aggPerIndividual = OF4, nameold = "acc_available", namenew = "Nacc_available", cval = 1)
  # Move valid day count variables to beginning of dataframe
  OF4 = cbind(OF4[,1:5],OF4[,(ncol(OF4)-10):ncol(OF4)],OF4[,6:(ncol(OF4)-11)])
  nom = names(OF4)
  cut = which(nom == "sleeponset_ts" | nom == "wakeup_ts" | nom == "night_number"  | nom == "window_number"
              | nom == "daysleeper" | nom == "cleaningcode" | nom == "acc_available"
              | nom == "guider" | nom == "L5TIME" | nom == "M5TIME"
              | nom == "L10TIME" | nom == "M10TIME" | nom == "acc_available" | nom == "daytype")
  names(OF4)[which(names(OF4)=="weekday")] = "startday"
  OF4 = OF4[,-cut]
  for (col4 in 1:ncol(OF4)) {
    navalues = which(is.na(OF4[,col4]) == TRUE)
    if (length(navalues) > 0) {
      OF4[navalues, col4] = ""
    }
  }
  #Move Nvaliddays variables to the front of the spreadsheet
  Nvaliddays_variables = grep(x = colnames(OF4), pattern = "Nvaliddays", value = FALSE)
  Nvaliddays_variables = unique(c(which(colnames(OF4) =="Nvaliddays"),
                                  which(colnames(OF4) =="Nvaliddays_WD"),
                                  which(colnames(OF4) =="Nvaliddays_WE"), Nvaliddays_variables))
  OF4 = OF4[,unique(c(1:4, Nvaliddays_variables, 5:ncol(OF4)))]
  #-------------------------------------------------------------
  # store all summaries in csv files
  personsummary_clean = GGIR::tidyup_df(OF4)
  daysummary_clean = GGIR::tidyup_df(daysummary_clean)

  return(list(person = personsummary_clean, day = daysummary_clean, cleaning = cleancode))
}
