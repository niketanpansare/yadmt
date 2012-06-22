//
//  GetNumberOfClasses.cpp
//  
//
//  Created by Niketan Pansare on 6/21/12.
//  Copyright (c) 2012 Rice University. All rights reserved.
//

#include <iostream>
#include <fstream>
#include <string>
#include <cstring>
#include <cstdlib>
#include <cassert>
#include <climits>
#include <set>
#include "Assert.h"

using namespace std;

int GetNumFeaturesNClasses(const char* fileName, int* numClasses);

// Usage: GetMetaInformationOfInputSVM input-file [numFeatures/numClasses]
int main(int argc, char* argv[]) {
  ASSERT(argc == 3) << "Incorrect number of arguments" << DIE;
  int numClasses = 0;
  int numFeatures = GetNumFeaturesNClasses(argv[1], &numClasses);  
  if(strcmp(argv[2], "numFeatures") == 0) {
    cout << numFeatures;
  }
  else if(strcmp(argv[2], "numClasses") == 0) {
    cout << numClasses;
  }
  else {
    ASSERT(false) << "Second argument to " << argv[0] << " should be [numFeatures/numClasses], not \'" << argv[2] << "\'" << DIE;
  }
}

// This takes a string with format '7:22.5' and returns 22.5 (along with 7 as outputFeatureNum)
double GetValueAndFeatureNumber(char* inputString, int* outputFeatureNum, int lineNum, int featureNum) {
  for(int i = 0; i < 500; i++) {
    if(inputString[i] == ':') {
      inputString[i] = '\0';
      *outputFeatureNum = atoi(inputString);
      return atof(&inputString[i+1]);
    }
  }
  ASSERT(false) << "Error while generating Arff file >>" << inputString << "<< at line:" << lineNum << " and featureNum:" << featureNum << DIE; 
}

int GetNumFeaturesNClasses(const char* fileName, int* numClasses) {
  ifstream infile;
  infile.open(fileName);
  char arr[500];
  int maxFeatureNum = 0;
  int lineNum = 1; string line;
  set<int> classes;
  
  while(getline(infile,line)) {
    if(line.compare("") == 0) {
      break; // break since empty line
    }
    char* myLine = new char[line.length() + 1];
    line.copy(myLine, line.length());
    myLine[line.length()] = '\0';
    char* pch = strtok(myLine," ");
    int featureNum = 0; 
    while(pch != NULL) {
      if(strcmp(pch, "") == 0) {
        pch = strtok (NULL, " ");
        continue;
      }
      if(featureNum == 0) {
        int classValue = strtol(pch, NULL, 10);
        classes.insert(classValue);
      }
      else {
        ASSERT(strstr(pch, ":") != NULL) << "Incorrect format at line " << lineNum << " in file " << fileName << "\'" << pch << "\'" << DIE; 
        
        int myCurrFeatureNum = 0;
        strcpy(arr, pch);
        double myValue = GetValueAndFeatureNumber(arr, &myCurrFeatureNum, lineNum, featureNum);
        maxFeatureNum = maxFeatureNum > myCurrFeatureNum ? maxFeatureNum : myCurrFeatureNum;
      }
      featureNum++;
      pch = strtok (NULL, " ");
    }
    lineNum++;
  }
  *numClasses = classes.size();
  if(classes.size() == 2) {
    for(set<int>::iterator it= classes.begin(); it != classes.end(); it++) {
      ASSERT(*it == 1 || *it == -1) << "Class values need to be either -1 or 1 for 2 class problem" << DIE; 
    }
  }
  else {
    for(set<int>::iterator it= classes.begin(); it != classes.end(); it++) {
      ASSERT(*it > 0 && *it <= *numClasses) << "Class values need to be between [1, " << (*numClasses) << "] for  " << (*numClasses) << "-class problem in file: " << fileName << DIE; 
    }
  }
  
  ASSERT(*numClasses > 1) << "Incorrect number of classes in file " << fileName << DIE;
  ASSERT(maxFeatureNum > 0) << "Number of features has to be greater than 0, but it is " << maxFeatureNum << " for file: " << fileName << DIE;
  return maxFeatureNum;
}