#!/bin/bash

CONFIG_SWITCH_NAME=$1
RUN_CONFIG_JSON=$2

echo "$CONFIG_SWITCH_NAME" | grep -qE '.*(4\.14|5\.0\.1|5\.1\.0).*'
if [ $? = 0 ]; then
    # Recognized compiler variant (4.14, 5.0.1, 5.1.0)
    echo "Filtering some benchmarks for OCaml $CONFIG_SWITCH_NAME";
    jq '{wrappers : .wrappers, benchmarks: [.benchmarks | .[] | select( .name as $name | ["irmin_replay", "cpdf", "frama-c", "js_of_ocaml", "graph500_kernel1", "graph500_kernel1_multicore"] | index($name) | not )]}' "$RUN_CONFIG_JSON" >"$RUN_CONFIG_JSON".tmp;
    mv "$RUN_CONFIG_JSON".tmp "$RUN_CONFIG_JSON";
    echo "(data_only_dirs irmin cpdf frama-c)" >benchmarks/dune
else
    echo "Not filtering benchmarks for OCaml $CONFIG_SWITCH_NAME"
fi
