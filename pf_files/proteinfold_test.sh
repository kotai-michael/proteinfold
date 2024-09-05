module load nextflow/23.04.4 java/11 cuda/11.8.0

export SINGULARITY_CACHE_DIR=/srv/scratch/$USER/Singularity/cache
export NXF_SINGULARITY_CACHEDIR=/srv/scratch/$USER/Singularity/cache

nextflow run ../main.nf \
    --input samplesheet.csv \
    --outdir test_out \
    --mode alphafold2 \
    --alphafold2_db /mnt/af2/ \
    --full_dbs true \
    --alphafold2_model_preset multimer \
    --alphafold_params_name 'params' \
    --alphafold2_mode 'split_msa_prediction' \
    --use_gpu true \
    -profile singularity \ 
