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

    container "/srv/scratch/z5378336/RoseTTAFold_All_Atom.sif"

    input:
    tuple val(meta), path(fasta)
    path ('bfd/*')
    path ('UniRef30_2020_06/*')
    path ('pdb100_2021Mar03/*')
    path ('blast-2.2.26/*')
    
    output:
    path ("${fasta.baseName}*")
    path "*_mqc.tsv", emit: multiqc
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    ln -s /app/RoseTTAFold-All-Atom/make_msa.sh .

    mamba run --name RFAA python -m rf2aa.run_inference \
    --config-dir $PWD \
    --config-path $PWD \
    --config-name "${fasta}"

    cp "${fasta.baseName}".pdb ./"${fasta.baseName}".rosettafold_all_atom.pdb
    awk '{print \$6"\\t"\$11}' "${fasta.baseName}".rosettafold_all_atom.pdb | uniq > plddt.tsv
    echo -e Positions"\\t" > header.tsv
    cat header.tsv plddt.tsv > ../"${fasta.baseName}"_plddt_mqc.tsv
    cd ..

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
