#!/bin/Rscript
# Rscript StatisticalTests.R  accuracy.txt output.html stat_test significanceLevel COMPARE_DATASETS
# where third argument (stat_test) suggests type of test: 1- non-parametric and 2 - parametric
# significanceLevel=0.95, and COMPARE_DATASETS=0

is.installed <- function(mypkg) is.element(mypkg, installed.packages()[,1])

if(is.installed("agricolae") == FALSE) {
  install.packages("agricolae")
}
library(agricolae) # for HSD.test and friedman

args <- commandArgs(TRUE)
performanceData <- read.table(args[1])
COMPARE_DATASETS <- as.numeric(args[5])
# default
names(performanceData) <- c("Accuracy", "Classifier", "Cycles", "Dataset")
if(COMPARE_DATASETS == 1) {
  # Very stupid hack to compare datasets :)
  names(performanceData) <- c("Accuracy", "Dataset", "Cycles", "Classifier")
}
outputFileName <- args[2]
stat_test = as.numeric(args[3]) # 1 for non-parametric and 2 for parameteric
significanceLevel = as.numeric(args[4]) # 0.95

# default values
differenceInPerformanceMeasure <- 0 # for 2 class

#sort by cycles
performanceData <- performanceData[with(performanceData, order(Cycles)),]
performanceData$Classifier <- factor(performanceData$Classifier)
performanceData$Dataset <- factor(performanceData$Dataset)
performanceData$Cycles <- factor(performanceData$Cycles)
tempPerformanceData <- performanceData

nameOfDataSets <- levels(performanceData$Dataset)
nameOfClassifiers <- levels(performanceData$Classifier)
numDatasets <- length(nameOfDataSets)
numClassifiers <- length(nameOfClassifiers)

outputLines <- rep("<tr> <td>", numClassifiers)
for(i in 1:numClassifiers) {
  outputLines[i] <- paste(outputLines[i], nameOfClassifiers[i], "</td>")
}

outputTest <- ""

for(d in 1:numDatasets) {
  performanceData <- subset(tempPerformanceData, tempPerformanceData$Dataset == nameOfDataSets[d])

  if(numClassifiers == 2) {
    if(stat_test == 1) {
      # Wilcoxon signed rank test:
      outputTest <- "Results from Wilcoxon signed rank test:"
      myPVal <- wilcox.test(Accuracy ~ Classifier, data=performanceData, mu=differenceInPerformanceMeasure, conf.level=significanceLevel, paired=TRUE)$p.value 
    }
    else {
      # Paired t-test:
      outputTest <- "Results from Paired t-test:"
      myPVal <- t.test(Accuracy ~ Classifier, data=performanceData, mu=differenceInPerformanceMeasure, conf.level=significanceLevel, paired=TRUE)$p.value 
    }
    
    if(myPVal < (1 - significanceLevel)) {
      avgAccuracy1 <- mean(subset(performanceData, performanceData$Classifier == nameOfClassifiers[1])$Accuracy)
      avgAccuracy2 <- mean(subset(performanceData, performanceData$Classifier == nameOfClassifiers[2])$Accuracy)
      if(avgAccuracy1 > avgAccuracy2) {
        outputLines[1] <- paste(outputLines[1],"<td>", avgAccuracy1, "<sup> 1 </sup></td>")  
        outputLines[2] <- paste(outputLines[2],"<td>", avgAccuracy2, "<sup> 2 </sup></td>")
      }
      else {
        outputLines[1] <- paste(outputLines[1],"<td>", avgAccuracy1, "<sup> 2 </sup></td>")  
        outputLines[2] <- paste(outputLines[2],"<td>", avgAccuracy2, "<sup> 1 </sup></td>")
      }
    }
    else {
      for(i in 1:numClassifiers) {
        avgAccuracy <- mean(subset(performanceData, performanceData$Classifier == nameOfClassifiers[i])$Accuracy)
        outputLines[i] <- paste(outputLines[i],"<td>", avgAccuracy, "<sup> 1 </sup></td>")
      }
    }
  }
  else {
    if(stat_test == 1) {
      # Friedman rank sum test:
      outputTest <- "Results from Friedman rank sum test:"
      # myPVal <- friedman.test(Accuracy ~ Classifier | Cycles, data=performanceData)$p.value 
      dat <- with(performanceData, friedman(Cycles, Classifier, Accuracy, group=TRUE))
    }
    else {
      # Tukey's HSD test:
      outputTest <- "Results from Tukey's HSD test:"
      dat <- HSD.test(aov(Accuracy ~ Classifier, data=performanceData), "Classifier", group=TRUE, alpha=(1-significanceLevel))
    }
    prevLevel <- ""
    prevRank <- 0
    superScripts <- rep("", numClassifiers)
    for(i in 1:numClassifiers) {
      if(dat$M[i] != prevLevel) {
        prevLevel <- dat$M[i]
        prevRank <- prevRank + 1
      }
      for(j in 1:numClassifiers) {
        if(dat$trt[i] == nameOfClassifiers[j]) {
          avgAccuracy <- mean(subset(performanceData, performanceData$Classifier == nameOfClassifiers[j])$Accuracy)
          outputLines[j] <- paste(outputLines[j],"<td>", avgAccuracy, "<sup>",  prevRank, "</sup></td>") 
          break;
        }
      }
    }
    
  }
}

cat("<html>\n<body>\n<table style=\"border:1px solid black;\">\n", file=outputFileName)
cat(outputTest, "\n", file=outputFileName, append=TRUE)
cat("<tr> <th>  </th>", file=outputFileName, append=TRUE)

for(d in 1:numDatasets) {
  cat("<th>", nameOfDataSets[d], "</th>", file=outputFileName, append=TRUE)
}
cat("</tr> \n", file=outputFileName, append=TRUE)
for(i in 1:numClassifiers) {
  outputLines[i] <- paste(outputLines[i], "</tr>\n")
  cat(outputLines[i], file=outputFileName, append=TRUE)
}
cat("</table>\n</body>\n</html>\n", file=outputFileName, append=TRUE)
