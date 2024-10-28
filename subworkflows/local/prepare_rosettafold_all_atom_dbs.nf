//
// TBD: Download all the required Rosettafold-All-Atom databases and parameters
//


workflow PREPARE_ROSETTAFOLD_ALL_ATOM_DBS {

    take:
    bfd_path                 // directory: /path/to/bfd/
    uniref30_rosettafold_all_atom_path // directory: /path/to/uniref30/rosettafold_all_atom/
    blast_path
    pdb100_path

    main:
    ch_bfd          = Channel.value(file(bfd_path))
    ch_uniref30     = Channel.value(file(uniref30_rosettafold_all_atom_path, type: 'any'))
    ch_blast        = Channel.value(file(blast_path, type: 'string'))
    ch_pdb100       = Channel.value(file(pdb100_path))

    emit:
    bfd        = ch_bfd
    uniref30   = ch_uniref30
    blast      = ch_blast
    pdb100     = ch_pdb100
}
