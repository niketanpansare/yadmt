#!/bin/Rscript
# Rscript args.R "1 or 2" confidenceLevel
# where first argument suggests type of test: 1- non-parametric and 2 - parametric
args <- commandArgs(TRUE)

typeOfTest = as.numeric(args[1])
confidenceLevel = as.numeric(args[2])

library(ggplot2) # for ddply
library(agricolae) # for HSD.test and friedman

names(performanceData) <- c("Accuracy", "Classifier", "Cycles", "Dataset")
attach(performanceData)

performanceSummary <- ddply(performanceData, .(performanceData$Classifier), function(myRow) data.frame(performanceData.avgAccuracy=mean(myRow$Accuracy)))
names(performanceSummary) <- c("Classifier", "AverageAccuracy")
performanceData$Classifier <- factor(performanceData$Classifier)
performanceData$Cycles <- factor(performanceData$Cycles)
performanceData$Dataset <- factor(performanceData$Dataset)
performanceSummary <- performanceSummary[with(performanceSummary, order(-AverageAccuracy)),]
numClasses <- nrow(performanceSummary)

#sort by cycles
performanceData <- performanceData[with(performanceData, order(Cycles)),]

# default values
differenceInPerformanceMeasure <- 0 # for 2 class
significanceLevel <- 0.95

stat_test <- 1 # 1 for non-parametric and 2 for parameteric

tempPerformanceData <- performanceData

nameOfDataSets <- levels(performanceData$Dataset)

cat("<table>\n")
cat("<th><td> Classifier </td><td> Average Accuracy </td><td> Dataset </td></th> \n")

for(d in 1:numDatasets) {
  nameOfDataSet <- nameOfDataSets[d]
  performanceData <- subset(tempPerformanceData, tempPerformanceData$Dataset == nameOfDataSet)

  if(numClasses == 2) {
    if(stat_test == 1) {
      #cat("Results using Wilcoxon signed rank test:\n")
      myPVal <- wilcox.test(Accuracy ~ Classifier, data=performanceData, mu=differenceInPerformanceMeasure, conf.level=significanceLevel, paired=TRUE)$p.value 
    }
    else {
      #cat("Results using Paired t-test:\n")
      myPVal <- t.test(Accuracy ~ Classifier, data=performanceData, mu=differenceInPerformanceMeasure, conf.level=significanceLevel, paired=TRUE)$p.value 
    }
    
    if(myPVal < (1 - significanceLevel)) {
      ranking <- c(1,2)
    }
    else {
      ranking <- c(1,1)
    }
  }
  else {
    if(stat_test == 1) {
      # cat("Results using Friedman rank sum test:\n")
      #myPVal <- friedman.test(Accuracy ~ Classifier | Cycles, data=performanceData)$p.value 
      dat <- with(performanceData, friedman(Cycles, Classifier, Accuracy, group=TRUE))
      prevLevel <- ""
      prevRank <- 0
      for(i in 1:numClasses) {
        if(dat$M[i] != prevLevel) {
          prevLevel <- dat$M[i]
          prevRank <- prevRank + 1
        }
        cat("<tr><td>", dat$trt[i], "</td><td>", subset(performanceSummary, performanceSummary$Classifier == dat$trt[i])$AverageAccuracy , "<sup>", prevRank,"</sup></td><td>", nameOfDataSet, "</td></tr>\n")	
      }

    }
    else {
      # cat("Results using Tukey's HSD test:\n")
      dat <- HSD.test(aov(Accuracy ~ Classifier, data=performanceData), "Classifier", group=TRUE, alpha=(1-significanceLevel))
      prevLevel <- ""
      prevRank <- 0
      for(i in 1:numClasses) {
        if(dat$M[i] != prevLevel) {
          prevLevel <- dat$M[i]
          prevRank <- prevRank + 1
        }
        cat("<tr><td>", dat$trt[i], "</td><td>", dat$means[i], "<sup>", prevRank,"</sup></td><td>", nameOfDataSet, "</td></tr>\n")	
      }
    }
  }
}
cat("</table>\n")
