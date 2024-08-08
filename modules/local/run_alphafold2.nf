/*
 * Run Alphafold2
 */
process RUN_ALPHAFOLD2 {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://nfcore/proteinfold_alphafold2_standard:1.0.0' :
        'nfcore/proteinfold_alphafold2_standard:1.0.0' }"

    input:
    tuple val(meta), path(fasta)
    val   db_preset
    val   alphafold2_model_preset
    path ('params/*')
    path ('bfd/*')
    path ('small_bfd/*')
    path ('mgnify/*')
    path ('pdb70/*')
    path ('pdb_mmcif/*')
    path ('uniclust30/*')
    path ('uniref90/*')
    path ('pdb_seqres/*')
    path ('uniprot/*')

    output:
    path ("${fasta.baseName}*")
    path "*_mqc.tsv", emit: multiqc
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def db_preset = db_preset ? "full_dbs --bfd_database_path=${params.bfd_dir_path}${params.bfd_metaclust_clu_complete_id30_c90_final_seq_sorted_opt_name} --uniclust30_database_path=${params.uniclust30_dir_path}${params.uniclust30_db_name}" :
        "reduced_dbs --small_bfd_database_path=${params.small_bfd_path}${params.bfd_first_non_consensus_sequences_name}"
    if (alphafold2_model_preset == 'multimer') {
        alphafold2_model_preset += " --pdb_seqres_database_path=${params.pdb_seqres_dir_path}${params.pdb_seqres_txt_name} --uniprot_database_path=${params.uniprot_dir_path}${params.uniprot_fasta_name} "
    }
    else {
        alphafold2_model_preset += " --pdb70_database_path=${params.pdb_dir_path}${params.pdb70_name} "
    }
    """
    if [ -f ${params.pdb_seqres_dir_path}/${params.pbd_seqres_txt_name} ]
        \$PDB_SEQRES_TEMP=\$(mktemp --directory)
        cp ${params.pdb_seqres_dir_path}${params.pdb_seqres_txt_name} \${PDB_SEQRES_TEMP}/
        then sed -i "/^\\w*0/d" \$PDB_SEQERS_TEMP/${params.pdb_seqres_txt_name}
    fi
    if [ -d ${params.alphafold2_params_path} ]; then ln -r -s ${params.alphafold2_params_path} params/; fi
    python3 /app/alphafold/run_alphafold.py \
        --fasta_paths=${fasta} \
        --model_preset=${alphafold2_model_preset} \
        --db_preset=${db_preset} \
        --output_dir=\$PWD \
        --data_dir=\$PWD \
        --uniref90_database_path=${params.uniref90_dir_path}uniref90.fasta \
        --template_mmcif_dir=${params.template_mmcif_dir} \
        --obsolete_pdbs_path=${params.obsolete_pdbs_path} \
        --random_seed=53343 \
        $args

    cp "${fasta.baseName}"/ranked_0.pdb ./"${fasta.baseName}".alphafold.pdb
    cd "${fasta.baseName}"
    awk '{print \$6"\\t"\$11}' ranked_0.pdb | uniq > ranked_0_plddt.tsv
    for i in 1 2 3 4
        do awk '{print \$6"\\t"\$11}' ranked_\$i.pdb | uniq | awk '{print \$2}' > ranked_"\$i"_plddt.tsv
    done
    paste ranked_0_plddt.tsv ranked_1_plddt.tsv ranked_2_plddt.tsv ranked_3_plddt.tsv ranked_4_plddt.tsv > plddt.tsv
    echo -e Positions"\\t"rank_0"\\t"rank_1"\\t"rank_2"\\t"rank_3"\\t"rank_4 > header.tsv
    cat header.tsv plddt.tsv > ../"${fasta.baseName}"_plddt_mqc.tsv
    cd ..

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch ./"${fasta.baseName}".alphafold.pdb
    touch ./"${fasta.baseName}"_mqc.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(gawk --version| head -1 | sed 's/GNU Awk //; s/, API:.*//')
    END_VERSIONS
    """
}
