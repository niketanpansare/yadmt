#!/bin/bash
# ./getParameterName fileName
FILENAME_WITH_EXT=$(basename "$1")
JUST_NAME="${FILENAME_WITH_EXT%.*}"

# Example: ./getParameterName /home/myUserName/data/my_file.txt
# should return "my_file"
# Any "/" or other special characters messes with sed
echo $JUST_NAME 
