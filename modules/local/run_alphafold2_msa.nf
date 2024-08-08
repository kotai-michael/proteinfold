/*
 * Run Alphafold2 MSA
 */
process RUN_ALPHAFOLD2_MSA {
    tag   "$meta.id"
    label 'process_medium'
    debug true

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://nfcore/proteinfold_alphafold2_msa:1.0.0' :
        'nfcore/proteinfold_alphafold2_msa:1.0.0' }"

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
    path ("${fasta.baseName}.features.pkl"), emit: features
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def db_preset = db_preset ? "full_dbs --bfd_database_path=${params.bfd_variable}bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt --uniclust30_database_path=${params.uniclust30_variable}uniclust30_2018_08" :
        "reduced_dbs --small_bfd_database_path=${params.small_bfd_path}bfd-first_non_consensus_sequences.fasta"
    if (alphafold2_model_preset == 'multimer') {
        alphafold2_model_preset += " --pdb_seqres_database_path=${params.pdb_seqres_variable}pdb_seqres.txt --uniprot_database_path=${params.uniprot_variable}/uniprot.fasta "
    }
    else {
        alphafold2_model_preset += " --pdb70_database_path=${params.pdb70_variable}pdb70 "
    }
    """
    #if [ -f pdb_seqres/pdb_seqres.txt ]
    #    \$PDB_SEQRES_TEMP=\$(mktemp --directory)
    #    cp ${params.pdb_seqres_variable}pdb_seqres.txt \${PDB_SEQRES_TEMP}/
    #    then sed -i "/^\\w*0/d" \$PDB_SEQERS_TEMP/pdb_seqres.txt
    #fi
    python3 /app/alphafold/run_msa.py \
        --fasta_paths=${fasta} \
        --model_preset=${alphafold2_model_preset} \
        --db_preset=${db_preset} \
        --output_dir=\$PWD \
        --data_dir=\$PWD \
        --uniref90_database_path=${params.uniref90_variable}uniref90.fasta \
        --mgnify_database_path=${params.mgnify_database_path}/mgy_clusters_2022_05.fa \
        --template_mmcif_dir=${params.template_mmcif_dir} \
        --obsolete_pdbs_path=${params.obsolete_pdbs_path}  \
        $args

    cp "${fasta.baseName}"/features.pkl ./"${fasta.baseName}".features.pkl

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch ./"${fasta.baseName}".features.pkl

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(gawk --version| head -1 | sed 's/GNU Awk //; s/, API:.*//')
    END_VERSIONS
    """
}
