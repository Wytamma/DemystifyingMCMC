library(bayesplot)
library(gridExtra)
library(ggplot2)
library(dplyr)
# commonly used functions (specify path to be relative to your main working dir)
source('scripts/utils.R')

# The script (`posterior_plots.R`)  will produce a range plots for the given
# BEAST log file. If a directory is provided all log files in any of the sub folders
# will be treated as duplicate runs.
# Run with:
# $ Rscript posterior_plots.R path/to/BEAST.log | path/to/out/directory  [optional:burn-in]

# --- SETTINGS ---
parameters <- c()  # parameters to plot, all by default - vector string
burn_in <- 0 #  set burn_in (discard samples up to burn_in) - float

# --- SETUP ---
args = commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  stop("Must provide a BEAST log file or directory as the first arg")
} else if (length(args) == 2) {
  burn_in <- as.numeric(args[2])
  if (burn_in >= 1) {
    stop("Burn un must be < 1")
  }
}

if (grepl('.log$', args[1])) {
  paths <- c(args[1])
} else if (dir.exists(args[1])) {
  paths <- list.files(
    args[1],
    pattern = '*.log',
    recursive = TRUE,
    full.names = TRUE
  )
  if (length(paths) == 0) {
    stop(paste("Could not find BEAST log files in directory:", args[1]))
  }
} else {
  stop("Must provide a BEAST log file or directory as the first arg")
}

if (length(paths) > 1) {
  out_dir <- paste0(get_common_dir(paths), '/plots/')
} else {
  out_dir <- paste0(dirname(paths[1]), '/plots/')
}

message(paste("Creating plots folder:", out_dir))
dir.create(out_dir, showWarnings = FALSE)
message(paste("Burn-in set to:", burn_in))

mcmc <- read.logFiles(
  paths = paths,
  burn_in = burn_in
)

mcmc <- mcmc[,!(names(mcmc) == "Sample")]  # Drop samples column

if (length(parameters) > 0) {
  # filter by parameters if provided
  # "Chain" is required by BayesPlot
  mcmc <- mcmc[, names(mcmc) %in% c(parameters, "Chain")]
}

mcmc[mcmc == Inf] <- NA  # replace inf with NA
mcmc <- mcmc[, colSums(is.na(mcmc)) == 0]  # Drop empty columns

# --- PLOTS ---
message("Creating trace.pdf plot...")
p <- mcmc_trace(mcmc) + facet_text(size = 16)
ggsave('trace.pdf',
  path = out_dir,
  p,
  height = length(names(mcmc)),
  width = length(names(mcmc)) * 1.8,
  limitsize = FALSE
)

message("Creating acf.pdf plot...")
p <-  mcmc_acf(mcmc) + facet_text(size = 16)
ggsave('acf.pdf',
  path = out_dir,
  p,
  width = length(names(mcmc)) * 2,
  limitsize = FALSE
)

message("Creating hist.pdf plot...")
p <- mcmc_hist(mcmc) + facet_text(size = 16)
ggsave('hist.pdf',
  path = out_dir,
  p,
  height = length(names(mcmc)),
  width = length(names(mcmc)),
  limitsize = FALSE
)

message("Creating dens.pdf plot...")
p <- mcmc_dens(mcmc) + facet_text(size = 16)
ggsave('dens.pdf',
  path = out_dir,
  p,
  height = length(names(mcmc)),
  width = length(names(mcmc)),
  limitsize = FALSE
)

if (length(unique(mcmc$Chain)) > 1) {
  message("Creating hist_by_chain.pdf plot...")
  p <- mcmc_hist_by_chain(mcmc) + facet_text(size = 16)
  ggsave('hist_by_chain.pdf',
    path = out_dir,
    p,
    height = length(unique(mcmc$Chain)),
    width = length(names(mcmc)) * 2,
    limitsize = FALSE
  )
  message("Creating violin.pdf plot...")
  p <-
    mcmc_violin(mcmc,  probs = c(0.05, 0.5, 0.95)) + facet_text(size = 16)
  ggsave('violin.pdf',
    path = out_dir,
    p,
    height = length(names(mcmc)),
    width = length(names(mcmc)),
    limitsize = FALSE
  )
}

message("Creating pairs.pdf plot...")
p <-
  mcmc_pairs(mcmc %>% group_by(Chain) %>% sample_n(500),
             off_diag_args = list(size = 1, alpha = 0.5))
p <- ggsave('pairs.pdf',
  path = out_dir,
  p,
  height = length(names(mcmc)) * 1.5,
  width = length(names(mcmc)) * 1.5,
  limitsize = FALSE,
)




