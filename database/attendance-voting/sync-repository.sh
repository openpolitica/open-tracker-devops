#!/bin/bash
#Init directory 
INIT_DIR=${PWD}

#Set environment variables
source ${INIT_DIR}/load-credentials.sh

./attendance-voting/prepare.sh
