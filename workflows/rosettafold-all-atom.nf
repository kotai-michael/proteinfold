## Currently just based on the AF2 .nf workflow, requires modification.

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowRosettafold-All-Atom.initialise(params, log)

// Check input path parameters to see if they exist
def checkPathParamList = [
    params.input,
    params.rosettafold-all-atom_db
]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input file not specified!' }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/rfaa_input_check' ## Doesn't exist, RFAA takes different inputs than AF2
include { PREPARE_ROSETTAFOLD-ALL-ATOM_DBS } from '../subworkflows/local/prepare_rosettafold-all-atom_dbs' ## Doesn't exist

//
// MODULE: Local to the pipeline
//
include { RUN_ROSETTAFOLD-ALL-ATOM      } from '../modules/local/run_rosettafold-all-atom'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow ROSETTAFOLD-ALL-ATOM {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    if (params.rosettafold-all-atom_model_preset != 'multimer') {
        INPUT_CHECK (
            ch_input
        )
        .fastas
        .map {
            meta, fasta ->
            [ meta, fasta.splitFasta(file:true) ]
        }
        .transpose()
        .set { ch_fasta }
    } else {
        INPUT_CHECK (
            ch_input
        )
        .fastas
        .set { ch_fasta }
    }
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    //
    // SUBWORKFLOW: Download databases and params for Rosettafold-All-Atom
    //
    PREPARE_ROSETTAFOLD-ALL-ATOM_DBS ( )
    ch_versions = ch_versions.mix(PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.versions)

    if (params.rosettafold-all-atom_mode == 'standard') {
        //
        // SUBWORKFLOW: Run Rosettafold-All-Atom standard mode
        //
        RUN_ROSETTAFOLD-ALL-ATOM (
            ch_fasta,
            params.full_dbs,
            params.rosettafold-all-atom_model_preset,
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.params,
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.bfd.ifEmpty([]),
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.small_bfd.ifEmpty([]),
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.mgnify,
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.pdb70,
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.pdb_mmcif,
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.uniclust30,
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.uniref90,
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.pdb_seqres,
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.uniprot,
        )
        ch_versions = ch_versions.mix(RUN_ROSETTAFOLD-ALL-ATOM.out.versions)
        ch_multiqc_rep = RUN_ROSETTAFOLD-ALL-ATOM.out.multiqc.collect()
    } else if (params.rosettafold-all-atom_mode == 'split_msa_prediction') {
        //
        // SUBWORKFLOW: Run Rosettafold-All-Atom split mode, MSA and prediction
        //
        RUN_ROSETTAFOLD-ALL-ATOM_MSA (
            ch_fasta,
            params.full_dbs,
            params.rosettafold-all-atom_model_preset,
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.params,
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.bfd.ifEmpty([]),
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.small_bfd.ifEmpty([]),
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.mgnify,
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.pdb70,
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.pdb_mmcif,
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.uniclust30,
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.uniref90,
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.pdb_seqres,
            PREPARE_ROSETTAFOLD-ALL-ATOM_DBS.out.uniprot

        )
        ch_versions = ch_versions.mix(RUN_ROSETTAFOLD-ALL-ATOM_MSA.out.versions)

    }

    //
    // MODULE: Pipeline reporting
    //
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowRosettafold-All-Atom.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowRosettafold-All-Atom.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_rep)

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    multiqc_report = MULTIQC.out.report.toList()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.adaptivecard(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
