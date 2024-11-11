#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/proteinfold
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-core/proteinfold
    Website: https://nf-co.re/proteinfold
    Slack  : https://nfcore.slack.com/channels/proteinfold
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

if (params.mode.toLowerCase().split(",").contains("alphafold2")) {
    include { PREPARE_ALPHAFOLD2_DBS } from './subworkflows/local/prepare_alphafold2_dbs'
    include { ALPHAFOLD2             } from './workflows/alphafold2'
}
if (params.mode.toLowerCase().split(",").contains("colabfold")) {
    include { PREPARE_COLABFOLD_DBS } from './subworkflows/local/prepare_colabfold_dbs'
    include { COLABFOLD             } from './workflows/colabfold'
}
if (params.mode.toLowerCase().split(",").contains("esmfold")) {
    include { PREPARE_ESMFOLD_DBS } from './subworkflows/local/prepare_esmfold_dbs'
    include { ESMFOLD             } from './workflows/esmfold'
}

include { PIPELINE_INITIALISATION          } from './subworkflows/local/utils_nfcore_proteinfold_pipeline'
include { PIPELINE_COMPLETION              } from './subworkflows/local/utils_nfcore_proteinfold_pipeline'
include { getColabfoldAlphafold2Params     } from './subworkflows/local/utils_nfcore_proteinfold_pipeline'
include { getColabfoldAlphafold2ParamsPath } from './subworkflows/local/utils_nfcore_proteinfold_pipeline'
include { POST_PROCESSING                  } from './subworkflows/local/post_processing'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COLABFOLD PARAMETER VALUES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

params.colabfold_alphafold2_params_link = getColabfoldAlphafold2Params()
params.colabfold_alphafold2_params_path = getColabfoldAlphafold2ParamsPath()

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline
//
workflow NFCORE_PROTEINFOLD {

    take:
    samplesheet // channel: samplesheet read in from --input

    main:
    ch_samplesheet              = samplesheet
    ch_multiqc                  = Channel.empty()
    ch_versions                 = Channel.empty()
    ch_report_input             = Channel.empty()
    ch_foldseek_db              = Channel.empty()
    ch_colabfold_out            = Channel.empty()
    ch_esmfold_out              = Channel.empty()
    ch_alphafold2_out           = Channel.empty()
    requested_modes             = params.mode.toLowerCase().split(",")
    //
    // WORKFLOW: Run alphafold2
    //
    if(requested_modes.contains("alphafold2")) {
        //
        // SUBWORKFLOW: Prepare Alphafold2 DBs
        //
        PREPARE_ALPHAFOLD2_DBS (
            params.alphafold2_db,
            params.full_dbs,
            params.bfd_path,
            params.small_bfd_path,
            params.alphafold2_params_path,
            params.mgnify_path,
            params.pdb70_path,
            params.pdb_mmcif_path,
            params.uniref30_alphafold2_path,
            params.uniref90_path,
            params.pdb_seqres_path,
            params.uniprot_path,
            params.bfd_link,
            params.small_bfd_link,
            params.alphafold2_params_link,
            params.mgnify_link,
            params.pdb70_link,
            params.pdb_mmcif_link,
            params.pdb_obsolete_link,
            params.uniref30_alphafold2_link,
            params.uniref90_link,
            params.pdb_seqres_link,
            params.uniprot_sprot_link,
            params.uniprot_trembl_link
        )
        ch_versions = ch_versions.mix(PREPARE_ALPHAFOLD2_DBS.out.versions)

        //
        // WORKFLOW: Run nf-core/alphafold2 workflow
        //
        ALPHAFOLD2 (
            ch_samplesheet,
            ch_versions,
            params.full_dbs,
            params.alphafold2_mode,
            params.alphafold2_model_preset,
            PREPARE_ALPHAFOLD2_DBS.out.params,
            PREPARE_ALPHAFOLD2_DBS.out.bfd.ifEmpty([]).first(),
            PREPARE_ALPHAFOLD2_DBS.out.small_bfd.ifEmpty([]).first(),
            PREPARE_ALPHAFOLD2_DBS.out.mgnify,
            PREPARE_ALPHAFOLD2_DBS.out.pdb70,
            PREPARE_ALPHAFOLD2_DBS.out.pdb_mmcif,
            PREPARE_ALPHAFOLD2_DBS.out.uniref30,
            PREPARE_ALPHAFOLD2_DBS.out.uniref90,
            PREPARE_ALPHAFOLD2_DBS.out.pdb_seqres,
            PREPARE_ALPHAFOLD2_DBS.out.uniprot
        )
        ch_multiqc  = ch_multiqc.mix(ALPHAFOLD2.out.multiqc_report.collect())
        ch_versions = ch_versions.mix(ALPHAFOLD2.out.versions)
        ch_report_input = ch_report_input.mix(
            ALPHAFOLD2.out.pdb.join(ALPHAFOLD2.out.msa).map{it[0]["model"] = "alphafold2"; it}
        )
        ALPHAFOLD2
            .out
            .main_pdb
            .map{[it[0]["id"], it[0], it[1]]}
            .set{ch_alphafold2_out}
    }

    //
    // WORKFLOW: Run colabfold
    //
    if(requested_modes.contains("colabfold")) {
        //
        // SUBWORKFLOW: Prepare Colabfold DBs
        //
        PREPARE_COLABFOLD_DBS (
            params.colabfold_db,
            params.colabfold_server,
            params.colabfold_alphafold2_params_path,
            params.colabfold_db_path,
            params.uniref30_colabfold_path,
            params.colabfold_alphafold2_params_link,
            params.colabfold_db_link,
            params.uniref30_colabfold_link,
            params.create_colabfold_index
        )
        ch_versions = ch_versions.mix(PREPARE_COLABFOLD_DBS.out.versions)

        //
        // WORKFLOW: Run nf-core/colabfold workflow
        //
        COLABFOLD (
            ch_samplesheet,
            ch_versions,
            params.colabfold_model_preset,
            PREPARE_COLABFOLD_DBS.out.params,
            PREPARE_COLABFOLD_DBS.out.colabfold_db,
            PREPARE_COLABFOLD_DBS.out.uniref30,
            params.num_recycles_colabfold
        )
        ch_multiqc  = ch_multiqc.mix(COLABFOLD.out.multiqc_report)
        ch_versions = ch_versions.mix(COLABFOLD.out.versions)
        ch_report_input = ch_report_input.mix(
            COLABFOLD
                .out
                .pdb
                .join(COLABFOLD.out.msa)
                .map { it[0]["model"] = "colabfold"; it }
        )
        COLABFOLD
                .out
                .main_pdb
                .map{[it[0]["id"], it[0], it[1]]}
                .join(COLABFOLD.out.msa
                        .map{[it[0]["id"], it[1]]},
                    remainder:true
                ).set{ch_colabfold_out}
    }

    //
    // WORKFLOW: Run esmfold
    //
    if(requested_modes.contains("esmfold")) {
        //
        // SUBWORKFLOW: Prepare esmfold DBs
        //
        PREPARE_ESMFOLD_DBS (
            params.esmfold_db,
            params.esmfold_params_path,
            params.esmfold_3B_v1,
            params.esm2_t36_3B_UR50D,
            params.esm2_t36_3B_UR50D_contact_regression
        )
        ch_versions = ch_versions.mix(PREPARE_ESMFOLD_DBS.out.versions)

        //
        // WORKFLOW: Run nf-core/esmfold workflow
        //
        ESMFOLD (
            ch_samplesheet,
            ch_versions,
            PREPARE_ESMFOLD_DBS.out.params,
            params.num_recycles_esmfold
        )
        ch_multiqc  = ch_multiqc.mix(ESMFOLD.out.multiqc_report.collect())
        ch_versions = ch_versions.mix(ESMFOLD.out.versions)
        ch_report_input = ch_report_input.mix(
            ESMFOLD.out.pdb.combine(Channel.fromPath("$projectDir/assets/NO_FILE")).map{it[0]["model"] = "esmfold"; it}
        )
        ch_report_input.filter{it[0]["model"] == "esmfold"}
            .map{[it[0]["id"], it[0], it[1], it[2]]}
            .set{ch_esmfold_out}
    }
    //
    // POST PROCESSING: generate visulaisation reports
    //
    if (params.foldseek_search == "easysearch"){
        ch_foldseek_db = channel.value([["id": params.foldseek_db],
                                        file(params.foldseek_db_path,
                                            checkIfExists: true)])
    }

    ch_multiqc_config = params.multiqc_config ? Channel.fromPath( params.multiqc_config ) : Channel.empty()
    ch_multiqc_logo = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo )   : Channel.empty()
    ch_multiqc_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
//ch_multiqc.view()
    POST_PROCESSING(
        params.skip_visualisation,
        requested_modes.size(),
        ch_report_input,
        Channel.fromPath("$projectDir/assets/proteinfold_template.html", checkIfExists: true).first(),
        Channel.fromPath("$projectDir/assets/comparison_template.html", checkIfExists: true).first(),
        params.foldseek_search,
        ch_foldseek_db,
        params.skip_multiqc,
        params.outdir,
        ch_versions,
        ch_multiqc,
        Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true).first(),
        ch_multiqc_config.first(),
        ch_multiqc_logo.first(),
        ch_multiqc_methods_description.first(),
        ch_alphafold2_out,
        ch_esmfold_out,
        ch_colabfold_out
    )

    emit:
    multiqc_report = ch_multiqc
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input
    )

    //
    // WORKFLOW: Run main workflow
    //
    NFCORE_PROTEINFOLD (
        PIPELINE_INITIALISATION.out.samplesheet
    )

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url,
        NFCORE_PROTEINFOLD.out.multiqc_report
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
