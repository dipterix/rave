% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/func_rave_prepare.R
\name{rave_prepare}
\alias{rave_prepare}
\title{Function to load subject and create ECoG data environment}
\usage{
rave_prepare(subject, electrodes, epoch, time_range, frequency_range,
  data_types = c("power"), reference = "default", attach = "r",
  load_brain = FALSE, data_env = getDefaultDataRepository(),
  strict = FALSE)
}
\arguments{
\item{subject}{characters, format: "PROJECT/SUBJECT"}

\item{electrodes}{numeric vector, which electrodes to be loaded}

\item{epoch, }{characters, depending on subject meta data. For example, use "epoch1" if exists epoch file "epoch_epoch1.csv"}

\item{time_range, }{vector of length 2 - before and after onset. For example, c(1,2), means 1 second before onset and 2 seconds after onset.}

\item{frequency_range, }{vector of length 2 - lowest and highest frequencies. By default is all frequencies. Only applied to power and phase data.}

\item{data_types, }{vector of characters, data to be preloaded. "power" - referenced power data, "phase" - referenced phase data, "volt" - referenced voltage data}

\item{reference, }{similar to epoch, For example, use "default" if exists reference file "reference_default.csv"}

\item{attach, }{characters or NULL, NULL if you don't want to attach it, "r" if want to load data as R environment, "py" if python, "matlab" for matlab.}

\item{load_brain}{try to load freesurf files?}

\item{data_env, }{environment to load data into.}

\item{strict}{check data completness? default is FALSE (suggested)}
}
\description{
Function to load subject and create ECoG data environment
}
\details{
Usually this function is for module writters and for debug use, or adhoc analysis.
}
