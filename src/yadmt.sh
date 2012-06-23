#!/bin/bash

#  yadmt configFile [TODO For Multiple machines: loginFile]
#
#  To use loginFile, you need to have password-less ssh
#  ssh-copy-id -i ~/.ssh/id_rsa.pub username@remote-server
#
#  Created by Niketan Pansare

# Has to be of format "configFile,inputFile,cycleNum,classifier,optional_params" without any spaces
PGM_NAME=$0
IS_WIZARD="FALSE"
USER_HOME=$(eval echo ~${SUDO_USER})
YADMT_DIR=$USER_HOME"/yadmt"
USER_NAME=$(id -un)
HOST_NAME=$(hostname --long)

LOGIN_FILE=$YADMT_DIR"/login.txt"

# Delete lock file before starting yadmt
rm -r /tmp/yadmt.lock/ &> /dev/null

###########################
# cleanup code
CLEANED_UP="FALSE"
function cleanup {
  if [ "$CLEANED_UP" == "FALSE" ]; then
    CLEANED_UP="TRUE"
    rm -rf $CONFIG_FILE $CONTROL_FILE &> /dev/null
  fi
}
# Trap user interrupts
trap "cleanup; exit 0" SIGHUP SIGINT SIGTERM
trap "cleanup;" EXIT
trap "cleanup;" ERR
###########################


if [ "$#" == "0" ]; then
  echo >&2 $PGM_NAME " - Expected an argument. Try running" $PGM_NAME "--wizard"
  exit 1
elif [ "$1" == "--wizard" ]; then
##############################
# Wizard
IS_WIZARD="TRUE"

# 1 - Single machine, 2 - multiple machines (accessible via ssh), 3 - EC2 cluster 
echo "yadmt supports following configuration:"
echo "1. Single machine"
echo "2. Multiple machines (accessible via passwordless ssh)"
echo -n "Which configuration do you want to run (1,2):"
read ANS
echo ""

if [ "$ANS" == "1" ]; then 
  EXPERIMENTAL_SETUP="1"
  echo "OK, will run yadmt on this machine only."
  echo ""
elif [ "$ANS" == "2" ]; then 

  echo -n "Do you want to use this machine i.e. " $USER_NAME"@"$HOST_NAME "(y/n):"
  read ANS
  echo ""
  if [ "$ANS" == "y" ]; then
    echo ":" > $LOGIN_FILE
  elif [ "$ANS" == "n" ]; then
    echo -n "" > $LOGIN_FILE
  else
    echo >&2 $PGM_NAME " - Invalid input."
    exit 1
  fi

  ANS="y"
  while "$ANS" == "y"
  do
    echo -n "Do you want to use more machine (y/n):"
    read ANS
    if [ "$ANS" == "y" ]; then
      echo "Login info of a remote machine can be username@remote-machine or just remote-machine"
      echo -n "Enter login info:"
      read REMOTE_LOGIN_INFO
      echo $REMOTE_LOGIN_INFO >> $LOGIN_FILE
    fi
  done
  
  echo ""

  echo "For sharing data across these machines, yadmt allows following option:"
  echo "1. SCP file transfer among machines"
  echo "2. Amazon S3"
  echo -n "Which option do you want(1,2):"
  read ANS
  echo ""
  if [ "$ANS" == "1" ]; then 
    EXPERIMENTAL_SETUP="2"
  elif [ "$ANS" == "2" ]; then 
    EXPERIMENTAL_SETUP="3"
  else
    echo >&2 $PGM_NAME " - Invalid option."
    exit 1
  fi
else
  echo >&2 $PGM_NAME " - Invalid configuration."
  exit 1
fi


echo "yadmt supports following tasks:"
echo "1. Classification"
echo "2. Topic Modelling"
echo -n "Which task do you wish to perform (1,2,...):"
read TASK1
echo ""

CONFIG_FILE=$YADMT_DIR"/config.txt"
CONTROL_FILE=$YADMT_DIR"/controlFile.txt"


echo "EXPERIMENTAL_SETUP="$EXPERIMENTAL_SETUP > $CONFIG_FILE
echo "MASTER="$USER_NAME"@"$HOST_NAME >> $CONFIG_FILE
# This means when disk space on home reaches 95%, don't keep any more file in disk cache (i.e. ~/yadmt/data)
echo "MAXIMUM_DISK_SPACE_TO_USE=95" >> $CONFIG_FILE

if [ "$TASK1" == "1" ]; then
  # Classification

  TASK="CLASSIFICATION"
  echo "TASK="$TASK >> $CONFIG_FILE  

  echo "yadmt supports following classifiers:"
  echo "svm_linear svm_poly svm_rbf naive_bayes"
  echo "(Hint: An example for below input is: svm_linear naive_bayes)" 
  echo -n "Enter the list of classifiers separated by space you wish to run:"
  read CLASSIFIERS
  echo ""
  echo "CLASSIFIERS=\""$CLASSIFIERS"\"" >> $CONFIG_FILE

  
  for classifier in $CLASSIFIERS
  do
    if [ "$classifier" == "naive_bayes" ]; then
      echo "Classifiers such as Weka may require large amount of memory depending on the input size."
      echo -n "Specify the amount of maximum memory in MB that a classifier can use (eg: 300, 1000):"
      read MAX_MEMORY_CLASSIFIER
      echo ""
      echo "MAX_MEMORY_CLASSIFIER="$MAX_MEMORY_CLASSIFIER >> $CONFIG_FILE
      
    elif [ "$classifier" == "svm_linear" ]; then 
      # Do nothing
      echo -n ""
    elif [ "$classifier" == "svm_poly" ]; then 
      echo -n "Enter the list of degree separated by space you wish to run for svm_poly (eg: 2 3 4):"
      read DEGREES_SVM_POLY
      echo ""
      echo "DEGREES_SVM_POLY=\""$DEGREES_SVM_POLY"\"" >> $CONFIG_FILE
    elif [ "$classifier" == "svm_rbf" ]; then 
      echo -n "Enter the list of gamma separated by space you wish to run for svm_rbf (eg: 0.001 0.01 0.1):"
      read GAMMAS_SVM_RBF
      echo ""
      echo "GAMMAS_SVM_RBF=\""$GAMMAS_SVM_RBF"\"" >> $CONFIG_FILE
    else
      echo >&2 $PGM_NAME " - Incorrect classifier:" classifier
      exit 1
    fi
  done
  
  echo -n "Enter the number of cycles you wish to run:"
  read NUM_CYCLES
  echo ""
  echo "NUM_CYCLES="$NUM_CYCLES >> $CONFIG_FILE

  echo -n "Enter the file name where you wish to store the accuracy (accuracy.txt):"
  read ACCURACY_FILE
  echo ""
  echo "ACCURACY_FILE="$ACCURACY_FILE >> $CONFIG_FILE
  
  echo -n "Enter the file name where you wish to store the results by each classifier (result.txt):"
  read RESULTS_FILE
  echo ""
  echo "RESULTS_FILE="$RESULTS_FILE >> $CONFIG_FILE

  echo "Make sure that you specify absolute path for below files."
  echo -n "Enter the file name that contains list of input files (files.txt):"
  read FILES
  echo ""
  echo "FILES="$FILES >> $CONFIG_FILE

  echo "Most experiments require to compare different models/parameters (example: features for CTM or LDA). yadmt assumes that:"
  echo "- One input file (in format of SVMLight/SVMMulticlass) is generated per parameter."
  echo "- For comparing different parameters, user has program X that takes the input file name and outputs string denoting the parameter name for that input file."
  echo "- Default program X outputs the string \"parameter1\" for every input file"
  echo -n "Do you want to use default program X (y/n):"
  read ANS
  echo ""
  if [ "$ANS" == "n" ]; then
    echo -n "Enter the path of user-defined program X:"
    read PROGRAMX
    echo ""
  else 
    PROGRAMX=$YADMT_DIR"/getParameterName"
  fi
  echo "PROGRAMX="$PROGRAMX >> $CONFIG_FILE
  
elif [ "$TASK1" == "2" ]; then
  # Topic Modeling
  TASK="TOPIC_MODELING"
  echo "Topic modeling not supported yet"
  exit 1
fi


##############################
else
  CONFIG_FILE=$1
fi


#LOGIN_FILE=$2

# Has MAX_MEMORY_CLASSIFIER, ACCURACY_FILE, RESULTS_FILE + FILES, NUM_CYCLES, CLASSIFIERS, DEGREES_SVM_POLY, GAMMAS_SVM_RBF
source $CONFIG_FILE

function cool_progress_ind {
  chars=( "[ - ]" "[ \\ ]" "[ | ]" "[ / ]" )
  interval=1
  count=0

  echo -n "     "
  while true
  do
  pos=$(($count % 4))

  echo -en "\b\b\b\b\b${chars[$pos]}"

  count=$(($count + 1))
  sleep $interval
  done
}

function stop_progress_ind {
  exec 2>/dev/null
  kill $1
  echo -en "\n"
}


if [ "$TASK" == "CLASSIFICATION" ]; then
#----------------------------------------------
  # Classification

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

  # Replacing xargs by more powerful gnu-parallel: cat $CONTROL_FILE | xargs --max-args=1 --max-procs=100 ./runClassifier.sh &
  # Delayed start makes sure that machines don't get overloaded. It may however adversely affect small jobs. However, the assumption is that running a classification task is usually extremely time-consuming task, so sleeping for few second should not affect overall performance drasctically.
  # TODO For Multiple machines: --sshloginfile $LOGIN_FILE
  RUN_CLASSIFIER_PATH=$YADMT_DIR"/runClassifier"
  if [ "$IS_WIZARD" == "TRUE" ]; then
    echo -n "Running classification task. Please wait "
    cool_progress_ind &
    pid=$!
    # If yadmt is interrupted, this will take care of killing progress bar
    trap "stop_progress_ind $pid; exit" INT TERM EXIT

    if [ "$EXPERIMENTAL_SETUP" == "1"  ]; then
      cat $CONTROL_FILE | parallel --max-args=1 --load 95% "sleep $((RANDOM*2/32767+1));"$RUN_CLASSIFIER_PATH' {};'
    else
      # first delete previous data folder
      parallel --sshloginfile $LOGIN_FILE "rm -rf "$YADMT_DIR"/data" &> /dev/null
      # then start the program
      cat $CONTROL_FILE | parallel --max-args=1 --sshloginfile $LOGIN_FILE --load 95% "sleep $((RANDOM*2/32767+1));"$RUN_CLASSIFIER_PATH' {};'
      # delete after finishing the program
      parallel --sshloginfile $LOGIN_FILE "rm -rf "$YADMT_DIR"/data" &> /dev/null
    fi

    stop_progress_ind $pid
  else
      if [ "$EXPERIMENTAL_SETUP" == "1"  ]; then
        cat $CONTROL_FILE | parallel --max-args=1 --load 95% "sleep $((RANDOM*2/32767+1));"$RUN_CLASSIFIER_PATH' {}'
      else
        # first delete previous data folder
        parallel --sshloginfile $LOGIN_FILE "rm -rf "$YADMT_DIR"/data" &> /dev/null
        # then start the program
        cat $CONTROL_FILE | parallel --max-args=1 --sshloginfile $LOGIN_FILE --load 95% "sleep $((RANDOM*2/32767+1));"$RUN_CLASSIFIER_PATH' {}'
        # delete after finishing the program
        parallel --sshloginfile $LOGIN_FILE "rm -rf "$YADMT_DIR"/data" &> /dev/null
      fi
  fi

  if [ "$IS_WIZARD" == "TRUE" ]; then
    echo "Done with classification task."
  fi

  # Use --tag to debug
  # TODO For Multiple machines:
  # parallel --nonall --sshloginfile $LOGIN_FILE 'cat $ACCURACY_FILE' > $ACCURACY_FILE".final" 

# Classification ends
#----------------------------------------------


elif [ "$TASK" == "TOPIC_MODELING" ]; then
#----------------------------------------------
  # Topic Modeling
  echo -n "" 

  # Topic Modeling ends
#----------------------------------------------
fi