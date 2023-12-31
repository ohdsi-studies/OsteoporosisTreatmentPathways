% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/extractSubResults.R
\name{extractSubResults}
\alias{extractSubResults}
\title{Extract Results}
\usage{
extractSubResults(
  connectionDetails,
  cdmDatabaseSchema,
  cohortDatabaseSchema,
  cohortTable,
  outputFolder
)
}
\arguments{
\item{connectionDetails}{An object of type \code{connectionDetails} as created using the
\code{\link[DatabaseConnector]{createConnectionDetails}} function in the
DatabaseConnector package.}

\item{cdmDatabaseSchema}{Schema name where your patient-level data in OMOP CDM format resides.
Note that for SQL Server, this should include both the database and
schema name, for example 'cdm_data.dbo'.}

\item{cohortDatabaseSchema}{Schema name where intermediate data can be stored. You will need to have
write priviliges in this schema. Note that for SQL Server, this should
include both the database and schema name, for example 'cdm_data.dbo'.}

\item{cohortTable}{The name of the table that will be created in the work database schema.
This table will hold the exposure and outcome cohorts used in this
study.}

\item{outputFolder}{Name of local folder where the results were generated; make sure to use forward slashes
(/). Do not use a folder on a network drive since this greatly impacts
performance.}

\item{oracleTempSchema}{Should be used in Oracle to specify a schema where the user has write
priviliges for storing temporary tables.}
}
\description{
Extract Results
}
\details{
Extract Duration, Demographics etc. Results.
}
