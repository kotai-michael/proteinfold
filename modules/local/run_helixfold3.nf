/*
 * Run HelixFold3
 */
process RUN_HELIXFOLD3 {
    tag "$meta.id"
    label 'process_medium'
    label 'gpu_compute'

    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_HELIXFOLD3 module does not support Conda. Please use Docker / Singularity / Podman / Apptainer instead.")
    }

    container "/srv/scratch/sbf/apptainers/helixfold3.sif"

    input:
    tuple val(meta), path(fasta)

    output:
    path ("${fasta.baseName}*")
    tuple val(meta), path ("${meta.id}_helixfold3.cif"), emit: main_cif
    tuple val(meta), path ("${meta.id}_helixfold3.pdb"), emit: main_pdb
    tuple val(meta), path ("${fasta.baseName}/ranked*pdb"), emit: pdb
    tuple val(meta), path ("${fasta.baseName}/*_msa.tsv") , emit: msa
    tuple val(meta), path ("*_mqc.tsv")                   , emit: multiqc
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    export MAXIT_SRC="${params.helixfold3_db}/maxit-v11.200-prod-src"
    export RCSBROOT="\$MAXIT_SRC"
    export PATH="\$MAXIT_SRC/bin:/opt/miniforge/envs/helixfold/bin:$PATH"
    export OBABEL_BIN="/opt/miniforge/envs/helixfold/bin"

    ln -s /app/helixfold3/* .

    /opt/miniforge/envs/helixfold/bin/python3.9 inference.py \
        --maxit_binary "\$MAXIT_SRC/bin/maxit" \
        --jackhmmer_binary_path "/opt/miniforge/envs/helixfold/bin/jackhmmer" \
        --hhblits_binary_path "/opt/miniforge/envs/helixfold/bin/hhblits" \
        --hhsearch_binary_path "/opt/miniforge/envs/helixfold/bin/hhsearch" \
        --kalign_binary_path "/opt/miniforge/envs/helixfold/bin/kalign" \
        --hmmsearch_binary_path "/opt/miniforge/envs/helixfold/bin/hmmsearch" \
        --hmmbuild_binary_path "/opt/miniforge/envs/helixfold/bin/hmmbuild" \
        --preset='reduced_dbs' \
        --bfd_database_path="${params.alphafold2_db}/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt" \
        --small_bfd_database_path="${params.helixfold3_db}/bfd-first_non_consensus_sequences.fasta" \
        --uniclust30_database_path="${params.helixfold3_db}/uniclust30/uniclust30_2018_08" \
        --uniprot_database_path="${params.alphafold2_db}/uniprot/uniprot.fasta" \
        --pdb_seqres_database_path="${params.alphafold2_db}/pdb_seqres/pdb_seqres.txt" \
        --rfam_database_path="${params.helixfold3_db}/Rfam-14.9_rep_seq.fasta" \
        --template_mmcif_dir="${params.alphafold2_db}/pdb_mmcif/mmcif_files" \
        --obsolete_pdbs_path="${params.alphafold2_db}/pdb_mmcif/obsolete.dat" \
        --ccd_preprocessed_path="${params.helixfold3_db}/ccd_preprocessed_etkdg.pkl.gz" \
        --uniref90_database_path "${params.helixfold3_db}/uniref90/uniref90.fasta" \
        --mgnify_database_path "${params.helixfold3_db}/mgnify/mgy_clusters_2018_12.fa" \
        --max_template_date=2024-08-14 \
        --input_json="${fasta}" \
        --output_dir="\$PWD" \
        --model_name allatom_demo \
        --init_model "${params.helixfold3_init_models_path}/HelixFold3-240814.pdparams" \
        --infer_times 1 \
        --diff_batch_size 1 \
        --precision "bf16"

    cp "${fasta.baseName}"/"${fasta.baseName}"-rank1/predicted_structure.pdb ./"${meta.id}"_helixfold3.pdb
    cp "${fasta.baseName}"/"${fasta.baseName}"-rank1/predicted_structure.cif ./"${meta.id}"_helixfold3.cif
    cd "${fasta.baseName}"
    awk '{print \$6"\\t"\$11}' "${fasta.baseName}"-rank1/predicted_structure.pdb | uniq > ranked_1_plddt.tsv
    for i in 2 3 4
        do awk '{print \$6"\\t"\$11}' "${fasta.baseName}"-rank\$i/predicted_structure.pdb | uniq | awk '{print \$2}' > ranked_"\$i"_plddt.tsv
    done
    paste ranked_1_plddt.tsv ranked_2_plddt.tsv ranked_3_plddt.tsv ranked_4_plddt.tsv > plddt.tsv
    echo -e Positions"\\t"rank_1"\\t"rank_2"\\t"rank_3"\\t"rank_4 > header.tsv
    cat header.tsv plddt.tsv > ../"${meta.id}"_plddt_mqc.tsv
    cp final_features.pkl ../
    for i in 2 3 4
        do cp "${fasta.baseName}"-rank\$i/predicted_structure.pdb" ../ranked_\$i.pdb
    done
    cd ..

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch ./"${meta.id}"_helixfold3.pdb
    touch ./"${meta.id}"_mqc.tsv
    mkdir "${fasta.baseName}"
    touch "${fasta.baseName}/ranked_1.pdb"
    touch "${fasta.baseName}/ranked_2.pdb"
    touch "${fasta.baseName}/ranked_3.pdb"
    touch "${fasta.baseName}/ranked_4.pdb"
    touch "${fasta.baseName}/${fasta.baseName}_msa.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
