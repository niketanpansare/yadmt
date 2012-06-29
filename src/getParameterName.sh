#!/bin/bash
# ./getParameterName fileName
FILE_FULL_PATH=$1
FILE_NAME="${FILE_FULL_PATH##*/}"
JUST_NAME="${FILE_NAME%%.*}"
echo $JUST_NAME 
