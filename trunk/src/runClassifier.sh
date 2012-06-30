#!/bin/bash

#  runClassifier.sh INPUT_CONFIGURATION
#  where INPUT_CONFIGURATION to be of format "configFile*inputFile*cycleNum*classifier*optional_params" without any spaces
#  Valid values for SVM_TYPE are 
#  svm_linear (linear), svm_poly (polynomial where * = 2, 3, 4, ...) 
#  svm_rbf (Radial Basis)
#
#  Created by Niketan Pansare

# Has to be of format "configFile,inputFile,cycleNum,classifier,optional_params" without any spaces
PGM_NAME=$0
USER_HOME=$(eval echo ~${SUDO_USER})
YADMT_DIR=$USER_HOME"/yadmt"
LOCKDIR="/tmp/yadmt.lock"

INPUT_CONFIGURATION=$1
#ARGS="$@"
#for INPUT_CONFIGURATION in "$ARGS"
#do
# set CONFIG_FILE, INPUT_FILE and CYCLE_NUM
Array=(`echo $INPUT_CONFIGURATION | tr "," "\n"`)
CONFIG_FILE="${Array[0]}"
INPUT_FILE="${Array[1]}"
CYCLE_NUM="${Array[2]}" 
CLASSIFIER="${Array[3]}" 
if [ "$CLASSIFIER" == "svm_poly" ]; then
  if [ "${#Array[@]}" == "5" ]; then
    DEGREE="${Array[4]}"
  else
    echo >&2 $PGM_NAME " - Expected degree for svm_poly"
    exit 1
  fi
elif [ "$CLASSIFIER" == "svm_rbf" ]; then
  if [ "${#Array[@]}" == "5" ]; then
    GAMMA="${Array[4]}"
  else
    echo >&2 $PGM_NAME " - Expected gamma for svm_rbf"
    exit 1
  fi
elif [ "$CLASSIFIER" == "naive_bayes" ]; then
  if [ "${#Array[@]}" == "5" ]; then
    PRIOR="${Array[4]}"
  else
    echo >&2 $PGM_NAME " - Expected prior for naive_bayes"
    exit 1
  fi
fi

###########################
# Locking mechanism to avoid race conditions when parallel runs
function acquire_lock {
  local LOCK_ACQUIRED="FALSE"
  while [ "$LOCK_ACQUIRED" == "FALSE" ]; 
  do
    if ! mkdir "$LOCKDIR" 2> /dev/null
    then
      sleep 1s
    else
      local LOCK_ACQUIRED="TRUE"
    fi
  done
}
function release_lock {
  rm -rf "$LOCKDIR" &> /dev/null
}
###########################
function cleanup {
  # cleanup code: Don't delete lock on finish since it can be held by some other instance of this script
  rm -rf $RANDOMIZED_INPUT_FILE $MODEL_FILE $TEMP_FILE1 $TEMP_FILE2 $TEMP_FILE3 $PRED_FILE $TRAIN_FILE $TEST_FILE &> /dev/null 
#if [ "$EXPERIMENTAL_SETUP" != "1" ]; then 
# Ignoring any disk issue for now !!
#FREE_DISK=`df /home | awk '{ print $5 }' | tail -n 1 | sed 's/%//'`
#if [ "$FREE_DISK" -gt "$MAXIMUM_DISK_SPACE_TO_USE" ]; then
#acquire_lock
      # Least recently used algorithm
      # Delete all but the most recent 2 input files
#cd $YADMT_DIR"/data"
#(ls -t|head -n 2;ls)|sort|uniq -u|xargs rm
#release_lock
#fi
#fi  
}
# Trap user interrupts
trap "cleanup" INT TERM EXIT ERR
###########################

#Read variables: MAX_MEMORY_CLASSIFIER, ACCURACY_FILE, RESULTS_FILE, MASTER, EXPERIMENTAL_SETUP
source $CONFIG_FILE

mkdir $YADMT_DIR"/data" &> /dev/null

# Only input files go in data directory
RANDOMIZED_INPUT_FILE=$YADMT_DIR"/input-"$RANDOM"-"$RANDOM"-"$RANDOM".txt"

if [ "$EXPERIMENTAL_SETUP" == "2" ]; then
  TEMP_INPUT_FILE=$INPUT_FILE
  ONLY_FILE_NAME_WITH_EXT=$(basename "$INPUT_FILE")
  INPUT_FILE=$YADMT_DIR"/data/"$ONLY_FILE_NAME_WITH_EXT

  # Double checking for efficiency so that you don't have to acquire lock 
  if [ ! -e $INPUT_FILE ]; then
    acquire_lock
    # So that only 1 process can download a file
    # Also, since control file ensures that input files are listed sequentially, this is really efficient mechanism !!!
    if [ ! -e $INPUT_FILE ]; then
      # Get file if it doesnot exists
      scp $MASTER":"$TEMP_INPUT_FILE $INPUT_FILE
    fi
    release_lock
  fi
elif [ "$EXPERIMENTAL_SETUP" == "3" ]; then
  echo >&2 $PGM_NAME " - Amazon S3 service not supported yet."
  exit 1
fi

#acquire_lock --> Needs to acquire lock since there is a chance that someone else might delete the input file. But since you delete only when disk reaches 95% and that too files other than recent 3, its highly unlikely that someone lese will delete the input file. On other hand, not locking here improves the performance drastically.
# sort -R fails for Macbook Pro
if ! sort -R $INPUT_FILE > $RANDOMIZED_INPUT_FILE 2> /dev/null
then
  echo >&2 $PGM_NAME " - Your system doesnot support \"sort -R\" option required to randomize the input file."
  rm $RANDOMIZED_INPUT_FILE &> /dev/null
  exit 1
fi
#release_lock

MODEL_FILE="model."$RANDOM"-"$RANDOM"-"$RANDOM".txt"
TEMP_FILE1="tempFile."$RANDOM"-"$RANDOM"-"$RANDOM".txt"
TEMP_FILE2="tempFile."$RANDOM"-"$RANDOM"-"$RANDOM".txt"
TEMP_FILE3="tempFile."$RANDOM"-"$RANDOM"-"$RANDOM".txt"
PRED_FILE="prediction."$RANDOM"-"$RANDOM"-"$RANDOM".txt"
TRAIN_FILE=$RANDOMIZED_INPUT_FILE".train"
TEST_FILE=$RANDOMIZED_INPUT_FILE".test"

# cleanup code if user decides to abort the execution of this script
VAL_ONE="1"

# For weka, maximum size of memory in MB
if [ -z "${MAX_MEMORY_CLASSIFIER}" ]; then
  MAX_MEMORY_CLASSIFIER=1024 # 1 GB of maximum memory for weka
fi

###########################

# Generate train and test files
acquire_lock
# To get NUM_LINES, use command given below, not `wc -l $INPUT_FILE`
NUM_LINES=`cat $INPUT_FILE | wc -l`
release_lock

NUM_TRAIN=$(($NUM_LINES*80/100)) 
NUM_TEST=$(($NUM_LINES*20/100))

# Sanity check
TOTAL_ITEMS=$((NUM_TRAIN+NUM_TEST))
if [ "$TOTAL_ITEMS" -gt "$NUM_LINES" ]; then
  echo >&2 $PGM_NAME " - Incorrect number for training and test data"
  exit 1
fi

cat $RANDOMIZED_INPUT_FILE | head -n $NUM_TRAIN > $TRAIN_FILE
cat $RANDOMIZED_INPUT_FILE | tail -n $NUM_TEST > $TEST_FILE

###########################

# Get parameters for classifer. Example: NUM_FEATURES, NUM_CLASSES and PARAM_NAME
METAINFO_PGM=$YADMT_DIR"/"GetMetaInformationOfInputSVM
if ! NUM_FEATURES=`$METAINFO_PGM $RANDOMIZED_INPUT_FILE numFeatures` 2> /dev/null
then
  echo >&2 $PGM_NAME " - Incorrect classes in input file:" $INPUT_FILE  "Make sure you assign values for all classes (eg: you cannot have classes 1,2,3,5). If there are just 2 classes, assign values -1 and 1."
  rm $RANDOMIZED_INPUT_FILE $TRAIN_FILE $TEST_FILE &> /dev/null
  exit 1
fi
if ! NUM_CLASSES=`$METAINFO_PGM $RANDOMIZED_INPUT_FILE numClasses` 2> /dev/null
then
  echo >&2 $PGM_NAME " - Incorrect classes in input file1:" $INPUT_FILE  "Make sure you assign values for all classes (eg: you cannot have classes 1,2,3,5). If there are just 2 classes, assign values -1 and 1."
  rm $RANDOMIZED_INPUT_FILE $TRAIN_FILE $TEST_FILE &> /dev/null
  exit 1
fi

PARAM_NAME=`$PROGRAMX $INPUT_FILE`

###########################


# Assumes data in $TEMP_FILE1
function getSVMAccuracy {
  # Zero/one-error on test set: 43.73% (296 correct, 230 incorrect, 526 total)
  # Accuracy on test set: 43.73% (296 correct, 230 incorrect, 526 total)
  set -- $(cat $TEMP_FILE1 | tail -n 1)
  if [ "$4" == "set:" ]; then
    local ACCURACY_WITH_PERCENT=$5
    local ACCURACY=`echo "${ACCURACY_WITH_PERCENT%?}"`
    echo $ACCURACY
  else
    echo "-1"
  fi
}

function getWekaAccuracy {
  local NUM_LINES_TEMP=`cat $TEMP_FILE1 | wc -l`
  DONE_ACCURACY="FALSE"
  for i in `seq 1 $NUM_LINES_TEMP`
  do
    set -- $(cat $TEMP_FILE1 | head -n $i | tail -n 1)
    # Correctly Classified Instances         367               61.1667 %
    if [ "$1" == "Correctly" ]; then
      echo $5
      DONE_ACCURACY="TRUE"
      break
    fi
  done
  if [ "$DONE_ACCURACY" == "FALSE" ]; then
    echo "-1"
  fi
}


if [ "$NUM_CLASSES" == "2" ]; then
  # SVM Light script
  if [ "$CLASSIFIER" == "svm_linear" ]; then
    $YADMT_DIR"/svm_learn" -t 0 $TRAIN_FILE $MODEL_FILE > $TEMP_FILE1
    $YADMT_DIR"/svm_classify" -v 1 $TEST_FILE $MODEL_FILE $PRED_FILE > $TEMP_FILE1
    acquire_lock
    echo "" >> $RESULTS_FILE
    echo "svm_linear: Results for input file:" $INPUT_FILE "cycle:" $CYCLE_NUM "parameter:" $PARAM_NAME >> $RESULTS_FILE
    cat $TEMP_FILE1 >> $RESULTS_FILE
    echo $(getSVMAccuracy) "svm_linear" $CYCLE_NUM $PARAM_NAME >> $ACCURACY_FILE
    release_lock
  elif [ "$CLASSIFIER" == "svm_poly" ]; then
    $YADMT_DIR"/svm_learn" -t 1 -d $DEGREE $TRAIN_FILE $MODEL_FILE > $TEMP_FILE1
    $YADMT_DIR"/svm_classify" -v 1 $TEST_FILE $MODEL_FILE $PRED_FILE > $TEMP_FILE1
    acquire_lock
    echo "" >> $RESULTS_FILE
    echo "svm_poly: Results for input file:" $INPUT_FILE "cycle:" $CYCLE_NUM "parameter:" $PARAM_NAME "DEGREE:" $DEGREE >> $RESULTS_FILE
    cat $TEMP_FILE1 >> $RESULTS_FILE
    echo $(getSVMAccuracy) "svm_poly_"$DEGREE $CYCLE_NUM $PARAM_NAME >> $ACCURACY_FILE
    release_lock
  elif [ "$CLASSIFIER" == "svm_rbf" ]; then
    $YADMT_DIR"/svm_learn" -t 2 -g $GAMMA $TRAIN_FILE $MODEL_FILE > $TEMP_FILE1
    $YADMT_DIR"/svm_classify" -v 1 $TEST_FILE $MODEL_FILE $PRED_FILE > $TEMP_FILE1
    acquire_lock
    echo "" >> $RESULTS_FILE
    echo "svm_rbf: Results for input file:" $INPUT_FILE "cycle:" $CYCLE_NUM "parameter:" $PARAM_NAME "GAMMA:" $GAMMA >> $RESULTS_FILE
    cat $TEMP_FILE1 >> $RESULTS_FILE
    echo $(getSVMAccuracy) "svm_rbf_"$GAMMA $CYCLE_NUM $PARAM_NAME >> $ACCURACY_FILE
    release_lock
  fi
  rm $TEMP_FILE1 $TEMP_FILE2 $MODEL_FILE $PRED_FILE &> /dev/null
else
  # SVM Multiclass script
  TRADE_OFF=0.01
  if [ "$CLASSIFIER" == "svm_linear" ]; then
    $YADMT_DIR"/svm_multiclass_learn" -c $TRADE_OFF -t 0 $TRAIN_FILE $MODEL_FILE > $TEMP_FILE1
    $YADMT_DIR"/svm_multiclass_classify" -v 1 $TEST_FILE $MODEL_FILE $PRED_FILE > $TEMP_FILE1
    acquire_lock
    echo "" >> $RESULTS_FILE
    echo "svm_linear: (multi-class) Results for input file:" $INPUT_FILE "cycle:" $CYCLE_NUM "parameter:" $PARAM_NAME >> $RESULTS_FILE
    cat $TEMP_FILE1 >> $RESULTS_FILE
    echo $(getSVMAccuracy) "svm_linear" $CYCLE_NUM $PARAM_NAME >> $ACCURACY_FILE
    release_lock
  elif [ "$CLASSIFIER" == "svm_poly" ]; then
    $YADMT_DIR"/svm_multiclass_learn" -c $TRADE_OFF -t 1 -d $DEGREE $TRAIN_FILE $MODEL_FILE > $TEMP_FILE1
    $YADMT_DIR"/svm_multiclass_classify" -v 1 $TEST_FILE $MODEL_FILE $PRED_FILE > $TEMP_FILE1
    acquire_lock
    echo "" >> $RESULTS_FILE
    echo "svm_poly: (multi-class) Results for input file:" $INPUT_FILE "cycle:" $CYCLE_NUM "parameter:" $PARAM_NAME "DEGREE:" $DEGREE >> $RESULTS_FILE
    cat $TEMP_FILE1 >> $RESULTS_FILE
    echo $(getSVMAccuracy) "svm_poly_"$DEGREE $CYCLE_NUM $PARAM_NAME >> $ACCURACY_FILE
    release_lock
  elif [ "$CLASSIFIER" == "svm_rbf" ]; then
    $YADMT_DIR"/svm_multiclass_learn" -c $TRADE_OFF -t 2 -g $GAMMA $TRAIN_FILE $MODEL_FILE > $TEMP_FILE1
    $YADMT_DIR"/svm_multiclass_classify" -v 1 $TEST_FILE $MODEL_FILE $PRED_FILE > $TEMP_FILE1
    acquire_lock
    echo "" >> $RESULTS_FILE
    echo "svm_rbf: (multi-class) Results for input file:" $INPUT_FILE "cycle:" $CYCLE_NUM "parameter:" $PARAM_NAME "GAMMA:" $GAMMA >> $RESULTS_FILE
    cat $TEMP_FILE1 >> $RESULTS_FILE
    echo $(getSVMAccuracy) "svm_rbf_"$GAMMA $CYCLE_NUM $PARAM_NAME >> $ACCURACY_FILE
    release_lock
  fi
  rm $TEMP_FILE1 $TEMP_FILE2 $MODEL_FILE $PRED_FILE &> /dev/null
fi

if [ "$SOFTWARE" == "WEKA" ]; then
  if ! $YADMT_DIR"/GenerateArffFiles" $TRAIN_FILE $TEMP_FILE1".arff" $NUM_CLASSES $NUM_FEATURES > $TEMP_FILE3 2> $TEMP_FILE1
  then
    DETAIL_ERROR=`cat $TEMP_FILE1` # Print for debugging
    echo >&2 $PGM_NAME " - Error while generating arff files."
    rm $TEMP_FILE1 $TEMP_FILE2 $TEMP_FILE3 $TEMP_FILE1".arff" $TEMP_FILE2".arff" &> /dev/null
    exit 1
  fi
  cat $TEMP_FILE1
  if ! $YADMT_DIR"/GenerateArffFiles" $TEST_FILE $TEMP_FILE2".arff" $NUM_CLASSES $NUM_FEATURES >> $TEMP_FILE3 2> $TEMP_FILE1
  then
    DETAIL_ERROR=`cat $TEMP_FILE1` # Print for debugging
    echo >&2 $PGM_NAME " - Error while generating arff files."
    rm $TEMP_FILE1 $TEMP_FILE2 $TEMP_FILE3 $TEMP_FILE1".arff" $TEMP_FILE2".arff" &> /dev/null
    exit 1
  fi
  cat $TEMP_FILE1
  TEMP_FILE3_DATA=`cat $TEMP_FILE3`

  if [ "$CLASSIFIER" == "naive_bayes" ]; then
    if [ "$PRIOR" == "multinomial" ]; then
      WEKA_CLASS="weka.classifiers.bayes.NaiveBayesMultinomial"
    elif [ "$PRIOR" == "normal" ]; then
      WEKA_CLASS="weka.classifiers.bayes.NaiveBayesSimple"
    else
      # For kernel estimation, enable -K
      WEKA_CLASS="weka.classifiers.bayes.NaiveBayes"
    fi
  elif [ "$CLASSIFIER" == "c45_decision_tree" ]; then
    WEKA_CLASS="weka.classifiers.trees.J48"
  elif [ "$CLASSIFIER" == "linear_regression" ]; then
    WEKA_CLASS="weka.classifiers.meta.ClassificationViaRegression -W weka.classifiers.functions.LinearRegression"
  elif [ "$CLASSIFIER" == "logistic_regression" ]; then
    WEKA_CLASS="weka.classifiers.functions.Logistic"
  elif [ "$CLASSIFIER" == "random_forest" ]; then
    WEKA_CLASS="weka.classifiers.trees.RandomForest"
  fi

  if [ "$TEMP_FILE3_DATA" == "" ]; then
    if ! java "-Xmx"$MAX_MEMORY_CLASSIFIER"m" -cp $YADMT_DIR"/weka.jar" $WEKA_CLASS -t $TEMP_FILE1".arff" -T $TEMP_FILE2".arff" > $TEMP_FILE3 2>>  $RESULTS_FILE
    then
      echo >&2 $PGM_NAME " - Error while executing weka "$CLASSIFIER" (See " $RESULTS_FILE " for detailed description of error).\n"
      rm $TEMP_FILE1 $TEMP_FILE2 $TEMP_FILE3 $TEMP_FILE1".arff" $TEMP_FILE2".arff" &> /dev/null
      exit 1
    fi
    acquire_lock
    cat $RESULTS_FILE
    exit
    echo "" >> $RESULTS_FILE
    echo $CLASSIFIER": Results for input file:" $INPUT_FILE "cycle:" $CYCLE_NUM "parameter:" $PARAM_NAME >> $RESULTS_FILE
    cat $TEMP_FILE3 >> $RESULTS_FILE
    # Note the positional parameters are unset, so don't use $PGM_NAME, $1, .. after this
    TAIL_NUM=$(($NUM_CLASSES+16))
    cat $TEMP_FILE3 | tail -n $TAIL_NUM | head -n 10 > $TEMP_FILE1
    echo $(getWekaAccuracy) $CLASSIFIER $CYCLE_NUM $PARAM_NAME >> $ACCURACY_FILE
    release_lock
    rm $TEMP_FILE1 $TEMP_FILE2 $TEMP_FILE3 $TEMP_FILE1".arff" $TEMP_FILE2".arff"  &> /dev/null
  else
    echo >&2 $PGM_NAME " - Error while generating arff files.\n"
    rm $TEMP_FILE1 $TEMP_FILE2 $TEMP_FILE3 $TEMP_FILE1".arff" $TEMP_FILE2".arff" &> /dev/null
    exit 1
  fi
  
fi

#done

