//
// Download with aria2 and uncompress the data if needed
//
include { UNTAR           } from '../../modules/nf-core/untar/main'
include { GUNZIP          } from '../../modules/nf-core/gunzip/main'
include { ARIA2           } from '../../modules/nf-core/aria2/main'
include { UNZIP           } from '../../modules/nf-core/unzip/main'
include { ZSTD_DECOMPRESS } from '../../modules/local/zstd_decompress/main.nf'

workflow ARIA2_UNCOMPRESS {
    take:
    source_url // url

    main:
    ARIA2 (
        [
            [:],
            source_url
        ]
    )
    ch_db = Channel.empty()

    if (source_url.toString().endsWith('.pkl.gz')) {
        ch_db = ARIA2.out.downloaded_file.map { it[1] }
    } else if (source_url.toString().endsWith('.tar') || source_url.toString().endsWith('.tar.gz') || source_url.toString().endsWith('.tar.zst')) {
        ch_db = UNTAR (ARIA2.out.downloaded_file).untar.map{ it[1] }
    } else if (source_url.toString().endsWith('.gz')) {
        ch_db = GUNZIP (ARIA2.out.downloaded_file).gunzip.map { it[1] }
    } else if (source_url.toString().endsWith('.zst')) {
        ch_db = ZSTD_DECOMPRESS (ARIA2.out.downloaded_file).decompressed.map { it[1] }
    } else if (source_url.toString().endsWith('.zip')) {
        ch_db = UNZIP (ARIA2.out.downloaded_file)
                    .unzipped_archive
                    //.map { it[1] }
                    .map { meta, dir ->
                        // Get the nested directory
                        def nestedDir = dir.listFiles()[0]
                        // Find the .pdparams file
                        def pdparamsFile = nestedDir.listFiles().find { it.getName().endsWith('.pdparams') }
                        [ pdparamsFile ]
                    }
        ch_db.view()
    } else {
        ch_db = ARIA2.out.downloaded_file.map { it[1] }
    }

    emit:
    db       = ch_db              // channel: [ db ]
    versions = ARIA2.out.versions // channel: [ versions.yml ]
}
