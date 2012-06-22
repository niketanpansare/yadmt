#!/bin/bash

cd ~
if ! ./svm_learn -? &> /dev/null
then
	echo "Installing SVM Light"
	mkdir ~/svm_light/
	cd ~/svm_light/
	wget http://download.joachims.org/svm_light/current/svm_light.tar.gz
	tar -xzf svm_light.tar.gz
	make
	cp svm_learn ~/yadmt/
	cp svm_classify ~/yadmt/
	cd ..
	rm -rf ~/svm_light/
fi

if ! ./svm_multiclass_learn -? &> /dev/null
then 
	echo "Installing SVM Multiclass"
	mkdir ~/svm_multiclass/
	cd ~/svm_multiclass/
	wget http://download.joachims.org/svm_multiclass/current/svm_multiclass.tar.gz
	tar -xzf svm_multiclass.tar.gz
	make
	cp svm_multiclass_learn ~/yadmt/
	cp svm_multiclass_classify ~/yadmt/
    cd ..
	rm -rf ~/svm_multiclass/
fi

if ! java -version &> /dev/null
then
	echo "Java not installed"
fi

if [ ! -e "./weka.jar" ]; 
then
	echo "Installing Weka"
	mkdir ~/weka/
	cd ~/weka/
	wget http://prdownloads.sourceforge.net/weka/weka-3-6-7.zip
	unzip weka-3-6-7.zip
	cp weka-3-6-7/weka.jar ~/yadmt/
	cd ..
	rm -rf ~/weka/
fi

# install g++
#sudo apt-get update
#sudo apt-get install build-essential

if [ ! -d "~/gnu-parallel" ];
then
	if ! parallel --help &> /dev/null
	then
		echo "Installing GNU Parallel"
		cd ~
		wget http://ftp.gnu.org/gnu/parallel/parallel-20120522.tar.bz2
		tar -xjf parallel-20120522.tar.bz2
		mv parallel-20120522 gnu-parallel
		cd gnu-parallel 
		./configure
		make
		sudo make install
	fi
fi
