#!/bin/bash

#  initialize.sh configFile loginFile
#  
#
#  Created by Niketan Pansare

# Has to be of format "configFile,inputFile,cycleNum,classifier,optional_params" without any spaces
PGM_NAME=$0
CONFIG_FILE=$1
#LOGIN_FILE=$2

# Has MAX_MEMORY_CLASSIFIER, ACCURACY_FILE, RESULTS_FILE + FILES, NUM_CYCLES, CLASSIFIERS, DEGREES_SVM_POLY, GAMMAS_SVM_RBF
source "./"$CONFIG_FILE

CONTROL_FILE="controlFile-"$RANDOM"-"$RANDOM"-"$RANDOM".txt"
rm $CONTROL_FILE &> /dev/null

for file in `cat $FILES`
do
  for cycle in `seq 1 $NUM_CYCLES`
  do
    for classifier in $CLASSIFIERS
    do
      if [ "$classifier" == "svm_poly" ]; then
        for degree in $DEGREES_SVM_POLY
        do
          OUTPUT_STR=$CONFIG_FILE","$file","$cycle","$classifier","$degree
          echo $OUTPUT_STR >> $CONTROL_FILE
        done
      elif [ "$classifier" == "svm_rbf" ]; then
        for gamma in $GAMMAS_SVM_RBF
        do
          OUTPUT_STR=$CONFIG_FILE","$file","$cycle","$classifier","$gamma
          echo $OUTPUT_STR >> $CONTROL_FILE
        done
      else
        OUTPUT_STR=$CONFIG_FILE","$file","$cycle","$classifier
        echo $OUTPUT_STR >> $CONTROL_FILE
      fi
    done
  done
done

#To include the local computer add the special sshlogin ':' to the list:
# server.example.com
# foo@server2.example.com
# server3.example.com
# :



# seq 1 5 | parallel echo
# seq 1 5 | parallel --max-args=2 echo

# Delayed start (will sleep between random 1-5 seconds before starting a job):
# seq 1 5 | parallel --max-args=2 'sleep $((RANDOM*4/32767+1));echo {}'


#ssh-copy-id -i ~/.ssh/id_rsa.pub username@

# Replacing xargs by more powerful gnu-parallel: cat $CONTROL_FILE | xargs --max-args=1 --max-procs=100 ./runClassifier.sh &
# Delayed start makes sure that machines don't get overloaded. It may however adversely affect small jobs.
# However, the assumption is that running a classification task is usually extremely time-consuming task, so sleeping for few second
# should not affect overall performance drasctically.
# --sshloginfile $LOGIN_FILE

# Randomizing the control file helps in load balancing as different classifiers have different requirements (cpu-demanding, memory demanding, etc)
sort -R $CONTROL_FILE > $CONTROL_FILE".temp"
cat $CONTROL_FILE".temp" | parallel --max-args=1 --load 95% 'sleep $((RANDOM*4/32767+1)); ~/yadmt/runClassifier {}'
rm $CONTROL_FILE".temp" $CONTROL_FILE &> /dev/null

# Use --tag to debug
# parallel --tag --nonall --sshloginfile $LOGIN_FILE 'cat $ACCURACY_FILE' > $ACCURACY_FILE".final" 
#parallel --tag --nonall --sshloginfile $LOGIN_FILE 'cat $ACCURACY_FILE' > $ACCURACY_FILE".final"