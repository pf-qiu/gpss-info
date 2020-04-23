#!/bin/bash

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 path_of_server1_cert"
  exit 1
fi

if ! [ -e "$1" ]; then
  echo "Error: $1 not found"
  exit 1
fi
if ! [ -d "$1" ]; then
  echo "Error: $1 not a directory"
  exit 1
fi

if [[ -z "${MASTER_DATA_DIRECTORY}" ]]; then
  echo "Error: Environment Variable MASTER_DATA_DIRECTORY not set!"
  exit 1
fi

for dir in $(find $MASTER_DATA_DIRECTORY/../../.. -name pg_hba.conf)
   do
   if [ -d $(dirname $dir)/gpfdists ]; then
       rm -rf $(dirname $dir)/gpfdists/*
       cp -rf $1/* $(dirname $dir)/gpfdists
       cat $(dirname $dir)/gpfdists/interca.crt >> $(dirname $dir)/gpfdists/root.crt
   fi
done
