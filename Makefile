#
# Configuration
#

# Use bash
SHELL=/bin/bash

# Make variable
MAKE=/usr/bin/make

# Set bench command from Dockerfile
BENCH_COMMAND=$(BENCHCMD)

# options for running the benchmarks
# benchmark build target type:
#  - buildbench: build all single threaded tests
BUILD_BENCH_TARGET ?= buildbench

# The run configuration json file that describes the benchmarks and
# configurations.
RUN_CONFIG_JSON ?= run_config.json

# Default dune version to be used
SANDMARK_DUNE_VERSION ?= 3.5.0

# Default URL
SANDMARK_URL ?= ""

# Default packages to remove
SANDMARK_REMOVE_PACKAGES ?= ""

# Default list of packages to override
SANDMARK_OVERRIDE_PACKAGES ?= ""

# Override orun with custom name
SANDMARK_CUSTOM_NAME ?= ""

# Flag to select whether to use sys_dune_hack
USE_SYS_DUNE_HACK ?= 0

# benchmark run target type:
#  run_<wrapper> where wrapper is one of the wrappers defined in
#  RUN_CONFIG_JSON. The default RUN_CONFIG_JSON defines two wrappers: perfstat
#  and orun
RUN_BENCH_TARGET ?= run_orun

# Dry run test without executing benchmarks
BUILD_ONLY ?= 0

# number of benchmark iterations to run
ITER ?= 1

# setup default for pre benchmark wrappers
# for example PRE_BENCH_EXEC='taskset --cpu-list 3 setarch `uname -m` --addr-no-randomize'
PRE_BENCH_EXEC ?=

# option to allow benchmarks to continue even if the opam package install errored
CONTINUE_ON_OPAM_INSTALL_ERROR ?= true

# option to wait for loadavg to settle down once the dependencies are installed and
# before the benchmarks are executed
OPT_WAIT ?= 1

IRMIN_DATA_DIR=/tmp/irmin-data

WRAPPER = $(patsubst run_%,%,$(RUN_BENCH_TARGET))

PACKAGES = sexplib0 re yojson react uuidm cpdf nbcodec minilight cubicle orun rungen

ifeq ($(findstring multibench,$(BUILD_BENCH_TARGET)),multibench)
	PACKAGES +=  lockfree kcas domainslib ctypes
else
	PACKAGES += ctypes js_of_ocaml-compiler
endif

DEPENDENCIES = libgmp-dev libdw-dev jq jo python3-pip pkg-config m4 autoconf # Ubuntu
PIP_DEPENDENCIES = intervaltree

.SECONDARY:
export OPAMROOT=$(CURDIR)/_opam

.PHONY: bash list depend clean

# HACK: we are using the system installed dune to avoid breakages with
# multicore and 4.09/trunk
# This is a workaround for r14/4.09/trunk until better solutions arrive
SYS_DUNE_BASE_DIR ?= $(subst /bin/dune,,$(shell which dune))

setup_sys_dune/%: _opam/%
	$(eval CONFIG_SWITCH_NAME = $*)
	$(eval OVERRIDE_DUNE = $(shell sed -n 's/.*dune\.\([0-9]\.[0-9]\.[0-9]\).*/\1/p' ocaml-versions/$*.json))
	$(if $(strip $(OVERRIDE_DUNE)),					\
		$(eval SANDMARK_DUNE_VERSION = "$(OVERRIDE_DUNE)")	\
		@echo "Overriding dune with "$(SANDMARK_DUNE_VERSION),	\
		@echo "Using default dune.$(SANDMARK_DUNE_VERSION)")
ifeq (1, $(USE_SYS_DUNE_HACK))
	@echo $(SYS_DUNE_BASE_DIR)
	@echo "Linking to system dune files found at: "$(SYS_DUNE_BASE_DIR)
	@echo $(SYS_DUNE_BASE_DIR)"/bin/dune --version = "$(shell $(SYS_DUNE_BASE_DIR)/bin/dune --version)
	@rm -rf $(CURDIR)/_opam/sys_dune
	@mkdir -p $(CURDIR)/_opam/sys_dune/bin
	@mkdir -p $(CURDIR)/_opam/sys_dune/lib
	ln -s $(SYS_DUNE_BASE_DIR)/bin/dune $(CURDIR)/_opam/sys_dune/bin/dune
	ln -s $(SYS_DUNE_BASE_DIR)/bin/jbuilder $(CURDIR)/_opam/sys_dune/bin/jbuilder
	ln -s $(SYS_DUNE_BASE_DIR)/lib/dune $(CURDIR)/_opam/sys_dune/lib/dune
	opam repo add upstream "git+https://github.com/ocaml/opam-repository.git" --on-switch=$(CONFIG_SWITCH_NAME) --rank 2
	opam install --switch=$(CONFIG_SWITCH_NAME) --yes ocamlfind
	opam install --switch=$(CONFIG_SWITCH_NAME) --yes "dune.$(SANDMARK_DUNE_VERSION)" "dune-configurator.$(SANDMARK_DUNE_VERSION)"
	# Pin the version so it doesn't change when installing packages
	opam pin add --switch=$(CONFIG_SWITCH_NAME) --yes -n dune "$(SANDMARK_DUNE_VERSION)"
endif

ocamls=$(wildcard ocaml-versions/*.json)

_opam/opam-init/init.sh:
	opam init --bare --no-setup --no-opamrc --disable-sandboxing ./dependencies

_opam/%: _opam/opam-init/init.sh ocaml-versions/%.json
	@ scripts/setup_opam.sh $* ${SANDMARK_URL}

override_packages/%: setup_sys_dune/%
	$(eval CONFIG_SWITCH_NAME = $*)
	$(eval DEV_OPAM = $(OPAMROOT)/$(CONFIG_SWITCH_NAME)/share/dev.opam)
	# Retrieve set of version constraints for chosen OCaml version
	@{ case "$*" in \
		*5.1.0*) echo "Using template/dev-5.1.0+trunk.opam" && cp dependencies/template/dev-5.1.0+trunk.opam $(DEV_OPAM) ;; \
		*5.0.1*) echo "Using template/dev-5.0.1+trunk.opam" && cp dependencies/template/dev-5.0.0+trunk.opam $(DEV_OPAM) ;; \
		*4.14*) echo "Using template/dev-4.14.0.opam" && cp dependencies/template/dev-4.14.0.opam $(DEV_OPAM) ;; \
		*) echo "Using template/dev.opam" && cp dependencies/template/dev.opam $(DEV_OPAM) ;; \
	esac };
	# Conditionally install runtime_events_tools for olly (pausetimes)
	@{ case "$*" in \
		5.*) \
			echo "Enabling pausetimes for OCaml >= 5"; \
			$(eval PACKAGES += runtime_events_tools) ;; \
	    *) echo "Pausetimes unavailable for OCaml < 5" ;; \
	esac };
	opam repo add alpha git+https://github.com/kit-ty-kate/opam-alpha-repository.git --on-switch=$(CONFIG_SWITCH_NAME) --rank 2
	opam exec --switch $(CONFIG_SWITCH_NAME) -- opam update
	opam install --switch=$(CONFIG_SWITCH_NAME) --yes "lru" "psq"
	opam exec --switch $(CONFIG_SWITCH_NAME) -- opam list
ifeq (0, $(USE_SYS_DUNE_HACK))
	opam install --switch=$(CONFIG_SWITCH_NAME) --yes "dune.$(SANDMARK_DUNE_VERSION)" "dune-configurator.$(SANDMARK_DUNE_VERSION)" "dune-private-libs.$(SANDMARK_DUNE_VERSION)" || $(CONTINUE_ON_OPAM_INSTALL_ERROR)
endif
	opam update --switch=$(CONFIG_SWITCH_NAME)
	@{	for i in ${PACKAGES}; do \
			sed -i "/^]/i \ \ \"$${i}\"" $(DEV_OPAM); \
		done; \
	};
	@{	declare -A OVERRIDE=( ["ocaml-config"]="\"ocaml-config\" {= \"1\"}" );	\
		if [ -z "$(SANDMARK_OVERRIDE_PACKAGES)" ]; then \
			do_overrides=`jq '.package_overrides' ocaml-versions/$*.json`; \
			if [ "$${do_overrides}" != null ]; then \
				for row in `cat ocaml-versions/$*.json | jq '.package_overrides | .[]'`; do	\
					package=`echo $$row | xargs echo | tr -d '[:space:]'`; \
					package_name=`cut -d '.' -f 1 <<< "$$package"`; \
					package_version=`cut -d '.' -f 2- <<< "$$package"`; \
					OVERRIDE["$${package_name}"]="\"$${package_name}\" {= \"$${package_version}\" }";	\
				done;	\
			fi; \
		else \
			for p in ${SANDMARK_OVERRIDE_PACKAGES}; do \
				package="$${p}"; \
				package_name=`cut -d '.' -f 1 <<< "$${package}"`; \
				package_version=`cut -d '.' -f 2- <<< "$${package}"`; \
				OVERRIDE["$${package_name}"]="\"$${package_name}\" {= \"$${package_version}\" }"; \
			done; \
		fi; \
		for key in "$${!OVERRIDE[@]}"; do						\
			sed -i "/\"$${key}\"/s/.*/  $${OVERRIDE[$${key}]}/" $(DEV_OPAM); \
		done; \
		if [ -z "$(SANDMARK_REMOVE_PACKAGES)" ]; then \
			do_removal=`jq '.package_remove' ocaml-versions/$*.json`; \
			if [ "$${do_removal}" != null ]; then \
				for row in `cat ocaml-versions/$*.json | jq '.package_remove | .[]'`; do \
					name=`echo $$row | xargs echo | tr -d '[:space:]'`; \
					if [ OVERRIDE["$${name}"] != null ]; then \
						sed -i "/\"$${name}\"/s/.*/ /" $(DEV_OPAM); \
					fi; \
				done; \
			fi; \
		else \
			for p in ${SANDMARK_REMOVE_PACKAGES}; do \
				if [ OVERRIDE["$${p}"] != null ]; then \
					sed -i "/\"$${p}\"/s/.*/ /" $(DEV_OPAM); \
				fi; \
			done; \
		fi; \
		sed -i '/^\s*$$/d' $(DEV_OPAM); \
		opam install $(DEV_OPAM) --switch=$(CONFIG_SWITCH_NAME) --yes --deps-only;	\
		opam list --switch=$(CONFIG_SWITCH_NAME); \
	};

.PHONY: .FORCE
.FORCE:

# the file sandmark_git_hash.txt contains the current git hash for this version of sandmark
log_sandmark_hash:
	-git log -n 1


ocaml-versions/%.bench: depend/% check-parallel/% filter/% override_packages/% log_sandmark_hash ocaml-versions/%.json .FORCE
	$(eval CONFIG_SWITCH_NAME = $*)
	$(eval CONFIG_OPTIONS      = $(shell jq -r '.configure // empty' ocaml-versions/$*.json))
	$(eval CONFIG_RUN_PARAMS   = $(shell jq -r '.runparams // empty' ocaml-versions/$*.json))
	$(eval ENVIRONMENT         = $(shell jq -r '.wrappers[] | select(.name=="$(WRAPPER)") | .environment // empty' "$(RUN_CONFIG_JSON)" ))
	@{ echo '(lang dune 1.0)'; \
	   for i in `seq 1 $(ITER)`; do \
	     echo "(context (opam (switch $(CONFIG_SWITCH_NAME)) (name $(CONFIG_SWITCH_NAME)_$$i)))"; \
	   done } > ocaml-versions/.workspace.$(CONFIG_SWITCH_NAME)
	opam exec --switch $(CONFIG_SWITCH_NAME) -- rungen _build/$(CONFIG_SWITCH_NAME)_1 $(RUN_CONFIG_JSON) > runs_dune.inc
	opam exec --switch $(CONFIG_SWITCH_NAME) -- dune build --profile=release --workspace=ocaml-versions/.workspace.$(CONFIG_SWITCH_NAME) @$(BUILD_BENCH_TARGET);
	@{ if [ "$(BUILD_ONLY)" -eq 0 ]; then												\
		echo "Executing benchmarks with:";											\
		echo "  RUN_CONFIG_JSON=${RUN_CONFIG_JSON}";										\
		echo "  RUN_BENCH_TARGET=${RUN_BENCH_TARGET}  (WRAPPER=${WRAPPER})";							\
		echo "  PRE_BENCH_EXEC=${PRE_BENCH_EXEC}";										\
		$(PRE_BENCH_EXEC) $(ENVIRONMENT) opam exec --switch $(CONFIG_SWITCH_NAME) -- dune build -j 1 --profile=release				\
		  --workspace=ocaml-versions/.workspace.$(CONFIG_SWITCH_NAME) @$(RUN_BENCH_TARGET); ex=$$?;						\
		mkdir -p _results/;												\
		cp ${RUN_CONFIG_JSON} _results/;										\
		for i in `seq 1 $(ITER)`; do \
			declare -A META=( ["arch"]="uname -m" ["hostname"]="hostname" ["kernel"]="uname -s" ["version"]="uname -r" ); \
			s=""; for key in "$${!META[@]}"; do \
			result=`$${META[$${key}]}`; \
			if [ "$${s}" == "" ]; then \
				s="$${key}=$${result}"; \
			else \
				s="$${s} $${key}=$${result}"; \
			fi; \
			done; \
			header_entry=`jo -p $${s} | jq -c`; \
			echo "$${header_entry}" > _results/$(SANDMARK_CUSTOM_NAME)_$$i.$(WRAPPER).summary.bench; \
			find _build/$(CONFIG_SWITCH_NAME)_$$i -name '*.$(WRAPPER).bench' | xargs cat >> _results/$(SANDMARK_CUSTOM_NAME)_$$i.$(WRAPPER).summary.bench;		\
		done;															\
		exit $$ex;														\
	   else																\
		exit 0;															\
	   fi };

data.json:
	@ scripts/bench_to_json.sh

prep_bench:
	@{	$(BENCH_COMMAND); \
		$(MAKE) data.json; \
	};

bench: prep_bench
	@cat data.json

define check_dependency
	$(if $(filter $(shell $(2) | grep $(1) | wc -l), 0),
		@echo "$(1) is not installed. $(3)")
endef

load_irmin_data:
	mkdir -p /tmp/irmin_trace_replay_artefacts;
	if [ ! -f $(IRMIN_DATA_DIR)/data4_100066commits.repr ]; then \
		wget http://data.tarides.com/irmin/data4_100066commits.repr -P $(IRMIN_DATA_DIR); \
	fi;

filter/%:
	@ scripts/filter.sh $* $(RUN_CONFIG_JSON)

depend/%:
	@ scripts/check_json_url.sh $*
	@ scripts/loadavg.sh $(OPT_WAIT)
	$(foreach d, $(DEPENDENCIES),      $(call check_dependency, $(d), dpkg -l,   Install on Ubuntu using apt.))
	$(foreach d, $(PIP_DEPENDENCIES),  $(call check_dependency, $(d), pip3 list --format=columns, Install using pip3 install.))

check-parallel/%:
	@ scripts/check_parallel.sh $* $(BUILD_BENCH_TARGET)

benchclean:
	rm -rf _build/
	rm -rf _results/

clean:
	rm -rf dependencies/packages/ocaml/*
	rm -rf dependencies/packages/ocaml-base-compiler/*
	rm -rf ocaml-versions/.packages.*
	rm -rf ocaml-versions/*.bench
	rm -rf _build
	rm -rf _opam
	rm -rf _results
	rm -rf *filtered.json
	rm -rf *~
	rm -rf benchmarks/dune
	git clean -fd dependencies/packages/ocaml-base-compiler dependencies/packages/ocaml

list:
	@echo $(ocamls)

list_tags:
	@ echo "List of Tags"
	@ jq '[.benchmarks[].tags] | add | flatten | .[]' *.json | sort -u

bash:
	@ bash
	@ echo "[opam subshell completed]"

%_filtered.json: %.json
	@ jq '{wrappers : .wrappers, benchmarks: [.benchmarks | .[] | select(.tags | index($(TAG)) != null)]}' < $< > $@

set-bench-cpu/%:
	@ sed -i "s/cpu-list 5/cpu-list ${BENCH_CPU}/g" $*

%_2domains.json: %.json
	@ jq '{wrappers : .wrappers, benchmarks : [.benchmarks | .[] | {executable : .executable, name: .name, tags: .tags, runs : [.runs | .[] as $$item | if ($$item | .params | split(" ") | .[0] ) == "2" then $$item | .paramwrapper |= "" else empty end ] } ] }' < $< > $@
