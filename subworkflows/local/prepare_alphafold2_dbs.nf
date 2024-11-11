//
// Download all the required AlphaFold 2 databases and parameters
//

include {
    ARIA2_UNCOMPRESS as ARIA2_ALPHAFOLD2_PARAMS
    ARIA2_UNCOMPRESS as ARIA2_BFD
    ARIA2_UNCOMPRESS as ARIA2_SMALL_BFD
    ARIA2_UNCOMPRESS as ARIA2_MGNIFY
    ARIA2_UNCOMPRESS as ARIA2_PDB70
    ARIA2_UNCOMPRESS as ARIA2_UNIREF30
    ARIA2_UNCOMPRESS as ARIA2_UNIREF90
    ARIA2_UNCOMPRESS as ARIA2_UNIPROT_SPROT
    ARIA2_UNCOMPRESS as ARIA2_UNIPROT_TREMBL } from './aria2_uncompress'

include { ARIA2 as ARIA2_PDB_SEQRES } from '../../modules/nf-core/aria2/main'

include { COMBINE_UNIPROT   } from '../../modules/local/combine_uniprot'
include { DOWNLOAD_PDBMMCIF } from '../../modules/local/download_pdbmmcif'

workflow PREPARE_ALPHAFOLD2_DBS {

    take:
    alphafold2_db            // directory: path to alphafold2 DBs
    full_dbs                 //   boolean: Use full databases (otherwise reduced version)
    bfd_path                 // directory: /path/to/bfd/
    small_bfd_path           // directory: /path/to/small_bfd/
    alphafold2_params_path   // directory: /path/to/alphafold2/params/
    mgnify_path              // directory: /path/to/mgnify/
    pdb70_path               // directory: /path/to/pdb70/
    pdb_mmcif_path           // directory: /path/to/pdb_mmcif/
    uniref30_alphafold2_path // directory: /path/to/uniref30/alphafold2/
    uniref90_path            // directory: /path/to/uniref90/
    pdb_seqres_path          // directory: /path/to/pdb_seqres/
    uniprot_path             // directory: /path/to/uniprot/
    bfd_link                 //    string: Specifies the link to download bfd
    small_bfd_link           //    string: Specifies the link to download small_bfd
    alphafold2_params_link   //    string: Specifies the link to download alphafold2_params
    mgnify_link              //    string: Specifies the link to download mgnify
    pdb70_link               //    string: Specifies the link to download pdb70
    pdb_mmcif_link           //    string: Specifies the link to download pdb_mmcif
    pdb_obsolete_link        //    string: Specifies the link to download pdb_obsolete
    uniref30_alphafold2_link //    string: Specifies the link to download uniref30_alphafold2
    uniref90_link            //    string: Specifies the link to download uniref90
    pdb_seqres_link          //    string: Specifies the link to download pdb_seqres
    uniprot_sprot_link       //    string: Specifies the link to download uniprot_sprot
    uniprot_trembl_link      //    string: Specifies the link to download uniprot_trembl

    main:
    ch_bfd        = Channel.empty()
    ch_small_bfd  = Channel.empty()
    ch_versions   = Channel.empty()


    if (alphafold2_db) {
        if (full_dbs) {
            ch_bfd       = Channel.value(file(bfd_path))
            ch_small_bfd = Channel.value(file("${projectDir}/assets/dummy_db"))
        }
        else {
            ch_bfd       = Channel.value(file("${projectDir}/assets/dummy_db"))
            ch_small_bfd = Channel.value(file(small_bfd_path))
        }

        ch_params         = Channel.value(file(alphafold2_params_path))
        ch_mgnify         = Channel.value(file(mgnify_path))
        ch_pdb70          = Channel.value(file(pdb70_path, type: 'dir' ))
        ch_mmcif_files    = file(pdb_mmcif_path, type: 'dir')
        ch_mmcif_obsolete = file(pdb_mmcif_path, type: 'file')
        ch_mmcif          = Channel.value(ch_mmcif_files + ch_mmcif_obsolete)
        ch_uniref30       = Channel.value(file(uniref30_alphafold2_path, type: 'any'))
        ch_uniref90       = Channel.value(file(uniref90_path))
        ch_pdb_seqres     = Channel.value(file(pdb_seqres_path))
        ch_uniprot        = Channel.value(file(uniprot_path))
    }
    else {
        if (full_dbs) {
            ARIA2_BFD(
                bfd_link
            )
            ch_bfd =  ARIA2_BFD.out.db
            ch_versions = ch_versions.mix(ARIA2_BFD.out.versions)
        } else {
            ARIA2_SMALL_BFD(
                small_bfd_link
            )
            ch_small_bfd = ARIA2_SMALL_BFD.out.db
            ch_versions = ch_versions.mix(ARIA2_SMALL_BFD.out.versions)
        }

        ARIA2_ALPHAFOLD2_PARAMS(
            alphafold2_params_link
        )
        ch_params = ARIA2_ALPHAFOLD2_PARAMS.out.db
        ch_versions = ch_versions.mix(ARIA2_ALPHAFOLD2_PARAMS.out.versions)

        ARIA2_MGNIFY(
            mgnify_link
        )
        ch_mgnify = ARIA2_MGNIFY.out.db
        ch_versions = ch_versions.mix(ARIA2_MGNIFY.out.versions)

        ARIA2_PDB70(
            pdb70_link
        )
        ch_pdb70 = ARIA2_PDB70.out.db
        ch_versions = ch_versions.mix(ARIA2_PDB70.out.versions)

        DOWNLOAD_PDBMMCIF(
            pdb_mmcif_link,
            pdb_obsolete_link
        )
        ch_mmcif = DOWNLOAD_PDBMMCIF.out.ch_db
        ch_versions = ch_versions.mix(DOWNLOAD_PDBMMCIF.out.versions)

        ARIA2_UNIREF30(
            uniref30_alphafold2_link
        )
        ch_uniref30 = ARIA2_UNIREF30.out.db
        ch_versions = ch_versions.mix(ARIA2_UNIREF30.out.versions)

        ARIA2_UNIREF90(
            uniref90_link
        )
        ch_uniref90 = ARIA2_UNIREF90.out.db
        ch_versions = ch_versions.mix(ARIA2_UNIREF90.out.versions)

        ARIA2_PDB_SEQRES (
            [
                [:],
                pdb_seqres_link
            ]
        )
        ch_pdb_seqres = ARIA2_PDB_SEQRES.out.downloaded_file.map{ it[1] }
        ch_versions = ch_versions.mix(ARIA2_PDB_SEQRES.out.versions)

        ARIA2_UNIPROT_SPROT(
            uniprot_sprot_link
        )
        ch_versions = ch_versions.mix(ARIA2_UNIPROT_SPROT.out.versions)
        ARIA2_UNIPROT_TREMBL(
            uniprot_trembl_link
        )
        ch_versions = ch_versions.mix(ARIA2_UNIPROT_TREMBL.out.versions)
        COMBINE_UNIPROT (
            ARIA2_UNIPROT_SPROT.out.db,
            ARIA2_UNIPROT_TREMBL.out.db
        )
        ch_uniprot = COMBINE_UNIPROT.out.ch_db
        ch_version =  ch_versions.mix(COMBINE_UNIPROT.out.versions)
    }

    emit:
    bfd        = ch_bfd
    small_bfd  = ch_small_bfd
    params     = ch_params
    mgnify     = ch_mgnify
    pdb70      = ch_pdb70
    pdb_mmcif  = ch_mmcif
    uniref30   = ch_uniref30
    uniref90   = ch_uniref90
    pdb_seqres = ch_pdb_seqres
    uniprot    = ch_uniprot
    versions   = ch_versions
}
