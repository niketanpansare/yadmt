# yadmt
For my recent project, I faced with a problem: I had to compare my model's performance against a standard model under different parameter settings. For comparison, I ran off-the-shelf classifiers on the features outputed by the respective models. I soon realized there was no easy and efficient way to do that, and hence I wrote this tool.
## Target Audience:

1. A machine learning researcher who developed a new classifier and wants to test it against traditional ones, but does not want to spend time:
  * dealing with different formats of various classifiers,
  * baby-sitting the experiments so as not to crash the server by running too many parallel instances,
  * and still wants to get the job done as fast as possible (since the paper deadline is approaching fast ;-) )
  * or does not own a server and wants to use cluster instead (may be even on-demand clusters like Amazon EC2). 
2. Another machine learning researcher who has same concerns as the one above, but unlike the above person, he/she has developed a new model that outputs set of features and want to use classification accuracy as a measure to compare it against traditional models.
3. Researchers who knows very little about machine learning and want to run off-the-shelf classifiers on their datasets. 

Please read Usage wiki-page for more details.

## Functionality:
* Packages useful open-source tools (such as svmlight, weka, etc)
* Configurable to support different parameters for different classifiers
* Auto load-balancing
* Extremely simple to use
* Can be run on cluster without much hassle
* Support cross-validation (i.e. can run many cycles on the datasets for standard statistical tests)
* Outputs the accuracies in intuitive format
* Also can compare the accuracies of various classifiers by running statistical tests on them

## Demo:
[Youtube video](https://www.youtube.com/watch?v=-gxLSx-NEjE)

## Usage:
1. If you are using cluster,
  * Make sure that you have setup passwordless ssh over your cluster.
  * Create a login file "~/yadmt/loginFile" containing the names of machine (For Amazon EC2, use private DNS). Use ':' for local machine 
  
2. Create a file "~/yadmt/files.txt" that contains path of input files. The input file should be in format suggested by svmlight. The below commands should create files.txt in the folder "~/yadmt" containing full-path of all the files inside "my_data_directory".
    cd my_data_directory
    ls -d -1 $PWD/*.* > ~/yadmt/files.txt

3. Now run the following command that will walk you through the process:
    cd ~/yadmt
    ./yadmt --wizard

## Disclaimer:
This software uses third-party software such as svmlight, Weka, etc. Some of these software require you to take permissions from the authors if you plan to use it for commercial reasons. So, I will assume you are going to use this tool only for educational purpose only. For all other purposes, please contact respective authors/creators of those softwares.
Regarding yadmt, it is free only for non-commercial use. The author is not responsible for implications from the use of this software.
Also note that, if you prefer a GUI version without any load balancing, clusters or statistical tests features, use Weka experimenter. 
