/*
 * Run RoseTTAFold_All_Atom 
 */
process RUN_ROSETTAFOLD_ALL_ATOM {
    tag "$meta.id"
    label 'process_medium'

    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_ROSETTAFOLD_ALL_ATOM module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }

    container "RoseTTAFold_All_Atom.sif"

    input:
    tuple val(meta), path(file)
    
    output:
    path ("${file.baseName}*")
    path "*_mqc.tsv", emit: multiqc
    path "versions.yaml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
	apptainer run --nv -B /mnt/af2,/srv \
	--env blast_path="${params.blast_path}" \
	--env bfd_path="${params.bfd_path}" \
	--env uniref30_path="${params.uniref30_variable}" \
	--env pdb100="${params.pdb100_path}" \
	RoseTTAFold_All_Atom.sif "$file"
    
    cat <<-END_VERSIONS > versions.yaml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch ./"${file.baseName}".rosettafold_all_atom.pdb
    touch ./"${file.baseName}"_mqc.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(gawk --version| head -1 | sed 's/GNU Awk //; s/, API:.*//')
    END_VERSIONS
    """
}
