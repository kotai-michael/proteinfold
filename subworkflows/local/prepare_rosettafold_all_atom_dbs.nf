//
// Download all the required Rosettafold-All-Atom databases and parameters
//

include {
    ARIA2_UNCOMPRESS as ARIA2_BFD
    ARIA2_UNCOMPRESS as ARIA2_SMALL_BFD
    ARIA2_UNCOMPRESS as ARIA2_UNIREF30} from './aria2_uncompress'

workflow PREPARE_ROSETTAFOLD_ALL_ATOM_DBS {

    take:
    rosettafold_all_atom_db            // directory: path to rosettafold_all_atom DBs
    bfd_path                 // directory: /path/to/bfd/
    small_bfd_path           // directory: /path/to/small_bfd/
    uniref30_rosettafold_all_atom_path // directory: /path/to/uniref30/rosettafold_all_atom/
    bfd_link                 //    string: Specifies the link to download bfd
    small_bfd_link           //    string: Specifies the link to download small_bfd
    uniref30_rosettafold_all_atom_link //    string: Specifies the link to download uniref30_rosettafold_all_atom

    main:
    ch_bfd        = Channel.empty()
    ch_small_bfd  = Channel.empty()
    ch_versions   = Channel.empty()


    if (rosettafold_all_atom_db) {
        ch_bfd       = Channel.value(file(bfd_path))
        ch_small_bfd = Channel.value(file("${projectDir}/assets/dummy_db"))
        ch_bfd       = Channel.value(file("${projectDir}/assets/dummy_db"))
        ch_small_bfd = Channel.value(file(small_bfd_path))
        ch_uniref30       = Channel.value(file(uniref30_rosettafold_all_atom_path, type: 'any'))
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

        ARIA2_UNIREF30(
            uniref30_rosettafold_all_atom_link
        )
        ch_uniref30 = ARIA2_UNIREF30.out.db
        ch_versions = ch_versions.mix(ARIA2_UNIREF30.out.versions)
    }

    emit:
    bfd        = ch_bfd
    small_bfd  = ch_small_bfd
    uniref30   = ch_uniref30
    versions   = ch_versions
}
