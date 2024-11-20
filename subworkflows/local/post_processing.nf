//
// Post processing analysis for the predected structures
//

//
// SUBWORKFLOW: Consisting entirely of nf-core/modules
//
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from './utils_nfcore_proteinfold_pipeline'

include { GENERATE_REPORT     } from '../../modules/local/generate_report'
include { COMPARE_STRUCTURES  } from '../../modules/local/compare_structures'
include { FOLDSEEK_EASYSEARCH } from '../../modules/nf-core/foldseek/easysearch/main'
include { MULTIQC             } from '../../modules/nf-core/multiqc/main'


workflow POST_PROCESSING {

    take:
    skip_visualisation
    requested_modes_size
    ch_report_input
    ch_proteinfold_template
    ch_comparison_template
    foldseek_search
    ch_foldseek_db
    skip_multiqc
    outdir
    ch_versions
    ch_multiqc_rep
    ch_multiqc_config
    ch_multiqc_custom_config
    ch_multiqc_logo
    ch_multiqc_custom_methods_description
    ch_alphafold2_out
    ch_esmfold_out
    ch_colabfold_out

    main:
    ch_comparision_report_files = Channel.empty()

    if (!skip_visualisation){
        GENERATE_REPORT(
            ch_report_input.map{[it[0], it[1]]},
            ch_report_input.map{[it[0], it[2]]},
            ch_report_input.map{it[0].model},
            ch_proteinfold_template
        )
        ch_versions = ch_versions.mix(GENERATE_REPORT.out.versions)

        if (requested_modes_size > 1){
            ch_comparision_report_files = ch_comparision_report_files.mix(ch_alphafold2_out
                .join(GENERATE_REPORT.out.sequence_coverage
                        .filter{it[0]["model"] == "alphafold2"}
                        .map{[it[0]["id"], it[1]]}, remainder:true
                )
            )

            ch_comparision_report_files = ch_comparision_report_files.mix(
                ch_colabfold_out
            )

            ch_comparision_report_files = ch_comparision_report_files.mix(
                ch_esmfold_out
            )
            //ch_comparision_report_files.view()
            ch_comparision_report_files
                .groupTuple(by: [0], size: requested_modes_size)
                .set{ch_comparision_report_input}

            COMPARE_STRUCTURES(
                ch_comparision_report_input.map{it[1][0]["models"] = params.mode.toLowerCase(); [it[1][0], it[2]]},
                ch_comparision_report_input.map{it[1][0]["models"] = params.mode.toLowerCase(); [it[1][0], it[3]]},
                ch_comparison_template
            )
            ch_versions = ch_versions.mix(COMPARE_STRUCTURES.out.versions)
        }
    }

    if (foldseek_search == "easysearch"){
        FOLDSEEK_EASYSEARCH(
            ch_report_input
            .map{
                if (it[0].model == "esmfold")
                    [it[0], it[1]]
                else
                    [it[0], it[1][0]]
                },
            ch_foldseek_db
        )
    }

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(storeDir: "${outdir}/pipeline_info", name: 'nf_core_proteinfold_software_versions.yml', sort: true, newLine: true)
        .set { ch_collated_versions }
    //
    // MODULE: MultiQC
    //
    if (!skip_multiqc) {
        summary_params           = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
        ch_workflow_summary      = Channel.value(paramsSummaryMultiqc(summary_params))
        ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
        ch_methods_description                = Channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))

        ch_multiqc_files = Channel.empty()
        ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
        ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
        ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
        MULTIQC (
            ch_multiqc_rep.combine(ch_multiqc_files.collect().map{[it]}).map{[it[0], it[1] + it[2]]},
            ch_multiqc_config,
            ch_multiqc_custom_config.collect().ifEmpty([]),
            ch_multiqc_logo.collect().ifEmpty([]),
            [],
            []
        )
        ch_multiqc_report = MULTIQC.out.report.toList()
    }else{
        ch_multiqc_report = Channel.empty()
    }

    emit:
    versions   = ch_versions
    multiqc_report = ch_multiqc_report
}
