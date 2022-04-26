#!/bin/bash

function reportError() {
  if [ $1 -ne 0 ]; then
    echo "$2"
    exit $1
  fi
}

function reportErrorFallback() {
  if [ $1 -ne 0 ]; then
    echo "$2"
    "${@:3}"
    exit $1
  fi
}

function checkPreviousCommand(){
  reportError $? "$1"
}

