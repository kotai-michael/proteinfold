/*
 * Run Boltz
 */
process RUN_BOLTZ {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    container "nf-core/proteinfold_boltz:dev"

    input:
    tuple val(meta), path(fasta)
    path (files)
    path ('boltz1_conf.ckpt')
    path ('ccd.pkl')

    output:
    // TODO: rename npz into different emit channels as to not conflict with raw (.tsv) PAE etc. As in PR #306
    tuple val(meta), path ("boltz_results_*/processed/msa/*.npz")               , emit: msa
    tuple val(meta), path ("boltz_results_*/processed/structures/*.npz")        , emit: structures
    tuple val(meta), path ("boltz_results_*/predictions/*/confidence*.json")    , emit: confidence
    tuple val(meta), path ("${meta.id}_plddt.tsv")                              , emit: multiqc
    // TODO: support cif as well like with HelixFold3
    tuple val(meta), path ("${meta.id}_boltz.pdb")                              , emit: top_ranked_pdb
    tuple val(meta), path ("boltz_results_*/predictions/*/*.pdb")               , emit: pdb
    tuple val(meta), path ("boltz_results_*/predictions/*/plddt_*model_0.npz")  , emit: plddt
    tuple val(meta), path ("boltz_results_*/predictions/*/pae_*model_0.npz")    , emit: pae
    tuple val(meta), path ("${meta.id}_plddt.tsv")                              , emit: plddt_raw
    tuple val(meta), path ("${meta.id}_msa.tsv")                                , emit: msa_raw
    tuple val(meta), path ("${meta.id}_*_pae.tsv")                              , optional: true, emit: pae_raw
    tuple val(meta), path ("${meta.id}_ptm.tsv")                                , emit: ptm_raw
    tuple val(meta), path ("${meta.id}_iptm.tsv")                               , emit: iptm_raw

    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba

    // TODO: "boltz_results_*" dir should be be further specified using --out_dir when running Boltz, and being able to go "boltz_results_${meta.id}" instead of "boltz_results_*"
    // TODO: MSA processing for Boltz is not solid yet. They can come from webserver, local mmseq, or a custom paired .csv (see docs below)
    // https://github.com/jwohlwend/boltz/blob/main/docs/prediction.md#yaml-format
    // TODO: what I really need to do is add a function to read /processed/msa/*.npz and convert it to a .tsv file
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_BOLTZ module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def version = "0.4.1"
    def args = task.ext.args ?: ''

    """
    boltz predict "${fasta}" ${args} --cache ./ --write_full_pae --output_format pdb
    cp boltz_results_*/predictions/*/*.pdb ./${meta.id}_boltz.pdb

    extract_metrics.py --name ${meta.id} \\
        --structs boltz_results_*/predictions/${meta.id}/*.pdb \\
        --jsons boltz_results_*/predictions/${meta.id}/confidence_*_model_*.json \\
        --npzs boltz_results_*/predictions/${meta.id}/pae_*_model_*.npz \\
        --csvs boltz_results_*/msa/${meta.id}_*.csv \\

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        boltz: $version
    END_VERSIONS
    """

    stub:
    def version = "0.4.1"
    """
    mkdir -p boltz_results_${meta.id}/processed/msa/
    mkdir -p boltz_results_${meta.id}/processed/structures/
    mkdir -p boltz_results_${meta.id}/predictions/${meta.id}/

    touch boltz_results_${meta.id}/processed/msa/${meta.id}.npz
    touch boltz_results_${meta.id}/processed/structures/${meta.id}.npz
    touch boltz_results_${meta.id}/predictions/${meta.id}/confidence_${meta.id}.json
    touch boltz_results_${meta.id}/predictions/${meta.id}/${meta.id}.pdb
    touch boltz_results_${meta.id}/predictions/${meta.id}/plddt_${meta.id}_model_0.npz
    touch boltz_results_${meta.id}/predictions/${meta.id}/pae_${meta.id}_model_0.npz

    touch "${meta.id}_boltz.pdb"
    touch "${meta.id}_plddt.tsv"
    touch "${meta.id}_msa.tsv"
    touch "${meta.id}_0_pae.tsv"
    touch "${meta.id}_0_ptm.tsv"
    touch "${meta.id}_0_iptm.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        boltz: $version
    END_VERSIONS
    """
}
