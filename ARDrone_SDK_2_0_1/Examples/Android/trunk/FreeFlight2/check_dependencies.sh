#!/bin/sh

## Author : stephane.piskorski@parrot.com
## Date   : 19th,Oct. 2010


check()
{
	if [ `cat ./temporary_file | grep "ii[\ ]*$1\ " | wc -l` -eq 0 ] ; then
		echo " $1";
	fi
}

verify()
{
		packages="$packages$(check $1)";
}

verifyEither()
{
	FOUND="no"
	for pack in $*; do
		locPack=$(check $pack)
		if [ -z $locPack ]; then
			FOUND="yes"
		fi
	done
	if [ "$FOUND" = "no" ]; then
		packages="$packages $1"
	fi
}


packages="";

if [ `which uname` ] ; then
	if [ `uname -a | grep Ubuntu | wc -l` ] ; then

		echo "\033[31mChecking required Ubuntu packages ...\033[0m";

		if [ ! -e ./temporary_file ] ; then   # check that the temp file does not exist

			dpkg -l > ./temporary_file;

			#To build the android app
			verifyEither "openjdk-6-jdk" "sun-java6-jdk";
			verify "ant";
			verify "rpl";

			if [ "$packages" != "" ] ; then
				echo "You should install the following packages to compile the Mykonos project with Ubuntu:\n $packages";
				echo "Do you want to install them now [y/n] ?";
				read user_answer ;
				if [ "$user_answer" = "y" ]; then
					sudo apt-get install $packages;
				fi
			else
				echo "ok.";
			fi

			rm ./temporary_file;
		fi
	fi
fi

