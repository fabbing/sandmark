#!/bin/bash
# Script called to build the benchmarks.

config_switch_name=$1
wrapper=$2
run_config_json=$3
iter=$4
build_bench_target=$5

CONFIG_OPTIONS=$(jq -r '.configure // empty' ocaml-versions/"$config_switch_name".json)
CONFIG_RUN_PARAMS=$(jq -r '.runparams // empty' ocaml-versions/"$config_switch_name".json)
ENVIRONMENT=$(jq -r '.wrappers[] | select(.name=="'"$wrapper"'") | .environment // empty' "$run_config_json")

fill_dune_file () {
    echo '(lang dune 1.0)';
    for i in $(seq 1 "$iter"); do
        echo "(context (opam (switch $config_switch_name) (name ${config_switch_name}_$i)))";
    done
}

fill_dune_file > ocaml-versions/.workspace."$config_switch_name"
opam exec --switch "$config_switch_name" -- rungen _build/"$config_switch_name"_1 "$run_config_json" > runs_dune.inc
opam exec --switch "$config_switch_name" -- dune build --profile=release --workspace=ocaml-versions/.workspace."$config_switch_name" @"$build_bench_target";