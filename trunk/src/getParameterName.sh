#!/bin/bash
# ./getParameterName fileName
FILENAME_WITH_EXT=$(basename "$1")
JUST_NAME="${FILENAME_WITH_EXT%.*}"
echo $JUST_NAME 
