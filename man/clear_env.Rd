% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils_general.R
\name{clear_env}
\alias{clear_env}
\title{Function to clear all elements within environment}
\usage{
clear_env(env, all.names = T)
}
\arguments{
\item{env}{environment to clean}

\item{all.names}{clear all variables?}
}
\description{
Function to clear all elements within environment
}
\examples{
\dontrun{
env = new.env()
env$a = 1
print(as.list(env))

clear_env(env)
print(as.list(env))
}
}
