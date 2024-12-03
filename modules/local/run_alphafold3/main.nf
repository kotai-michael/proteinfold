/*
 * Run Alphafold3
 */
process RUN_ALPHAFOLD3 {
    tag "$meta.id"
    label 'process_medium'

    container "nf-core/proteinfold_alphafold3_standard:1.2.0dev"

    input:
    tuple val(meta), path(json)
    // val   db_preset (now always small by default)
    // val   alphafold3_model_preset // (multimer)
    path ('params/*') // ok
    // path ('bfd/*') 
    path ('small_bfd/*')
    path ('mgnify/*') // ok
    // path ('pdb70/*') 
    path ('mmcif_files/*') // ok
    // path ('uniref30/*')
    path ('uniref90/*') // ok
    path ('pdb_seqres/*') // ok
    path ('uniprot/*')

    output:
    path "*.pdb", emit: pdb
    // path ("${fasta.baseName}*")
    // tuple val(meta), path ("${meta.id}_alphafold2.pdb")   , emit: top_ranked_pdb
    // tuple val(meta), path ("${fasta.baseName}/ranked*pdb"), emit: pdb
    // tuple val(meta), path ("${fasta.baseName}/*_msa.tsv") , emit: msa
    // tuple val(meta), path ("*_mqc.tsv")                   , emit: multiqc
    // path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_ALPHAFOLD3 module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }

    def args = task.ext.args ?: ''
    // TODO this kind of conditionals should be implemented in case we allow for rna input
    // if (alphafold3_model_preset == 'multimer') {
    //     alphafold3_model_preset += " --pdb_seqres_database_path=./pdb_seqres/pdb_seqres.txt --uniprot_database_path=./uniprot/uniprot.fasta "
    // }
    // else {
    //     alphafold3_model_preset += " --pdb70_database_path=./pdb70/pdb70_from_mmcif_200916/pdb70 "
    // }
    """
    if [ -f pdb_seqres/pdb_seqres.txt ]
        then sed -i "/^\\w*0/d" pdb_seqres/pdb_seqres.txt
    fi
    if [ -d params/alphafold_params_* ]; then ln -r -s params/alphafold_params_*/* params/; fi
    python3 /app/alphafold/run_alphafold.py \\
        --json_path=${json} \\
        --model_dir=./params/af3.bin \\
        --uniref90_database_path=./uniref90/uniref90_2022_05.fa \\
        --mgnify_database_path=./mgnify/mgy_clusters_2022_05.fa \\
        --pdb_database_path=./mmcif_files \\
        --small_bfd_database_path=./small_bfd/bfd-first_non_consensus_sequences.fasta \\
        --uniprot_cluster_annot_database_path=./uniprot/uniprot_all_2021_04.fa \\
        --seqres_database_path=./pdb_seqres/pdb_seqres_2022_09_28.fasta \\
        --output_dir=\$PWD \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
    
    // # --random_seed=53343 \                                     # no, TODO: find something similar
        
    stub:
    """
    touch test.pdb

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
