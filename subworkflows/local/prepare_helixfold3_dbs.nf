workflow PREPARE_HELIXFOLD3_DBS {

    take:
	uniclust30_path
	ccd_preprocessed_path
	rfam_path
	uniclust30_link
	ccd_preprocessed_link
	rfam_link

	main:
	ch_uniclust30	    = Channel.value(file(uniclust30_path))
    ch_ccd_preprocessed = Channel.value(file(ccd_preprocessed_path))
    ch_rfam             = Channel.value(file(rfam_path))
    ch_versions         = Channel.empty()

    emit:
    uniclust30          = ch_uniclust30
    ccd_preprocessed    = ch_ccd_preprocessed
    rfam                = ch_rfam
    versions            = ch_versions
}
