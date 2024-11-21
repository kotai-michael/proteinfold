/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//
include { COLABFOLD_BATCH        } from '../modules/local/colabfold_batch'
include { MMSEQS_COLABFOLDSEARCH } from '../modules/local/mmseqs_colabfoldsearch'
include { MULTIFASTA_TO_CSV      } from '../modules/local/multifasta_to_csv'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow COLABFOLD {

    take:
    ch_samplesheet          // channel: samplesheet read in from --input
    ch_versions            // channel: [ path(versions.yml) ]
    colabfold_model_preset // string: Specifies the model preset to use for colabfold
    ch_colabfold_params    // channel: path(colabfold_params)
    ch_colabfold_db        // channel: path(colabfold_db)
    ch_uniref30            // channel: path(uniref30)
    num_recycles           // int: Number of recycles for esmfold

    main:
    ch_multiqc_report = Channel.empty()

    if (params.colabfold_server == 'webserver') {
        //
        // MODULE: Run colabfold
        //
        if (params.colabfold_model_preset != 'alphafold2_ptm' && params.colabfold_model_preset != 'alphafold2') {
            MULTIFASTA_TO_CSV(
                ch_samplesheet
            )
            ch_versions = ch_versions.mix(MULTIFASTA_TO_CSV.out.versions)
            COLABFOLD_BATCH(
                MULTIFASTA_TO_CSV.out.input_csv,
                colabfold_model_preset,
                ch_colabfold_params,
                [],
                [],
                num_recycles
            )
            ch_versions = ch_versions.mix(COLABFOLD_BATCH.out.versions)
        } else {
            COLABFOLD_BATCH(
                ch_samplesheet,
                colabfold_model_preset,
                ch_colabfold_params,
                [],
                [],
                num_recycles
            )
            ch_versions = ch_versions.mix(COLABFOLD_BATCH.out.versions)
        }

    } else if (params.colabfold_server == 'local') {
        //
        // MODULE: Run mmseqs
        //
        if (params.colabfold_model_preset != 'alphafold2_ptm' && params.colabfold_model_preset != 'alphafold2') {
            MULTIFASTA_TO_CSV(
                ch_samplesheet
            )
            ch_versions = ch_versions.mix(MULTIFASTA_TO_CSV.out.versions)
            MMSEQS_COLABFOLDSEARCH (
                MULTIFASTA_TO_CSV.out.input_csv,
                ch_colabfold_params,
                ch_colabfold_db,
                ch_uniref30
            )
            ch_versions = ch_versions.mix(MMSEQS_COLABFOLDSEARCH.out.versions)
        } else {
            MMSEQS_COLABFOLDSEARCH (
                ch_samplesheet,
                ch_colabfold_params,
                ch_colabfold_db,
                ch_uniref30
            )
            ch_versions = ch_versions.mix(MMSEQS_COLABFOLDSEARCH.out.versions)
        }

        //
        // MODULE: Run colabfold
        //
        COLABFOLD_BATCH(
            MMSEQS_COLABFOLDSEARCH.out.a3m,
            colabfold_model_preset,
            ch_colabfold_params,
            ch_colabfold_db,
            ch_uniref30,
            num_recycles
        )
        ch_versions    = ch_versions.mix(COLABFOLD_BATCH.out.versions)
    }

    COLABFOLD_BATCH
        .out
        .top_ranked_pdb
        .map { [ it[0]["id"], it[0], it[1] ] }
        .join(
            COLABFOLD_BATCH
                .out
                .msa
                .map { [ it[0]["id"], it[1] ] },
            remainder:true
        )
        .set { ch_top_ranked_pdb }

    COLABFOLD_BATCH
        .out
        .pdb
        .join(COLABFOLD_BATCH.out.msa)
        .map {
            it[0]["model"] = "colabfold"
            it
        }
        .set { ch_pdb_msa }

    COLABFOLD_BATCH
        .out
        .multiqc
        .map { it[1] }
        .toSortedList()
        .map { [ [ "model":"colabfold"], it.flatten() ] }
        .set { ch_multiqc_report  }

    COLABFOLD_BATCH
        .out
        .multiqc

    COLABFOLD_BATCH
        .out
        .multiqc
        .collect()

    emit:
    top_ranked_pdb = ch_top_ranked_pdb // channel: [ id, /path/to/*.pdb ]
    pdb_msa        = ch_pdb_msa        // channel: [ meta, /path/to/*.pdb, /path/to/*_coverage.png ]
    multiqc_report = ch_multiqc_report // channel: /path/to/multiqc_report.html
    versions       = ch_versions       // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
