#!/bin/bash

#  runClassifier.sh INPUT_CONFIGURATION
#  where INPUT_CONFIGURATION to be of format "configFile*inputFile*cycleNum*classifier*optional_params" without any spaces
#  Valid values for SVM_TYPE are 
#  svm_linear (linear), svm_poly (polynomial where * = 2, 3, 4, ...) 
#  svm_rbf (Radial Basis)
#
#  Created by Niketan Pansare

# Has to be of format "configFile,inputFile,cycleNum,classifier,optional_params" without any spaces
INPUT_CONFIGURATION=$1
PGM_NAME=$0

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
fi

NUM_LINES=`cat $INPUT_FILE | wc -l`
NUM_TRAIN=$(($NUM_LINES*80/100)) 
NUM_TEST=$(($NUM_LINES*20/100))

# Sanity check
TOTAL_ITEMS=$((NUM_TRAIN+NUM_TEST))
if [ "$TOTAL_ITEMS" -gt "$NUM_LINES" ]; then
  echo >&2 $PGM_NAME " - Incorrect number for training and test data"
  exit 1
fi

#Read variables: MAX_MEMORY_CLASSIFIER, ACCURACY_FILE, RESULTS_FILE
source "./"$CONFIG_FILE

if [ -z "${MAX_MEMORY_CLASSIFIER}" ]; then
  MAX_MEMORY_CLASSIFIER=1000
fi

###########################
# Generate train and test files
RANDOMIZED_INPUT_FILE="input-"$RANDOM"-"$RANDOM"-"$RANDOM".txt"
if ! sort -R $INPUT_FILE > $RANDOMIZED_INPUT_FILE 2> /dev/null
then
  echo >&2 $PGM_NAME " - Your system doesnot support \"sort -R\" option required to randomize the input file."
  exit 1
fi

TRAIN_FILE=$RANDOMIZED_INPUT_FILE".train"
TEST_FILE=$RANDOMIZED_INPUT_FILE".test"
cat $RANDOMIZED_INPUT_FILE | head -n $NUM_TRAIN > $TRAIN_FILE
cat $RANDOMIZED_INPUT_FILE | tail -n $NUM_TEST > $TEST_FILE
###########################

if ! NUM_FEATURES=`./GetMetaInformationOfInputSVM $RANDOMIZED_INPUT_FILE numFeatures` 2> /dev/null
then
  echo >&2 $PGM_NAME " - Incorrect classes in input file:" $INPUT_FILE  "Make sure you assign values for all classes (eg: you cannot have classes 1,2,3,5). If there are just 2 classes, assign values -1 and 1."
  rm $RANDOMIZED_INPUT_FILE $TRAIN_FILE $TEST_FILE &> /dev/null
  exit 1
fi
if ! NUM_CLASSES=`./GetMetaInformationOfInputSVM $RANDOMIZED_INPUT_FILE numClasses` 2> /dev/null
then
  echo >&2 $PGM_NAME " - Incorrect classes in input file1:" $INPUT_FILE  "Make sure you assign values for all classes (eg: you cannot have classes 1,2,3,5). If there are just 2 classes, assign values -1 and 1."
  rm $RANDOMIZED_INPUT_FILE $TRAIN_FILE $TEST_FILE &> /dev/null
  exit 1
fi
PARAM_NAME=`./getParameterName $RANDOMIZED_INPUT_FILE`

SVM_2CLASS_PATTERN='s/Accuracy on test set: \([0-9]*.[0-9]*\)% ([0-9]* correct, [0-9]* incorrect, [0-9]* total)\.*/'
SVM_NCLASS_PATTERN='s/Zero\/one-error on test set: \([0-9]*.[0-9]*\)% ([0-9]* correct, [0-9]* incorrect, [0-9]* total)\.*/'

###########################
# Locking mechanism to avoid race conditions when parallel runs
LOCKDIR="/tmp/yadmt.lock"
function acquire_lock {
  LOCK_ACQUIRED="FALSE"
  while [ "$LOCK_ACQUIRED" == "FALSE" ]; 
  do
    if ! mkdir "$LOCKDIR" 2> /dev/null
    then
      sleep 1s
    else
      LOCK_ACQUIRED="TRUE"
    fi
  done
}
function release_lock {
  rm -r "$LOCKDIR" &> /dev/null
}
###########################


MODEL_FILE="model."$RANDOM"-"$RANDOM"-"$RANDOM".txt"
TEMP_FILE1="tempFile."$RANDOM"-"$RANDOM"-"$RANDOM".txt"
TEMP_FILE2="tempFile."$RANDOM"-"$RANDOM"-"$RANDOM".txt"
TEMP_FILE3="tempFile."$RANDOM"-"$RANDOM"-"$RANDOM".txt"
PRED_FILE="prediction."$RANDOM"-"$RANDOM"-"$RANDOM".txt"

if [ "$NUM_CLASSES" == "2" ]; then
  # SVM Light script
  if [ "$CLASSIFIER" == "svm_linear" ]; then
    ./svm_learn -t 0 $TRAIN_FILE $MODEL_FILE > $TEMP_FILE1
    ./svm_classify -v 1 $TEST_FILE $MODEL_FILE $PRED_FILE > $TEMP_FILE1
    acquire_lock
    echo "" >> $RESULTS_FILE
    echo "svm_linear: Results for input file:" $INPUT_FILE "cycle:" $CYCLE_NUM "parameter:" $PARAM_NAME >> $RESULTS_FILE
    cat $TEMP_FILE1 >> $RESULTS_FILE
    sed '/^Reading model/d' $TEMP_FILE1 > $TEMP_FILE2
    sed '/^Precision/d' $TEMP_FILE2 > $TEMP_FILE1
    sed "$SVM_2CLASS_PATTERN$CYCLE_NUM svm_linear 0 "$PARAM_NAME" \1/g" $TEMP_FILE1 >> $ACCURACY_FILE
    release_lock
  elif [ "$CLASSIFIER" == "svm_poly" ]; then
    ./svm_learn -t 1 -d $DEGREE $TRAIN_FILE $MODEL_FILE > $TEMP_FILE1
    ./svm_classify -v 1 $TEST_FILE $MODEL_FILE $PRED_FILE > $TEMP_FILE1
    acquire_lock
    echo "" >> $RESULTS_FILE
    echo "svm_poly: Results for input file:" $INPUT_FILE "cycle:" $CYCLE_NUM "parameter:" $PARAM_NAME "DEGREE:" $DEGREE >> $RESULTS_FILE
    cat $TEMP_FILE1 >> $RESULTS_FILE
    sed '/^Reading model/d' $TEMP_FILE1 > $TEMP_FILE2
    sed '/^Precision/d' $TEMP_FILE2 > $TEMP_FILE1
    sed "$SVM_2CLASS_PATTERN$CYCLE_NUM svm_poly "$DEGREE" "$PARAM_NAME" \1/g" $TEMP_FILE1 >> $ACCURACY_FILE
    release_lock
  elif [ "$CLASSIFIER" == "svm_rbf" ]; then
    ./svm_learn -t 2 -g $GAMMA $TRAIN_FILE $MODEL_FILE > $TEMP_FILE1
    ./svm_classify -v 1 $TEST_FILE $MODEL_FILE $PRED_FILE > $TEMP_FILE1
    acquire_lock
    echo "" >> $RESULTS_FILE
    echo "svm_rbf: Results for input file:" $INPUT_FILE "cycle:" $CYCLE_NUM "parameter:" $PARAM_NAME "GAMMA:" $GAMMA >> $RESULTS_FILE
    cat $TEMP_FILE1 >> $RESULTS_FILE
    sed '/^Reading model/d' $TEMP_FILE1 > $TEMP_FILE2
    sed '/^Precision/d' $TEMP_FILE2 > $TEMP_FILE1
    sed "$SVM_2CLASS_PATTERN$CYCLE_NUM svm_rbf "$GAMMA" "$PARAM_NAME" \1/g" $TEMP_FILE1 >> $ACCURACY_FILE
    release_lock
  fi
  rm $TEMP_FILE1 $TEMP_FILE2 $MODEL_FILE $PRED_FILE &> /dev/null
else
  # SVM Multiclass script
  TRADE_OFF=0.01
  if [ "$CLASSIFIER" == "svm_linear" ]; then
    ./svm_multiclass_learn -c $TRADE_OFF -t 0 $TRAIN_FILE $MODEL_FILE > $TEMP_FILE1
    ./svm_multiclass_classify -v 1 $TEST_FILE $MODEL_FILE $PRED_FILE > $TEMP_FILE1
    acquire_lock
    echo "" >> $RESULTS_FILE
    echo "svm_linear: (multi-class) Results for input file:" $INPUT_FILE "cycle:" $CYCLE_NUM "parameter:" $PARAM_NAME >> $RESULTS_FILE
    cat $TEMP_FILE1 >> $RESULTS_FILE
    sed '/^Reading model/d' $TEMP_FILE1 > $TEMP_FILE2
    sed '/^Precision/d' $TEMP_FILE2 > $TEMP_FILE1
    sed '/^Reading test examples/d' $TEMP_FILE1 > $TEMP_FILE2
    sed '/^Classifying test examples/d' $TEMP_FILE2 > $TEMP_FILE1
    sed '/^Runtime/d' $TEMP_FILE1 > $TEMP_FILE2
    sed '/^Average loss on test set/d' $TEMP_FILE2 > $TEMP_FILE1
    sed "$SVM_NCLASS_PATTERN$CYCLE_NUM svm_linear 0 "$PARAM_NAME" \1/g" $TEMP_FILE1 >> $ACCURACY_FILE
    release_lock
  elif [ "$CLASSIFIER" == "svm_poly" ]; then
    ./svm_multiclass_learn -c $TRADE_OFF -t 1 -d $DEGREE $TRAIN_FILE $MODEL_FILE > $TEMP_FILE1
    ./svm_multiclass_classify -v 1 $TEST_FILE $MODEL_FILE $PRED_FILE > $TEMP_FILE1
    acquire_lock
    echo "" >> $RESULTS_FILE
    echo "svm_poly: (multi-class) Results for input file:" $INPUT_FILE "cycle:" $CYCLE_NUM "parameter:" $PARAM_NAME "DEGREE:" $DEGREE >> $RESULTS_FILE
    cat $TEMP_FILE1 >> $RESULTS_FILE
    sed '/^Reading model/d' $TEMP_FILE1 > $TEMP_FILE2
    sed '/^Precision/d' $TEMP_FILE2 > $TEMP_FILE1
    sed '/^Reading test examples/d' $TEMP_FILE1 > $TEMP_FILE2
    sed '/^Classifying test examples/d' $TEMP_FILE2 > $TEMP_FILE1
    sed '/^Runtime/d' $TEMP_FILE1 > $TEMP_FILE2
    sed '/^Average loss on test set/d' $TEMP_FILE2 > $TEMP_FILE1
    sed "$SVM_NCLASS_PATTERN$CYCLE_NUM svm_poly "$DEGREE" "$PARAM_NAME" \1/g" $TEMP_FILE1 >> $ACCURACY_FILE
    release_lock
  elif [ "$CLASSIFIER" == "svm_rbf" ]; then
    ./svm_multiclass_learn -c $TRADE_OFF -t 2 -g $GAMMA $TRAIN_FILE $MODEL_FILE > $TEMP_FILE1
    ./svm_multiclass_classify -v 1 $TEST_FILE $MODEL_FILE $PRED_FILE > $TEMP_FILE1
    acquire_lock
    echo "" >> $RESULTS_FILE
    echo "svm_rbf: (multi-class) Results for input file:" $INPUT_FILE "cycle:" $CYCLE_NUM "parameter:" $PARAM_NAME "DEGREE:" $DEGREE >> $RESULTS_FILE
    cat $TEMP_FILE1 >> $RESULTS_FILE
    sed '/^Reading model/d' $TEMP_FILE1 > $TEMP_FILE2
    sed '/^Precision/d' $TEMP_FILE2 > $TEMP_FILE1
    sed '/^Reading test examples/d' $TEMP_FILE1 > $TEMP_FILE2
    sed '/^Classifying test examples/d' $TEMP_FILE2 > $TEMP_FILE1
    sed '/^Runtime/d' $TEMP_FILE1 > $TEMP_FILE2
    sed '/^Average loss on test set/d' $TEMP_FILE2 > $TEMP_FILE1
    sed "$SVM_NCLASS_PATTERN$CYCLE_NUM svm_rbf "$GAMMA" "$PARAM_NAME" \1/g" $TEMP_FILE1 >> $ACCURACY_FILE
    release_lock
  fi
  rm $TEMP_FILE1 $TEMP_FILE2 $MODEL_FILE $PRED_FILE &> /dev/null
fi

if [ "$CLASSIFIER" == "naive_bayes" ]; then
  if ! ./GenerateArffFiles $TRAIN_FILE $TEMP_FILE1".arff" > $TEMP_FILE3 2> $TEMP_FILE1
  then
    DETAIL_ERROR=`cat $TEMP_FILE1` # Print for debugging
    echo >&2 $PGM_NAME " - Error while generating arff files."
    rm $TEMP_FILE1 $TEMP_FILE2 $TEMP_FILE3 $TEMP_FILE1".arff" $TEMP_FILE2".arff" &> /dev/null
    exit 1
  fi
  if ! ./GenerateArffFiles $TEST_FILE $TEMP_FILE2".arff" >> $TEMP_FILE3 2> $TEMP_FILE1
  then
    DETAIL_ERROR=`cat $TEMP_FILE1` # Print for debugging
    echo >&2 $PGM_NAME " - Error while generating arff files."
    rm $TEMP_FILE1 $TEMP_FILE2 $TEMP_FILE3 $TEMP_FILE1".arff" $TEMP_FILE2".arff" &> /dev/null
    exit 1
  fi
  TEMP_FILE3_DATA=`cat $TEMP_FILE3`
  if [ "$TEMP_FILE3_DATA" == "" ]; then
    if ! java "-Xmx"$MAX_MEMORY_CLASSIFIER"m" -cp ./weka.jar weka.classifiers.bayes.NaiveBayes -t $TEMP_FILE1".arff" -T $TEMP_FILE2".arff" > $TEMP_FILE3 2>>  $RESULTS_FILE
    then
      echo >&2 $PGM_NAME " - Error while executing weka naive bayes (See " $RESULTS_FILE " for detailed description of error).\n"
      rm $TEMP_FILE1 $TEMP_FILE2 $TEMP_FILE3 $TEMP_FILE1".arff" $TEMP_FILE2".arff" &> /dev/null
      exit 1
    fi
    acquire_lock
    echo "" >> $RESULTS_FILE
    echo "naive_bayes: Results for input file:" $INPUT_FILE "cycle:" $CYCLE_NUM "parameter:" $PARAM_NAME >> $RESULTS_FILE
    cat $TEMP_FILE3 >> $RESULTS_FILE
    # Note the positional parameters are unset, so don't use $PGM_NAME, $1, .. after this
    TAIL_NUM=$(($NUM_CLASSES+16))
    set -- $(cat $TEMP_FILE3 | tail -n $TAIL_NUM | head -n 1)
    # Example: now, $1="Correctly", $2="Classified", $3="Instances", $4="417", $5="79.1271"
    echo $CYCLE_NUM "naive_bayes" "0" $PARAM_NAME $5 >> $ACCURACY_FILE
    release_lock
    rm $TEMP_FILE1 $TEMP_FILE2 $TEMP_FILE3 $TEMP_FILE1".arff" $TEMP_FILE2".arff"  &> /dev/null
  else
    echo >&2 $PGM_NAME " - Error while generating arff files.\n"
    rm $TEMP_FILE1 $TEMP_FILE2 $TEMP_FILE3 $TEMP_FILE1".arff" $TEMP_FILE2".arff" &> /dev/null
    exit 1
  fi
  
fi

rm $RANDOMIZED_INPUT_FILE $TRAIN_FILE $TEST_FILE $TEMP_FILE1 $TEMP_FILE2 $MODEL_FILE $PRED_FILE &> /dev/null

