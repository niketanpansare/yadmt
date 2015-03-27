## High level instructions:
1. If you are using cluster,
  * Make sure that you have setup passwordless ssh over your cluster.
  * Create a login file "~/yadmt/loginFile" containing the names of machine (For Amazon EC2, use private DNS). Use ':' for local machine 

2. Create a file "~/yadmt/files.txt" that contains path of input files. The input file should be in format suggested by svmlight. The below commands should create files.txt in the folder "~/yadmt" containing full-path of all the files inside "my_data_directory".

    cd my_data_directory
    ls -d -1 $PWD/*.* > ~/yadmt/files.txt

3. Now run the following command that will walk you through the process:

    cd ~/yadmt
    ./yadmt --wizard

## Different setup:

While using yadmt for classification, you would be interested in one of the following questions:

1. For a given dataset, find the best classifier (in this section, the classifier refers to "classifier+parameter" combo, i.e. "svm_poly+degree2")
  * See section "How to find best classifier" 
2. Given many datasets, find the best classifier on each datasets.
  * This is same as asking question 1 on every dataset, i.e. treating every dataset independent of each other. Good news is you don't have to run yadmt for every single dataset. All you have to do is modify getParameterName file and add path of every dataset in files.txt and yadmt will take care of the rest. 
3. Given many datasets and just 1 classifier, compare the classifier's performance across the datasets.
  * Since not many researchers are interested in this question, this feature is hidden intentionally. Set "COMPARE_DATASETS=1" in yadmt to enable this (Note: only for advanced users).
  * This is useful for people that have developed feature selection models like LDA or CTM and wants to compare their efficacy using classification. In this case, we suggest that you re-run your models to generate n datasets and specify 1 for number of cycles in yadmt and not vice-versa. 
4. Given many datasets and many classifiers, find the best classifier overall.
  * This is a tricky question and yadmt doesnot answer that directly (although it does that indirectly by answering questions 2 and 3). We suggest that you run appropriate statistical tests on accuracy file and make your own decision (See StatisticalTests.R for reference). 
5. Given a very large dataset (that will definitely make off-the-self classifiers run out of memory), find the best classifier.
  * As a performance hack, you can randomly partition the dataset into smaller datasets and ask question 2. However, a word of caution, some classifiers have weird property that they might work well on smaller datasets and might not work so well on larger dataset (or at least there is no guarantee that they will). We suggest using Apache Mahout or writing your own Hadoop-based or disk-based classifier. 
6. Given a newly developed classifier ("control classifier"), test its performance across traditional classifiers.
  * Feature under development. 
7. Ask above questions by for different performance measures like ROC, precision/recall, etc
  * Feature under development. 
  
## Input format:

The input file has to be of format suggested by SVMLight:

    classLabel featureNum:featureValue ...

The class label should be {1,-1} for binary classification and a positive integer for multi-class classification. Example:

    1 1:1.75814e-14 2:1.74821e-05 3:1.37931e-08 4:1.25827e-14 5:4.09717e-05 6:1.28084e-09 7:2.80137e-22 8:2.17821e-24

## Output format:

yadmt outputs 2 files:
  * An accuracy file with format: "accuracy classifierName cycleNumber dataset"
  * An HTML file comparing the classifiers that is described in below section. 
  
## How to find best classifier:

yadmt ranks the classifiers for you by default by running StatisticalTests.R on the accuracy file. It outputs the results in tabular html format (where entry inside the table is average accuracy over all the runs and superscripts specifies the rank of that classifier for the given dataset). Example:

Results from Friedman rank sum test:
	dataset1 	dataset2
svm_linear 	89.879 1 	89.005 2
svm_poly_2 	89.805 1 	89.663 2
svm_poly_3 	89.832 1 	90.242 1
svm_rbf_0.1 	90.289 1 	89.032 3

The above table suggests that after running Friedman test, for dataset1, all the classifiers performed equally well. In this case, I would suggest increase the number of cycles or decrease the level of significance to get more comparable ranking.

But for dataset2, polynomial SVM with degree 3 performed significantly better than linear and polynomial SVM with degree 2, which in turn performed significantly better than SVM RBF with gamma 0.1.

To get the above table, StatisticalTests.R runs one of the following statistical tests to compare the classifier:
1. Non-parametric tests (Wilcoxon test for 2-classifiers and Friedman test for n-classifiers)
2. Parametric tests (paired t-test for 2-classifiers and Tukey's HSD test for n-classifiers) 

For more details about these tests, see Demsar's 2006 paper.

## Supported classifiers:

1. SVMLight, SVMMulticlass: linear, polynomial and RBF SVMs.
2. Weka: Naive Bayes (multinomial/normal prior), C 4.5 decision tree, Multi-response linear regression, Logistic regression and Random forest. 

## Known Issues:

If the number of elements for a given class is too low as compared to others, it could be the case that for either test or training data, there would be no element from that class. In this case, the Weka classifiers (but not the SVMs) could fail. Following script helps sometime by randomizing the input:

    cd ~/yadmt/
    for file in `cat files.txt`
    do
      cp $file blah.temp
      sort -R blah.temp > $file
      rm blah.temp
    done
