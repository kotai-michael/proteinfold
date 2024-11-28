/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//
include { RUN_HELIXFOLD3      } from '../modules/local/run_helixfold3'

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

workflow HELIXFOLD3 {

    take:
    ch_samplesheet
    ch_versions             // channel: [ path(versions.yml) ]
    ch_helixfold3_uniclust30
    ch_helixfold3_ccd_preprocessed
    ch_helixfold3_rfam
    ch_helixfold3_bfd
    ch_helixfold3_small_bfd
    ch_helixfold3_uniprot
    ch_helixfold3_pdb_seqres
    ch_helixfold3_uniref90
    ch_helixfold3_mgnify
    ch_helixfold3_pdb_mmcif
    ch_helixfold3_init_models
    ch_helixfold3_maxit_src

    main:
    ch_multiqc_files    = Channel.empty()
    ch_pdb              = Channel.empty()
    ch_top_ranked_pdb   = Channel.empty()
    ch_msa              = Channel.empty()
    ch_multiqc_report   = Channel.empty()

    //
    // SUBWORKFLOW: Run helixfold3
    //
    RUN_HELIXFOLD3 (
        ch_samplesheet,
        ch_helixfold3_uniclust30,
        ch_helixfold3_ccd_preprocessed,
        ch_helixfold3_rfam,
        ch_helixfold3_bfd,
        ch_helixfold3_small_bfd,
        ch_helixfold3_uniprot,
        ch_helixfold3_pdb_seqres,
        ch_helixfold3_uniref90,
        ch_helixfold3_mgnify,
        ch_helixfold3_pdb_mmcif,
        ch_helixfold3_init_models,
        ch_helixfold3_maxit_src
    )

    RUN_HELIXFOLD3_ALL_ATOM
        .out
        .multiqc
        .map { it[1] }
        .toSortedList()
        .map { [ [ "model": "helixfold3" ], it.flatten() ] }
        .set { ch_multiqc_report }

    ch_pdb            = ch_pdb.mix(RUN_HELIXFOLD3_ALL_ATOM.out.pdb)
    ch_top_ranked_pdb = ch_top_ranked_pdb.mix(RUN_HELIXFOLD3_ALL_ATOM.out.top_ranked_pdb)
    ch_versions       = ch_versions.mix(RUN_HELIXFOLD3_ALL_ATOM.out.versions)

    RUN_HELIXFOLD3_ALL_ATOM
        .out
        .pdb
        .combine(ch_dummy_file)
        .map {
            it[0]["model"] = "helixfold3"
            it
        }
        .set { ch_pdb_msa }

    ch_top_ranked_pdb
        .map { [ it[0]["id"], it[0], it[1] ] }
        .set { ch_top_ranked_pdb }

    ch_pdb
        .join(ch_msa)
        .map {
            it[0]["model"] = "helixfold3"
            it
        }
        .set { ch_pdb_msa }

    emit:
    top_ranked_pdb = ch_top_ranked_pdb // channel: [ id, /path/to/*.pdb ]
    multiqc_report = ch_multiqc_report // channel: /path/to/multiqc_report.html
    versions       = ch_versions       // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
