#!/usr/bin/env python3

import sys
import argparse
import json
import string

def parse_args(args=None):
    Description = "Convert fasta files to Alphafold3 json format."
    Epilog = "Example usage: python fasta_to_alphafold3_json.py <FILE_IN> <ID>"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)

    ## REQUIRED PARAMETERS
    parser.add_argument(
        "FILE_IN",
        help="Input fasta file."
    )
    parser.add_argument(
        "ID",
        help="ID for file name and for json id tag."
    )

    ## OPTIONAL PARAMETERS
    parser.add_argument(
        "-ms",
        "--model_seed",
        type=int,
        nargs='+',
        dest="MODEL_SEED",
        default=[11],
        help="Alphafold 3 model seed."
    )

    return parser.parse_args(args)

## Copied from alphafold3 so that our id in the file name is actually the same as the file name
## created by alphafold3 source code here:
## https://github.com/google-deepmind/alphafold3/blob/7fdf96161d61a6e18048e5c62bf7e1d711992943/src/alphafold3/common/folding_input.py#L1166-L1170
def sanitised_name(id):
    """Returns sanitised version of the name that can be used as a filename."""
    lower_spaceless_name = id.lower().replace(' ', '_')
    allowed_chars = set(string.ascii_lowercase + string.digits + '_-.')
    return ''.join(l for l in lower_spaceless_name if l in allowed_chars)


def fasta_to_alphafold3_json(file_in, id):
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
    # hacerlo solo para single fasta
    with open(file_in, "r", encoding="utf-8-sig") as fin:
        n_seq = 0
        for l in fin:
            l = l.strip()
            if l.startswith(">"):

                if n_seq > 1:
                    raise RuntimeError("Multifasta files are not allowed")

                n_seq += 1
                if sequence:
                    sequence_list.append(sequence)
                # id = l[1:6]

                sequence = {"id": id, "sequence": ""}
            else:
                sequence["sequence"] += l

        # if sequence:
        #     sequence_list.append(sequence)

    # return sequence_list
    return sequence

## Example from Alphafold3 docs
# json_string = '''{
#   "name": "2PV7",
#   "sequences": [
#     {
#       "protein": {
#         "id": ["A", "B"],
#         "sequence": "GMRESYANENQFGFKTINSDIHKIVIVGGYGKLGGLFARYLRASGYPISILDREDWAVAESILANADVVIVSVPINLTLETIERLKPYLTENMLLADLTSVKREPLAKMLEVHTGAVLGLHPMFGADIASMAKQVVVRCDGRFPERYEWLLEQIQIWGAKIYQTNATEHDHNMTYIQALRHFSTFANGLHLSKQPINLANLLALSSPIYRLELAMIGRLFAQDAELYADIIMDKSENLAVIETLKQTYDEALTFFENNDRQGFIDAFHKVRDWFGDYSEQFLKESRQLLQQANDLKQG"
#       }
#     }
#   ],
#   "modelSeeds": [1],
#   "dialect": "alphafold3",
#   "version": 1
# }'''


# def create_json_dict(sequence_list):
def create_json_dict(sequence, model_seed):
    """
    This function ... TODO
    """

    json_sequence_dict = {}

    # for sequence in sequence_list:
    item = {
        "name": f"{sequence['id']}",

        "sequences": [
            {
                "protein": {
                    "id": "A",
                    "sequence": sequence["sequence"]
                }
            },
        ],
        "modelSeeds": model_seed,
        "dialect": "alphafold3",
        "version": 1
    }

    json_sequence_dict[sequence["id"]] = item

    return json_sequence_dict

def main(args=None):
    args = parse_args(args)
    id = args.ID

    if id.endswith(".json"):
        id = id[:-5]
        reformatted_id = sanitised_name(id)
    else:
        reformatted_id = sanitised_name(id)

    out_json = f"{reformatted_id}.json"

    sequence = fasta_to_alphafold3_json(args.FILE_IN, reformatted_id)
    json_dict = create_json_dict(sequence, args.MODEL_SEED)

    # for id, f_json in json_dict.items():

    print ("json file " + out_json)
    with open(out_json, "w") as fout:
        json.dump(json_dict[reformatted_id], fout, indent=4)

    with open(out_json, 'r') as f:
        json_str = f.read()


if __name__ == "__main__":
    sys.exit(main())
