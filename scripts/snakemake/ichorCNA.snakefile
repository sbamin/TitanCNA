configfile: "/mnt/evocore/repos/TitanCNA/scripts/snakemake/config/config.yaml"
## samples.yaml comes from mounted device and given as an argument in run_snakemake wrapper
# configfile: "/mnt/scratch/run_config/samples.yaml"

rule correctDepth:
  input: 
  	expand("results/ichorCNA/{tumor}/{tumor}.cna.seg", tumor=config["pairings"]),
  	expand("results/ichorCNA/{tumor}/{tumor}.correctedDepth.txt", tumor=config["pairings"]),
  	expand("results/readDepth/{samples}.bin{binSize}.wig", samples=config["samples"], binSize=str(config["binSize"]))

rule read_counter:
	input:
		lambda wildcards: config["samples"][wildcards.samples]
	output:
		mywig="results/readDepth/{samples}.bin{binSize}.wig",
		done="results/readDepth/{samples}.bin{binSize}.done"	
	params:
		readCounter=config["readCounterScript"],
		binSize=config["binSize"],
		qual="20",
		chrs=config["chrs"],
		mem=config["std_mem"],
		runtime=config["std_runtime"],
		pe=config["std_numCores"]
	resources:
		mem=4
	log:
		"logs/readDepth/{samples}.bin{binSize}.log"
	shell:
		"""
		{params.readCounter} {input} -c {params.chrs} -w {params.binSize} -q {params.qual} > {output} 2> {log}
		echo "read_counter done" > {output.done} 2> {log}
		"""

rule ichorCNA:
	input:
		tum="results/readDepth/{tumor}.bin" + str(config["binSize"]) + ".wig",
		norm=lambda wildcards: "results/readDepth/" + config["pairings"][wildcards.tumor] + ".bin" + str(config["binSize"]) + ".wig"
	output:
		corrDepth="results/ichorCNA/{tumor}/{tumor}.correctedDepth.txt",
		#param="results/ichorCNA/{tumor}/{tumor}.params.txt",
		cna="results/ichorCNA/{tumor}/{tumor}.cna.seg"
		#outDir="results/ichorCNA/{tumor}"
		#segTxt="results/ichorCNA/{tumor}/{tumor}.seg.txt",
		#seg="results/ichorCNA/{tumor}/{tumor}.seg",
		#rdata="results/ichorCNA/{tumor}/{tumor}.RData"
	params:
		rscript=config["ichorCNA_rscript"],
		libdir=config["ichorCNA_libdir"],
		id="{tumor}",
		ploidy=config["ichorCNA_ploidy"],
		normal=config["ichorCNA_normal"],
		genomeStyle=config["genomeStyle"],
		gcwig=config["ichorCNA_gcWig"],
		mapwig=config["ichorCNA_mapWig"],
		estimateNormal=config["ichorCNA_estimateNormal"],
		estimatePloidy=config["ichorCNA_estimatePloidy"],
		estimateClonality=config["ichorCNA_estimateClonality"],
		scStates=config["ichorCNA_scStates"],
		maxCN=config["ichorCNA_maxCN"],
		includeHOMD=config["ichorCNA_includeHOMD"],
		chrs=config["ichorCNA_chrs"],
		#chrTrain=config["ichorCNA_chrTrain"],
		centromere=config["centromere"],
		exons=config["ichorCNA_exons"],
		txnE=config["ichorCNA_txnE"],
		txnStrength=config["ichorCNA_txnStrength"],
		fracReadsChrYMale="0.001",
		plotFileType=config["ichorCNA_plotFileType"],
		plotYlim=config["ichorCNA_plotYlim"],
		mem=config["ichorCNA_mem"],
		runtime=config["ichorCNA_runtime"],
		pe=config["ichorCNA_pe"],
		outDir="results/ichorCNA/{tumor}"
	resources:
		mem=4
	log:
		"logs/ichorCNA/{tumor}.log"	
	shell:
		"Rscript {params.rscript} --libdir {params.libdir} --id {params.id} --WIG {input.tum} --gcWig {params.gcwig} --mapWig {params.mapwig} --NORMWIG {input.norm} --ploidy \"{params.ploidy}\" --normal \"{params.normal}\" --maxCN {params.maxCN} --includeHOMD {params.includeHOMD} --genomeStyle {params.genomeStyle} --chrs \"{params.chrs}\" --estimateNormal {params.estimateNormal} --estimatePloidy {params.estimatePloidy} --estimateScPrevalence {params.estimateClonality} --scStates \"{params.scStates}\" --centromere {params.centromere} --exons.bed {params.exons} --txnE {params.txnE} --txnStrength {params.txnStrength} --fracReadsInChrYForMale {params.fracReadsChrYMale} --plotFileType {params.plotFileType} --plotYLim \"{params.plotYlim}\" --outDir {params.outDir} > {log} 2> {log}"
