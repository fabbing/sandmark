#!/bin/bash

config_switch_name=$1
sandmark_url=$2

rm -rf dependencies/packages/ocaml/ocaml."$config_switch_name"
rm -rf dependencies/packages/ocaml-base-compiler/ocaml-base-compiler."$config_switch_name"
mkdir -p dependencies/packages/ocaml/ocaml."$config_switch_name"
cp -R dependencies/template/ocaml/* dependencies/packages/ocaml/ocaml."$config_switch_name"/
mkdir -p dependencies/packages/ocaml-base-compiler/ocaml-base-compiler."$config_switch_name"
cp -R dependencies/template/ocaml-base-compiler/* \
    dependencies/packages/ocaml-base-compiler/ocaml-base-compiler."$config_switch_name"/
if [ "$sandmark_url" == "" ]; then
    url=$(jq -r '.url // empty' ocaml-versions/"$config_switch_name".json);
else
    url="$sandmark_url";
fi
echo "url { src: \"$url\" }
setenv: [ [ ORUN_CONFIG_ocaml_url = \"$url\" ] ]" >> dependencies/packages/ocaml-base-compiler/ocaml-base-compiler."$config_switch_name"/opam;
OCAML_CONFIG_OPTION=$(jq -r '.configure // empty' ocaml-versions/"$config_switch_name".json)
OCAML_RUN_PARAM=$(jq -r '.runparams // empty' ocaml-versions/"$config_switch_name".json)
opam update
OCAMLRUNPARAM="$OCAML_RUN_PARAM" OCAMLCONFIGOPTION="$OCAML_CONFIG_OPTION" opam switch create --keep-build-dir --yes "$config_switch_name" ocaml-base-compiler."$config_switch_name"
case "$config_switch_name" in
    *5.1*) opam pin add -n --yes --switch "$config_switch_name" sexplib0.v0.15.0 https://github.com/shakthimaan/sexplib0.git#multicore;
esac

# TODO remove pin when a new orun version is released on opam
opam pin add -n --yes --switch "$config_switch_name" orun https://github.com/ocaml-bench/orun.git
# TODO remove pin when a new runtime_events_tools is released on opam
opam pin add -n --yes --switch "$config_switch_name" runtime_events_tools https://github.com/sadiqj/runtime_events_tools.git#09630b67b82f7d3226736793dd7bfc33999f4b25
opam pin add -n --yes --switch "$config_switch_name" ocamlfind https://github.com/dra27/ocamlfind/archive/lib-layout.tar.gz
opam pin add -n --yes --switch "$config_switch_name" base.v0.14.3 https://github.com/janestreet/base.git#v0.14.3
opam pin add -n --yes --switch "$config_switch_name" coq-core https://github.com/ejgallego/coq/archive/refs/tags/multicore-2021-09-29.tar.gz
opam pin add -n --yes --switch "$config_switch_name" coq-stdlib https://github.com/ejgallego/coq/archive/refs/tags/multicore-2021-09-29.tar.gz