workflow PREPARE_HELIXFOLD3_DBS {

    take:
    helixfold3_uniclust30_link
    helixfold3_ccd_preprocessed_link
    helixfold3_rfam_link
    helixfold3_init_models_link
    helixfold3_bfd_link
    helixfold3_small_bfd_link
    helixfold3_uniprot_link
    helixfold3_pdb_seqres_link
    helixfold3_uniref90_link
    helixfold3_mgnify_link
    helixfold3_pdb_mmcif_link
    helixfold3_uniclust30_path
    helixfold3_ccd_preprocessed_path
    helixfold3_rfam_path
    helixfold3_init_models_path
    helixfold3_bfd_path
    helixfold3_small_bfd_path
    helixfold3_uniprot_path
    helixfold3_pdb_seqres_path
    helixfold3_uniref90_path
    helixfold3_mgnify_path
    helixfold3_pdb_mmcif_path

    main:
    ch_helixfold3_uniclust30 = Channel.value(file(helixfold3_uniclust30_path))
    ch_helixfold3_ccd_preprocessed = Channel.value(file(helixfold3_ccd_preprocessed_path))
    ch_helixfold3_rfam = Channel.value(file(helixfold3_rfam_path))
    ch_helixfold3_bfd = Channel.value(file(helixfold3_bfd_path))
    ch_helixfold3_small_bfd = Channel.value(file(helixfold3_small_bfd_path))
    ch_helixfold3_uniprot = Channel.value(file(helixfold3_uniprot_path))
    ch_helixfold3_pdb_seqres = Channel.value(file(helixfold3_pdb_seqres_path))
    ch_helixfold3_uniref90 = Channel.value(file(helixfold3_uniref90_path))
    ch_helixfold3_mgnify     = Channel.value(file(helixfold3_mgnify_path))
    ch_mmcif_files              = file(helixfold3_pdb_mmcif_path, type: 'dir')
    ch_mmcif_obsolete           = file(helixfold3_pdb_mmcif_path, type: 'file')
    ch_helixfold3_pdb_mmcif     = Channel.value(ch_mmcif_files + ch_mmcif_obsolete)
    ch_helixfold3_init_models   = Channel.value(file(helixfold3_init_models_path))
    ch_versions         = Channel.empty()

    emit:
    helixfold3_uniclust30        = ch_helixfold3_uniclust30
    helixfold3_ccd_preprocessed  = ch_helixfold3_ccd_preprocessed
    helixfold3_rfam              = ch_helixfold3_rfam
    helixfold3_bfd               = ch_helixfold3_bfd
    helixfold3_small_bfd         = ch_helixfold3_small_bfd
    helixfold3_uniprot           = ch_helixfold3_uniprot
    helixfold3_pdb_seqres        = ch_helixfold3_pdb_seqres
    helixfold3_uniref90          = ch_helixfold3_uniref90
    helixfold3_mgnify            = ch_helixfold3_mgnify
    helixfold3_pdb_mmcif         = ch_helixfold3_pdb_mmcif
    helixfold3_init_models       = ch_helixfold3_init_models
    versions                    = ch_versions
}
