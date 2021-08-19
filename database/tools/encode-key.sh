#!/bin/bash
jq -r '. | @base64 ' $1
