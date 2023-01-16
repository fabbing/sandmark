#!/bin/bash

CONFIG_SWITCH_NAME=$1
if [[ $BUILD_BENCH_TARGET =~ multibench* && $CONFIG_SWITCH_NAME =~ 4.14* ]]; then
    echo "Not running parallel tests for $CONFIG_SWITCH_NAME";
    exit 1;
fi
