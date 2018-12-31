#!/bin/bash

# collects mempool txs and sorts them into buckets depending on their fees

MEASURMENT=mempool

CUSTOM_FILTERS="def addBucket(f): f | map( ( .fee * 100000000 ) /  .size  | floor )"

BUCKET_LABELS=(
  "0-1" "1-2" "2-3" "3-4" "4-5" "5-6" "6-7" "7-8" "8-10"
  "10-12" "12-14" "14-17" "17-20" "20-25"
  "25-30" "30-40" "40-50" "50-60" "60-70" "70-80"
  "80-100" "100-120" "120-140" "140-170" "170-200" "200-250"
  "250-300" "300-400" "400-500" "500-600" "600-700" "700-800" "800-1000"
  "1000-1200" "1200-1400" "1400-1700" "1700-2000" "2000+"
)
BUCKET_MINIMA=(
  0 1 2 3 4 5 6 7 8
  10 12 14 17 20 25
  30 40 50 60 70 80
  100 120 140 170 200 250
  300 400 500 600 700 800
  1000 1200 1400 1700 2000
)
BUCKET_LAST_INDEX=$((${#BUCKET_MINIMA[@]}-1))
BUCKET_DATA=(
  0 0 0 0 0 0
  0 0 0 0 0 0
  0 0 0 0 0 0
  0 0 0 0 0 0
  0 0 0 0 0 0
  0 0 0 0 0 0
  0 0
)

SATOSHI_COUNT=$(/usr/bin/bitcoin-cli getrawmempool true | jq "$CUSTOM_FILTERS; . | addBucket(.) | group_by(.)[]|sort_by(.)|(length|tostring)+\":\"+(.[0]|tostring)" | tr -d \")

for d in $SATOSHI_COUNT
do
  OLD_IFS="$IFS"
  IFS=":"
  COUNT_SATOSHIS=( $d )
  IFS="$OLD_IFS"

  for i in $(seq 0 $BUCKET_LAST_INDEX)
  do
    index=$(( $BUCKET_LAST_INDEX - $i ))
    if [[ ${BUCKET_MINIMA[$index]} -le ${COUNT_SATOSHIS[1]} ]]; then
        BUCKET_DATA[$index]=$(( ${BUCKET_DATA[$index]} + ${COUNT_SATOSHIS[0]} ))
        break
    fi
  done

done

echo -n "${MEASURMENT} "
for i in $(seq 0 $BUCKET_LAST_INDEX )
do
  sortBy=$(printf "%02d" $i)
  echo -n "b[${sortBy}][${BUCKET_LABELS[$i]}]=${BUCKET_DATA[$i]}i"
  if [[ $i -lt $BUCKET_LAST_INDEX ]]; then
    echo -n ","
  fi
done
echo ""