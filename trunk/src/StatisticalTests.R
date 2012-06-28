#!/bin/Rscript
# Rscript args.R "1 or 2" confidenceLevel
# where first argument suggests type of test: 1- non-parametric and 2 - parametric
args <- commandArgs(TRUE)

typeOfTest = as.numeric(args[1])
confidenceLevel = as.numeric(args[2])
