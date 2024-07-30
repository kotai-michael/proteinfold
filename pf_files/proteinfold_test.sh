module load nextflow/23.04.4 java/11

export SINGULARITY_CACHE_DIR=/srv/scratch/sbf/singularity_cache
export NXF_SINGULARITY_CACHEDIR=/srv/scratch/sbf/singularity_cache

nextflow run ../main.nf \
    --input samplesheet.csv \
    --outdir test_out \
    --mode alphafold2 \
    --alphafold2_db /data/bio/alphafold \
    --full_dbs true \
    --alphafold2_model_preset monomer \
    --use_gpu true \
    -profile singularity
