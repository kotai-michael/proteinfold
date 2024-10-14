/*
 * Run RoseTTAFold-All-Atom 
 */
process RUN_ROSETTAFOLD-ALL-ATOM {
    tag "$meta.id"
    label 'process_medium'

    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_ROSETTAFOLD-ALL-ATOM module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }

    container "RoseTTAFold-All-Atom.sif"

    input:
    tuple val(meta), path(file)
    
    output:
    path ("${file.baseName}*")
    path "*_mqc.tsv", emit: multiqc
    path "versions.yaml", emit: versions

    when:
    task.ext.when == null || task.ext.when

### Need to modify the DB variables to match dbs.config
    script:
	apptainer run --nv -B /mnt/af2,/srv \
	--env blast_path="${params.blast_path}" \
	--env bfd_path="${params.bfd_path}" \
	--env uniref30_path="${params.uniref30_path}" \
	--env pdb100="${params.pdb100}" \
	RoseTTAFold-All-Atom-dev.sif "$file"
    }
#    cp "${file.baseName}"/ranked_0.pdb ./"${file.baseName}".rosettafold-all-atom.pdb
#    cd "${file.baseName}"
#    awk '{print \$6"\\t"\$11}' ranked_0.pdb | uniq > ranked_0_plddt.tsv
#    for i in 1 2 3 4
#        do awk '{print \$6"\\t"\$11}' ranked_\$i.pdb | uniq | awk '{print \$2}' > ranked_"\$i"_plddt.tsv
#    done
#    paste ranked_0_plddt.tsv ranked_1_plddt.tsv ranked_2_plddt.tsv ranked_3_plddt.tsv ranked_4_plddt.tsv > plddt.tsv
#    echo -e Positions"\\t"rank_0"\\t"rank_1"\\t"rank_2"\\t"rank_3"\\t"rank_4 > header.tsv
#    cat header.tsv plddt.tsv > ../"${file.baseName}"_plddt_mqc.tsv
#    cd ..

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    ""
    touch ./"${file.baseName}".rosettafold-all-atom.pdb
    touch ./"${file.baseName}"_mqc.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(gawk --version| head -1 | sed 's/GNU Awk //; s/, API:.*//')
    END_VERSIONS
    """
}
