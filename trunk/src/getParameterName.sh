#!/bin/bash
# ./getParameterName fileName
FILE_FULL_PATH=$1
JUST_NAME="${FILE_FULL_PATH%%.*}"
echo $JUST_NAME 
