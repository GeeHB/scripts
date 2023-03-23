#!/bin/bash

tableau=(("un" "deux "trois") ("onze" "douze" "treize"))

for i in `seq 1 2`
do
	let "index=$i-1"
	echo ${tableau[$index]}
done
