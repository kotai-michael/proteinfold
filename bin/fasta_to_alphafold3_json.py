#!/usr/bin/env python3

import sys
import argparse
import json

def parse_args(args=None):
    Description = "Convert fasta files to Alphafold3 json format."
    Epilog = "Example usage: python fasta_to_alphafold3_json.py <FILE_IN> <FILE_OUT>"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument("FILE_IN", help="Input fasta file.")
    parser.add_argument("FILE_OUT", help="Output json file.")
    return parser.parse_args(args)

def fasta_to_alphafold3_json(file_in):
    """
    TODO
    This function checks that the samplesheet follows the following structure:
    sample,fastq_1,fastq_2,replicate,antibody,control,control_replicate
    SPT5_T0,SRR1822153_1.fastq.gz,SRR1822153_2.fastq.gz,SPT5,1,SPT5_INPUT,1
    SPT5_T0,SRR1822154_1.fastq.gz,SRR1822154_2.fastq.gz,SPT5,2,SPT5_INPUT,2
    SPT5_INPUT,SRR5204809_Spt5-ChIP_Input1_SacCer_ChIP-Seq_ss100k_R1.fastq.gz,SRR5204809_Spt5-ChIP_Input1_SacCer_ChIP-Seq_ss100k_R2.fastq.gz,1,,,
    SPT5_INPUT,SRR5204810_Spt5-ChIP_Input2_SacCer_ChIP-Seq_ss100k_R1.fastq.gz,SRR5204810_Spt5-ChIP_Input2_SacCer_ChIP-Seq_ss100k_R2.fastq.gz,2,,,
    For an example see:
    https://raw.githubusercontent.com/nf-core/test-datasets/chipseq/samplesheet/v2.1/samplesheet_test.csv
    """

    sequence_list = []
    sequence = None
    fasta_mapping_dict = {}

    with open(file_in, "r", encoding="utf-8-sig") as fin:
        for l in fin:
            l = l.strip()
            if l.startswith(">"):
                if sequence:
                    sequence_list.append(sequence)
                id = l[1:]
                sequence = {"id": id, "sequence": ""}
            else:
                sequence["sequence"] += l

        if sequence:
            sequence_list.append(sequence)

    return sequence_list

def create_json_dict(sequence_list):
    """
    This function ... TODO
    """

    json_sequence_list = []

    for sequence in sequence_list:
        item = {
            "name": "my_proteinfold_job",
            "modelSeeds": [11],
            "sequences": [
                {
                    "protein": {
                        "id": sequence["id"],
                        "sequence": sequence["sequence"],
                        "modifications": [],
                        "unpairedMsa": "",
                        "pairedMsa": "",
                        "templates": []
                    }
                }
            ]
        }
        json_sequence_list.append(item)

    return json_sequence_list

def main(args=None):
    args = parse_args(args)
    sequences = fasta_to_alphafold3_json(args.FILE_IN)
    json_list = create_json_dict(sequences)

    with open(args.FILE_OUT, "w") as fout:
        json.dump(json_list, fout, indent=4)

if __name__ == "__main__":
    sys.exit(main())
