nextflow run nf-core/proteinfold -r 1.1.0 \
    --input samplesheet.csv \
    --outdir test_out \
    --mode alphafold2 \
    --alphafold2_db /data/bio/alphafold \
    --full_dbs true \
    --alphafold2_model_preset monomer \
    --use_gpu false \
    -profile singularity
