/*
 * Run RoseTTAFold_All_Atom
 */
process RUN_ROSETTAFOLD_ALL_ATOM {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "nf-core/proteinfold_rosettafold_all_atom:dev"

    input:
    tuple val(meta), path(yaml)
    path ('bfd/*')
    path ('UniRef30_2020_06/*')
    path ('pdb100_2021Mar03/*')
    path ('*')
    path (fasta_files)

    output:
    tuple val(meta), path ("${meta.id}_rosettafold_all_atom.pdb"), emit: pdb
    tuple val(meta), path ("*_mqc.tsv")                          , emit: multiqc
    path "versions.yml"                                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_ROSETTAFOLD_ALL_ATOM module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''
    def VERSION = '1.2.0dev' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.

    """
    mamba run --name RFAA python /app/RoseTTAFold-All-Atom/rf2aa/run_inference.py \
    --config-dir /app/RoseTTAFold-All-Atom/rf2aa/config/inference \
    --config-name "${yaml}" \
    $args

    cp "${yaml.baseName}.pdb" "${meta.id}_rosettafold_all_atom.pdb"
    awk '{printf "%s\\t%.0f\\n", \$6, \$11 * 100}' ${meta.id}_rosettafold_all_atom.pdb | uniq > plddt.tsv
    echo -e Positions"\\t"${meta.id}_rosettafold_all_atom.pdb > header.tsv
    cat header.tsv plddt.tsv > "${meta.id}_plddt_mqc.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch ./${meta.id}_rosettafold_all_atom.pdb
    touch ./${meta.id}_plddt_mqc.tsv
    touch ./${meta.id}_aux.pt
    touch ./${meta.id}.pdb
    touch ./header.tsv
    touch ./plddt.tsv
    mkdir ./outputs
    mkdir ./${meta.id}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
