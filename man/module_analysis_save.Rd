% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/func_group_analysis.R
\name{module_analysis_save}
\alias{module_analysis_save}
\title{Save analysis to look up tables}
\usage{
module_analysis_save(project_name, subject_code, module_id, analysis_name,
  file, meta = NULL)
}
\arguments{
\item{project_name}{project name}

\item{subject_code}{subject code}

\item{module_id}{module id}

\item{analysis_name}{user-specified, use module_analysis_names to get all of'em}

\item{file}{which file saved to.}

\item{meta}{one row of data.frame adding additional data (multiple ones will be ignored)}
}
\description{
Save analysis to look up tables
}
