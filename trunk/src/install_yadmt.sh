#!/bin/bash

if ! java -version &> /dev/null
then
  echo "Installing Java"
  sudo apt-get install openjdk-7-jdk
fi
# install g++
sudo apt-get update
sudo apt-get install build-essential
sudo apt-get install unzip
sudo apt-get update

USER_HOME=$(eval echo ~${SUDO_USER})
YADMT_DIR=$USER_HOME"/yadmt"

echo "Installing yadmt files"
mkdir $YADMT_DIR 
chmod +x *.sh
cp yadmt.sh $YADMT_DIR
cp getParameterName.sh $YADMT_DIR"/getParameterName"
cp runClassifier.sh $YADMT_DIR"/runClassifier" 
g++ GenerateArffFiles.cpp Assert.cpp -o $YADMT_DIR"/GenerateArffFiles"
g++ GetMetaInformationOfInputSVM.cpp Assert.cpp -o $YADMT_DIR"/GetMetaInformationOfInputSVM"

echo "Installing SVM Light"
cd $YADMT_DIR
mkdir svm_light 
cd svm_light/
wget http://download.joachims.org/svm_light/current/svm_light_linux.tar.gz
tar -xzf svm_light_linux.tar.gz
cp svm_learn $YADMT_DIR
cp svm_classify $YADMT_DIR
cd $YADMT_DIR
rm -rf $YADMT_DIR"/svm_light/"
if ! ./svm_learn --help &> /dev/null
then
  sudo apt-get install ia32-libs
fi

echo "Installing SVM Multiclass"
cd $YADMT_DIR
mkdir svm_multiclass 
cd svm_multiclass/
http://download.joachims.org/svm_multiclass/current/svm_multiclass_linux.tar.gz
tar -xzf svm_multiclass_linux.tar.gz
make
cp svm_multiclass_learn $YADMT_DIR
cp svm_multiclass_classify $YADMT_DIR
cd $YADMT_DIR
rm -rf $YADMT_DIR"/svm_multiclass/"

echo "Installing Weka"
cd $YADMT_DIR
mkdir weka 
cd weka
wget "http://prdownloads.sourceforge.net/weka/weka-3-6-7.zip"
unzip "weka-3-6-7.zip"
cp "weka-3-6-7/weka.jar" $YADMT_DIR
cd $YADMT_DIR
rm -rf $YADMT_DIR"/weka/"


if ! parallel --help &> /dev/null
then
  echo "Installing GNU Parallel"
  cd $YADMT_DIR  
  wget "http://ftp.gnu.org/gnu/parallel/parallel-20120522.tar.bz2"
  tar -xjf "parallel-20120522.tar.bz2"
  rm "parallel-20120522.tar.bz2"
  mv parallel-20120522 gnu-parallel
  cd gnu-parallel 
  ./configure
  make
  sudo make install
  cd $YADMT_DIR
  rm -rf $YADMT_DIR"/gnu-parallel/"
fi