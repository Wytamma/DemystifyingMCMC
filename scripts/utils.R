# this scripts implements some useful functions for working with BEAST data in R
# to use these functions a `source('utils.R')` to your R scipt

# find the MCA of a set of paths
get_common_dir <- function(paths, delim = "/") {
  path_chunks <- strsplit(paths, delim)
  i <- 1
  repeat ({
    current_chunk <- sapply(path_chunks, function(x)
      x[i])
    if (any(current_chunk != current_chunk[1]))
      break
    i <- i + 1
  })
  paste(path_chunks[[1]][seq_len(i - 1)], collapse = delim)
}

# function to read BEAST2 log file
read.logFile <- function(path_to_logFile, burn_in) {
  logFile <-
    read.csv(path_to_logFile,
             sep = "\t",
             comment.char = '#')
  logFile <- type.convert(logFile, as.is = TRUE)
  logFile <-
    logFile[logFile$Sample >= max(logFile$Sample) * burn_in,]
  return (logFile)
}

# function to read multiple BEAST2 log files
read.logFiles <- function(paths, burn_in, prior = TRUE) {
  logFiles <- data.frame()
  Chain <- 0
  for (path_to_logFile in sort(paths)) {
    Chain <- Chain + 1
    logFile <- read.logFile(path_to_logFile = path_to_logFile,
                            burn_in = burn_in)
    logFile['Chain'] = Chain
    logFiles <- rbind(logFiles, logFile)
  }
  return(logFiles)
}
