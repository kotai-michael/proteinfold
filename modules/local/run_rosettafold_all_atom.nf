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

//    container "/srv/scratch/z5378336/apptainers/RoseTTAFold-All-Atom-dev.sif"

    input:
    tuple val(meta), path(fasta)
//    path ('bfd/*')
//    path ('uniref30/*')
//    path ('blast/*')
//    path ('pdb100/*')
    
    output:
    path ("${fasta.baseName}*")
    path "*_mqc.tsv", emit: multiqc
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
//    mamba run --name RFAA python -m rf2aa.run_inference --config-name "${fasta}"
    """
    echo "DEBUG: Contents of bfd path:"
    ls -lh /
    
    cat <<-END_VERSIONS > versions.yml

    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch ./"${fasta.baseName}".rosettafold_all_atom.pdb
    touch ./"${fasta.baseName}"_mqc.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(gawk --version| head -1 | sed 's/GNU Awk //; s/, API:.*//')
    END_VERSIONS
    """
}
