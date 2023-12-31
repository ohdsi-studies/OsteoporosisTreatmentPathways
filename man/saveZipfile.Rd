% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/saveZipfile.R
\name{saveZipfile}
\alias{saveZipfile}
\title{Create Zip file}
\usage{
saveZipfile(databaseName, outputFolder)
}
\arguments{
\item{databaseName}{Some meta-information that will be used by the export function.}

\item{outputFolder}{Name of local folder where the results were generated; make sure to use forward slashes
(/). Do not use a folder on a network drive since this greatly impacts performance.}
}
\description{
Compress the analysis results files
}
