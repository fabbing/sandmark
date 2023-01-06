#!/bin/bash

CONFIG_SWITCH_NAME=$1
RUN_CONFIG_JSON=$2

CONFIG_VARIANT=$(echo $CONFIG_SWITCH_NAME | grep -oE '([0-9]|\.)*')

case "$CONFIG_VARIANT" in
    *5.1.0*)
        echo "Filtering some benchmarks for OCaml 5.1.0";
        jq '{wrappers : .wrappers, benchmarks: [.benchmarks | .[] | select( .name as $name | ["irmin_replay", "cpdf", "frama-c", "js_of_ocaml", "graph500_kernel1", "graph500_kernel1_multicore"] | index($name) | not )]}' $RUN_CONFIG_JSON >$RUN_CONFIG_JSON.tmp;
        mv $RUN_CONFIG_JSON.tmp $RUN_CONFIG_JSON;
        echo "(data_only_dirs irmin cpdf frama-c)" >benchmarks/dune;;
    *5.0.1*)
        echo "Filtering some benchmarks for OCaml 5.0.1";
        jq '{wrappers : .wrappers, benchmarks: [.benchmarks | .[] | select( .name as $name | ["irmin_replay", "cpdf", "frama-c", "js_of_ocaml", "graph500_kernel1", "graph500_kernel1_multicore"] | index($name) | not )]}' $RUN_CONFIG_JSON >$RUN_CONFIG_JSON.tmp;
        mv $RUN_CONFIG_JSON.tmp $RUN_CONFIG_JSON;
        echo "(data_only_dirs irmin cpdf frama-c)" >benchmarks/dune;;
    *4.14*)
        echo "Filtering some benchmarks for OCaml 4.14";
        jq '{wrappers : .wrappers, benchmarks: [.benchmarks | .[] | select( .name as $name | ["irmin_replay", "cpdf", "frama-c", "js_of_ocaml", "graph500_kernel1", "graph500_kernel1_multicore"] | index($name) | not )]}' $RUN_CONFIG_JSON >$RUN_CONFIG_JSON.tmp;
        mv $RUN_CONFIG_JSON.tmp $RUN_CONFIG_JSON;
        echo "(data_only_dirs irmin cpdf frama-c)" >benchmarks/dune;;
    *)
        echo "Not filtering benchmarks for OCaml $CONFIG_SWITCH_NAME";;
esac
