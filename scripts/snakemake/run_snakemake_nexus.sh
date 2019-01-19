#!/bin/bash

## Run TitanCNA on DNA Nexus Cloud
## Samir B. Amin, @sbamin
## Sandeep Namburi, @snamburi3

# usage
show_help() {
cat << EOF

Wrapper to run TitanCNA on DNA Nexus platform

## Note that all paths are internal to docker container, and not the actual path on the docker host machine.
## To map respective host volume, docker run with -v /host/user/scratch:/mnt/scratch -v /host/user/configs:/mnt/evocore arguments.

	-i path to config file - used to override snakemake configs
	-s sample barcode - used for making workdir, output files, etc. (default: tumor1)
	-t path to tumor bam
	-n path to normal bam
	-m run mode - DRY|RUN (default: DRY)
	-c max number of jobs to run in parallel (default: 4)

Example: ${0##*/} -s tumor1 -i /mnt/evocore/configs/config.yaml -t /mnt/scratch/bam/test_tumor.bam -n /mnt/scratch/bam/test_normal.bam -m DRY -c 4

EOF
}

if [[ $# == 0 ]];then show_help;exit 1;fi

while getopts "i:c:s:t:n:m:h" opt; do
    case "$opt" in
        h) show_help;exit 0;;
        i) CONFIGFILE=$OPTARG;;
        s) SAMPLEID=$OPTARG;;
        t) TMBAM=$OPTARG;;
        n) NRBAM=$OPTARG;;
        m) MODE=$OPTARG;;
		c) NCORES=$OPTARG;;
       '?') show_help >&2 exit 1 ;;
    esac
done

MYPWD="$(pwd)"
echo "Workdir is $MYPWD"

################################# SETUP_DISKS ##################################
## Note that following paths are internal to docker container, and can not be edited
## To map respective host volume, docker run with -v <path in host scratch>:/mnt/scratch -v <path in host evocore>:/mnt/evocore arg

##### SCRATCH ######
## do not change this
HOSTDATA="/mnt/scratch"
export HOSTDATA

mkdir -p "$HOSTDATA"/snakemake/sjc_titan
mkdir -p "$HOSTDATA"/snakemake/sjc_titan
mkdir -p "$HOSTDATA"/tmp

##### CONFIGS ######
HOSTCONFIGS="/mnt/evocore"
## Important: Copy git repo for TitanCNA, ichorCNA, etc here.
## Do not change directory structure, including names for TitanCNA and ichorCNA (case sensitive)
HOSTCODEDIR="$HOSTCONFIGS"/repos

if [[ ! -d "$HOSTCODEDIR" ]]; then
	echo -e "ERROR: Missing code directory at mounted path: $HOSTCODEDIR\nCopy git repo for TitanCNA, ichorCNA, etc under $HOSTCODEDIR\n" >&2
	exit 1
fi

############################## PARSE_USER_OPTIONS ##############################
## override config options, including config/samples.yaml
CONFIGFILE=${CONFIGFILE:-"$HOSTCODEDIR/TitanCNA/scripts/snakemake/config/config.yaml"}

if [[ ! -f "$CONFIGFILE" ]]; then
	echo -e "ERROR: Inaccesible config file at $CONFIGFILE\nProvide container and not host path to configfile at -i flag.\n" >&2
	show_help
	exit 1
fi

## set to RUN to disable dry mode
MODE=${MODE:-"DRY"}

if [[ "$MODE" != "RUN" ]]; then
	echo -e "INFO: -m is $MODE. Switching to DRY RUN.\n-m RUN to run snakemake on a node.\n" >&2
	MODE="DRY"
fi

## Number of jobs to run in parallel
NCORES=${NCORES:-4}

###### UNUSED FOR NOW ######
## Instead, override config/samples.yaml using CONFIGFILE option
## default sample as given in config/samples.yaml
SAMPLEID=${SAMPLEID:-"tumor1"}
TMBAM=${TMBAM:-"/mnt/scratch/bam/test_tumor.bam"}
NRBAM=${NRBAM:-"/mnt/scratch/bam/test_normal.bam"}

################################ RUN_SNAKEMAKE #################################

## Set PS1 to non-empty, even in non-interactive session
## so that user bashrc configs can load.
## see workaround below for details
PS1=\"$-\" && export PS1

########## SNAKEMAKE_WORKDIR ###########
## set to sample specific workdir
## defaults to config/config.yaml
SMK_BASEDIR="$HOSTDATA"/snakemake
mkdir -p "$SMK_BASEDIR"/runstats

SMK_WORKDIR="$HOSTDATA"/snakemake/sjc_titan/"$SAMPLEID"
mkdir -p "$SMK_WORKDIR"/logs
mkdir -p "$SMK_WORKDIR"/results

TSTAMP=$(date +%d%b%y_%H%M%S%Z)

cat << EOF

############ SNAKEMAKE_INFO ############
DT: $TSTAMP
Workdir: $SMK_WORKDIR
User config: $CONFIGFILE
MODE: $MODE

PS: Sample stats are optional, and may have been
supplied via config file.

SAMPLE: $SAMPLEID
TMBAM: $TMBAM
NRBAM: $NRBAM

MAX JOBS: $NCORES

#### docker ####
Hostname: $(hostname)
OS: $(uname -a)
User: $(id -a)

EOF

if [[ "$MODE" != "RUN" ]]; then
	echo "Running snakemake in dry run"
	sleep 1
	
	snakemake -s TitanCNA.snakefile -n --cores "$NCORES" --latency-wait 60 --max-jobs-per-second 1 --configfile "$CONFIGFILE" --rerun-incomplete -r -p --stats smk_run_sjc_titan_"$TSTAMP".json |& tee -a "$SMK_WORKDIR"/run_sjc_titan_"$TSTAMP".log
else
	snakemake --rulegraph -s TitanCNA.snakefile | dot -Tpng >| "$SMK_WORKDIR"/sjc_titan_flow_"$TSTAMP".png && \
	snakemake --dag -s TitanCNA.snakefile | dot -Tpdf >| "$SMK_WORKDIR"/sjc_titan_dag_"$TSTAMP".pdf && \
	printf "LOGGER\t%s\t%s\tsjc_titan\tSTART\t%s\n" "$TSTAMP" "$SAMPLEID" "$SMK_WORKDIR" | tee -a "$SMK_BASEDIR"/runstats/runstats.tsv && \
	snakemake -s TitanCNA.snakefile --cores "$NCORES" --latency-wait 60 --max-jobs-per-second 1 --configfile "$CONFIGFILE" --rerun-incomplete -r -p --stats smk_run_sjc_titan_"$TSTAMP".json |& tee -a "$SMK_WORKDIR"/run_sjc_titan_"$TSTAMP".log && \
	EXITSTAT=$? && \
	printf "LOGGER\t%s\t%s\tsjc_titan\tEND\t%s\n" "$TSTAMP" "$SAMPLEID" "$EXITSTAT" | tee -a "$SMK_BASEDIR"/runstats/runstats.tsv
fi

## END ##
