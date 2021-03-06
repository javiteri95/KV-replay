inputTrace=$1
TIF=$2
outputTrace=$3
flag=${4:-true}

size=$( wc -l $inputTrace | cut -d" " -f1 )
perfectSize=$(( size / TIF ))
bool=false

if [ "$flag" = true ]
then
	firstTimeStampRegister=$(head -n 1 $inputTrace)
	lastTimeStampRegister=$(tail -1 $inputTrace)
	firstTimeStamp=$( echo "$firstTimeStampRegister" | cut -d"," -f3 )
	lastTimeStamp=$( echo "$lastTimeStampRegister" | cut -d"," -f3 )

	perfectSize=$( echo "scale=9; ($lastTimeStamp - $firstTimeStamp) / $TIF " | bc )
	declare -A table=()


	for ((i=0 ; i <$TIF ; i++ ))
	do
		particularRegister=$( awk -F, -v "iawk=$i" -v "perfectSizeAwk=$perfectSize" -v "firstTimeStampAwk=$firstTimeStamp" '$3 >= ( firstTimeStampAwk + ( iawk * perfectSizeAwk)) { print NR  ; exit }' $inputTrace )
		table[$i]=$particularRegister
	done
	table[$TIF]=$((size +1 ))
fi



for (( i=0 ; i<$TIF ; i++ ))
do
	if [ "$flag" = true ]
	then
		initial=${table[$i]}
		iplus1=$(( i +1))
		final=$(( ${table[$iplus1]} - 1))
	else
		initial=$(( (i * $perfectSize) + 1 ))
		final=$(( (i + 1) * perfectSize ))
	fi

	sed -n "$initial, $final p" < $inputTrace > $inputTrace-temporalSubtrace-$i
	correctValue=$(head -n 1 $inputTrace-temporalSubtrace-$i)
	firstCommand=$( echo "$correctValue" | cut -d"," -f1 )
	firstKey=$( echo "$correctValue" | cut -d"," -f2 )
	firstTimeStamp=$( echo "$correctValue" | cut -d"," -f3 )
	firstSize=$( echo "$correctValue" | cut -d"," -f4 )
	if [ -z "$firstSize" ];then
		echo $firstCommand,$firstKey,0 > $inputTrace-temporalSubtrace-awk-$i 
	else
		bool=true
		echo $firstCommand,$firstKey,0,$firstSize > $inputTrace-temporalSubtrace-awk-$i
	fi
	awk -F , -v OFS=, 'BEGIN {CONVFMT = "%.9f"} ;  $3 -= "'"$firstTimeStamp"'" ' < $inputTrace-temporalSubtrace-$i >> $inputTrace-temporalSubtrace-awk-$i

	rm $inputTrace-temporalSubtrace-$i

	iput=0$i
	if [ $i -gt 9 ]
	then
		iput=$i
	fi


	if [ $bool = false ]
	then
		awk -v OFS="," -F"," '{print $1,"'"$iput"'"$2,$3}' $inputTrace-temporalSubtrace-awk-$i > $inputTrace-temporalSubtrace-awk-$i-two
	else
		awk -v OFS="," -F"," '{print $1,"'"$iput"'"$2,$3,$4}' $inputTrace-temporalSubtrace-awk-$i > $inputTrace-temporalSubtrace-awk-$i-two
	fi

	rm $inputTrace-temporalSubtrace-awk-$i

done


for ((i=1 ; i<$TIF ; i++ ))
do
	j=$(( i - 1 ))
	sort -t, -k3 -n -m $inputTrace-temporalSubtrace-awk-$j-two $inputTrace-temporalSubtrace-awk-$i-two > $inputTrace-temporalSubtrace-awk-temp-two 
	mv $inputTrace-temporalSubtrace-awk-temp-two $inputTrace-temporalSubtrace-awk-$i-two
done

for ((i=0 ; i<$TIF ; i++ ))
do
	TIFminus1=$(( TIF -1 ))
	if [ $TIFminus1 -eq $i ]; then
		mv $inputTrace-temporalSubtrace-awk-$i-two $outputTrace
	else
		rm $inputTrace-temporalSubtrace-awk-$i-two
	fi
done

