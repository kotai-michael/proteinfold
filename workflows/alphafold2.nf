/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//
include { RUN_ALPHAFOLD2      } from '../modules/local/run_alphafold2'
include { RUN_ALPHAFOLD2_MSA  } from '../modules/local/run_alphafold2_msa'
include { RUN_ALPHAFOLD2_PRED } from '../modules/local/run_alphafold2_pred'

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

workflow ALPHAFOLD2 {

    take:
    ch_samplesheet          // channel: samplesheet read in from --input
    ch_versions             // channel: [ path(versions.yml) ]
    full_dbs                // boolean: Use full databases (otherwise reduced version)
    alphafold2_mode         //  string: Mode to run Alphafold2 in
    alphafold2_model_preset //  string: Specifies the model preset to use for Alphafold2
    ch_alphafold2_params    // channel: path(alphafold2_params)
    ch_bfd                  // channel: path(bfd)
    ch_small_bfd            // channel: path(small_bfd)
    ch_mgnify               // channel: path(mgnify)
    ch_pdb70                // channel: path(pdb70)
    ch_pdb_mmcif            // channel: path(pdb_mmcif)
    ch_uniref30             // channel: path(uniref30)
    ch_uniref90             // channel: path(uniref90)
    ch_pdb_seqres           // channel: path(pdb_seqres)
    ch_uniprot              // channel: path(uniprot)

    main:
    ch_multiqc_files = Channel.empty()
    ch_pdb           = Channel.empty()
    ch_main_pdb      = Channel.empty()
    ch_msa           = Channel.empty()
    ch_multiqc_rep   = Channel.empty()

    if (alphafold2_model_preset != 'multimer') {
        ch_samplesheet
            .map {
                meta, fasta ->
                [ meta, fasta.splitFasta(file:true) ]
            }
            .transpose()
            .set { ch_samplesheet }
    }

    if (alphafold2_mode == 'standard') {
        //
        // SUBWORKFLOW: Run Alphafold2 standard mode
        //
        RUN_ALPHAFOLD2 (
            ch_samplesheet,
            full_dbs,
            alphafold2_model_preset,
            ch_alphafold2_params,
            ch_bfd,
            ch_small_bfd,
            ch_mgnify,
            ch_pdb70,
            ch_pdb_mmcif,
            ch_uniref30,
            ch_uniref90,
            ch_pdb_seqres,
            ch_uniprot
        )
        ch_pdb         = ch_pdb.mix(RUN_ALPHAFOLD2.out.pdb)
        ch_main_pdb    = ch_main_pdb.mix(RUN_ALPHAFOLD2.out.main_pdb)
        ch_msa         = ch_msa.mix(RUN_ALPHAFOLD2.out.msa)
        ch_multiqc_rep = RUN_ALPHAFOLD2.out.multiqc.map{it[1]}.toSortedList().map{[["model":"alphafold2"], it]}
        ch_versions    = ch_versions.mix(RUN_ALPHAFOLD2.out.versions)

    } else if (alphafold2_mode == 'split_msa_prediction') {
        //
        // SUBWORKFLOW: Run Alphafold2 split mode, MSA and predicition
        //
        RUN_ALPHAFOLD2_MSA (
            ch_samplesheet,
            full_dbs,
            alphafold2_model_preset,
            ch_alphafold2_params,
            ch_bfd,
            ch_small_bfd,
            ch_mgnify,
            ch_pdb70,
            ch_pdb_mmcif,
            ch_uniref30,
            ch_uniref90,
            ch_pdb_seqres,
            ch_uniprot
        )
        ch_versions    = ch_versions.mix(RUN_ALPHAFOLD2_MSA.out.versions)

        RUN_ALPHAFOLD2_PRED (
            ch_samplesheet,
            full_dbs,
            alphafold2_model_preset,
            ch_alphafold2_params,
            ch_bfd,
            ch_small_bfd,
            ch_mgnify,
            ch_pdb70,
            ch_pdb_mmcif,
            ch_uniref30,
            ch_uniref90,
            ch_pdb_seqres,
            ch_uniprot,
            RUN_ALPHAFOLD2_MSA.out.features
        )
        ch_pdb         = ch_pdb.mix(RUN_ALPHAFOLD2_PRED.out.pdb)
        ch_main_pdb    = ch_main_pdb.mix(RUN_ALPHAFOLD2_PRED.out.main_pdb)
        ch_msa         = ch_msa.mix(RUN_ALPHAFOLD2_PRED.out.msa)
        ch_multiqc_rep = RUN_ALPHAFOLD2_PRED.out.multiqc.map{it[1]}.toSortedList().map{[["model":"alphafold2"], it]}
        ch_versions = ch_versions.mix(RUN_ALPHAFOLD2_PRED.out.versions)
    }

    emit:
    main_pdb = ch_main_pdb // channel: /path/to/*.pdb
    pdb = ch_pdb // channel: /path/to/*.pdb
    msa = ch_msa // channel: /path/to/*msa.tsv
    multiqc_report = ch_multiqc_rep // channel: /path/to/multiqc_report.html
    versions       = ch_versions       // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
