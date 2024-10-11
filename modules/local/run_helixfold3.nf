/*
 * Run HelixFold3
 */
process RUN_HELIXFOLD3 {
    tag "$meta.id"
    label 'process_medium'

    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_HELIXFOLD3 module does not support Conda. Please use Docker / Singularity / Podman / Apptainer instead.")
    }

    container "helixfold3.sif"

    input:
    tuple val(meta), path(fasta)
    val   db_preset
    path ('params/*')
    path ('bfd/*')
    path ('small_bfd/*')
    path ('mgnify/*')
    path ('rfam/*')
    path ('pdb_mmcif/*')
    path ('uniclust30/*')
    path ('uniref90/*')
    path ('pdb_seqres/*')
    path ('uniprot/*')
    path ('ccd/*')

    output:
    path ("${fasta.baseName}*")
    path "*_mqc.tsv", emit: multiqc
    path "versions.yaml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    
    export PATH="/opt/miniforge/envs/helixfold/bin:$PATH"
    export PATH="$MAXIT_SRC/bin:$PATH"
    export OBABEL_BIN="/opt/miniforge/envs/helixfold/bin"
    export RCSBROOT=$MAXIT_SRC

    CUDA_VISIBLE_DEVICES=0 /opt/miniforge/envs/helixfold/bin/python3.9 inference.py \
        --maxit_binary "${MAXIT_SRC}/bin/maxit" \
        --jackhmmer_binary_path "/opt/miniforge/envs/helixfold/bin/jackhmmer" \
        --hhblits_binary_path "/opt/miniforge/envs/helixfold/bin/hhblits" \
        --hhsearch_binary_path "/opt/miniforge/envs/helixfold/bin/hhsearch" \
        --kalign_binary_path "/opt/miniforge/envs/helixfold/bin/kalign" \
        --hmmsearch_binary_path "/opt/miniforge/envs/helixfold/bin/hmmsearch" \
        --hmmbuild_binary_path "/opt/miniforge/envs/helixfold/bin/hmmbuild" \
        --preset='${db_preset}' \
        --bfd_database_path="${params.alphafold2_db}bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt" \
        --small_bfd_database_path="${params.alphafold2_db}/g/bfd-first_non_consensus_sequences.fasta" \
        --uniclust30_database_path="${params.alphafold2_db}/g/uniclust30/uniclust30_2018_08" \
        --uniprot_database_path="${params.alphafold2_db}uniprot/uniprot.fasta" \
        --pdb_seqres_database_path="${params.alphafold2_db}pdb_seqres/pdb_seqres.txt" \
        --rfam_database_path="${params.alphafold2_db}/g/Rfam-14.9_rep_seq.fasta" \
        --template_mmcif_dir="${params.alphafold2_db}pdb_mmcif/mmcif_files" \
        --obsolete_pdbs_path="${params.alphafold2_db}pdb_mmcif/obsolete.dat" \
        --ccd_preprocessed_path="${params.alphafold2_db}/g/ccd_preprocessed_etkdg.pkl.gz" \
        --max_template_date=2024-08-14 \
        --input_mnt="$fasta" \
        --output_dir="\$PWD" \
        --model_name allatom_demo \
        --init_model init_models/HelixFold3-240814.pdparams \
        --infer_times 5 \
        --precision "bf16"

    cp "${fasta.baseName}"/"${fasta.baseName}"-rank1/predicted_structure.pdb ./"${fasta.baseName}".helixfold.pdb
    cd "${fasta.baseName}"
    awk '{print \$6"\\t"\$11}' "${fasta.baseName}"-rank1/predicted_structure.pdb | uniq > ranked_0_plddt.tsv
    for i in 1 2 3 4
        do awk '{print \$6"\\t"\$11}' "${fasta.baseName}"-rank\$i/predicted_structure.pdb | uniq | awk '{print \$2}' > ranked_"\$i"_plddt.tsv
    done
    paste ranked_0_plddt.tsv ranked_1_plddt.tsv ranked_2_plddt.tsv ranked_3_plddt.tsv ranked_4_plddt.tsv > plddt.tsv
    echo -e Positions"\\t"rank_0"\\t"rank_1"\\t"rank_2"\\t"rank_3"\\t"rank_4 > header.tsv
    cat header.tsv plddt.tsv > ../"${fasta.baseName}"_plddt_mqc.tsv
    cd ..
    cp ${fasta.baseName}* ./

    cat <<-END_VERSIONS > versions.yaml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch ./"${fasta.baseName}".alphafold.pdb
    touch ./"${fasta.baseName}"_mqc.tsv

    cat <<-END_VERSIONS > versions.yaml
    "${task.process}":
        awk: \$(gawk --version| head -1 | sed 's/GNU Awk //; s/, API:.*//')
    END_VERSIONS
    """
}
