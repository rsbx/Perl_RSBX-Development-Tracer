#!/bin/bash

cat /dev/null $(find "$@" -type f -print |egrep '\.(pm|pod)$' | sort) | awk -f podcat.awk
