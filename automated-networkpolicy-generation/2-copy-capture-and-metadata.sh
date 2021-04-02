#!/bin/bash

source env.sh

set -eu

PODS=$(kubectl get pods -n $TARGET_NS -o name --field-selector status.phase!=Terminating | cut -d/ -f2)

i=0

until [ $i -gt $TEST_DURATION_IN_SECONDS ]
do
   echo "Going to wait for $((TEST_DURATION_IN_SECONDS-i)) seconds so that application traffic can be generated..."
  ((i=i+1))
  sleep 1
done

mkdir -p .tmp
for p in $PODS
do
   FILE="${p}.pcap"
   STATUS=$(kubectl get pod ${p} -o jsonpath='{.status.phase}' -n $TARGET_NS --ignore-not-found)
   if [[ $STATUS != "Running" ]] ;
   then
      echo "Pod ${p} is not in 'Running' state"
   else
      kubectl -n $TARGET_NS cp $p:/tmp/tcpdump.pcap ".tmp/${FILE}" -c tcpdump  
   fi
   
done

./create-capture-metadata.py $TARGET_NS ${PODS}
