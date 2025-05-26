#!/usr/bin/env python
import pickle
import os
import argparse
import json
#import torch moved to a conditional import since too bulky import if not used
import numpy as np
import csv
from utils import plddt_from_struct_b_factor

# TODO: Issue #309, make into a poper separate process, it its own module so that dependencies can be managed better
# TODO: Need a sense of ranking, so that metrics can be traced back to correct model structure, even if they're not in sequential order. The enumerates() here are not sufficient.
#       Needs to be program-dependent, (see item below).
# TODO: look into have a --prog argument that could set filenames etc, logically seperate it?
# {name}_{prog}_{metric}.tsv might be easier for MultiQC to parse a complex workdir, than without the .prog
# TODO: read --prog from ${meta.model} in the NextFlow pipes. This also allows case switching in a proper EXTRACT_METRICS process.
# E.g. in main.nf of EXTACT_METRICS process, we could have:
# match ${meta.mode}:
#     case 'alphafold2':
#        ...
#     case 'rosettafold_all_atom':
#        ...
#...
# ^ overwrought with duplication, but can catch program specific weirdness, and lower barrier to adding new programs in the future.

# Mapping of characters to integers for MSA parsing.
# 20 is for unknown characters, and 21 is for gaps.
AA_to_int = {
    "A": 0, "C": 1, "D": 2, "E": 3, "F": 4, "G": 5, "H": 6, "I": 7, "K": 8, "L": 9,
    "M": 10, "N": 11, "P": 12, "Q": 13, "R": 14, "S": 15, "T": 16, "V": 17, "W": 18, "Y": 19,
   ".": 20, "-": 21
}

def a3m_to_int(a3m_file):
    """
    Convert an A3M MSA representation into an integer representation (0-21).
    """
    with open(a3m_file, "r") as f:
        msa = f.read()

    # Convert each sequence in the MSA
    int_sequences = []
    for idx, line in enumerate(msa.splitlines()):
        if idx == 0 and not line.startswith(">"):  # If there's an additional header (non-FASTA) skip it. E.g ColabFold
            continue

        if not line.startswith(">"):  # Ignore header lines
            filtered_line = ''.join(char for char in line if not char.islower()) # Remove inserts (lower-case chars) in a3m
            int_sequence = [AA_to_int.get(char.upper(), 20) for char in filtered_line]
            int_sequences.append(int_sequence)

    int_sequences_array = np.array(int_sequences, dtype=object)
    return int_sequences_array

def format_msa_rows(msa_data):
    return [[str(x) for x in val] for val in msa_data]

def format_pae_rows(pae_data):
    return [[f"{num:.4f}" for num in row] for row in pae_data]

def write_tsv(file_path, rows):
    with open(file_path, 'w') as out_f:
        writer = csv.writer(out_f, delimiter='\t')
        writer.writerows(rows)

def extract_structs_plddt_to_tsv(name, structures):
    """
    Write out a tsv file contain pLDDTs for reading by MultiQC in nf-core/proteinfold
    Uses utils function with BioPython PDB package to extract residue pLDDT values from the b-factor column.
    """
    plddt_cols = [plddt_from_struct_b_factor(structure) for structure in structures]
    res_counts = [len(plddt_col) for plddt_col in plddt_cols]

    if len(set(res_counts)) != 1:
        raise ValueError("Not all structures have the same number of residues!")

    rank_names = [f"rank_{i}" for i in range(len(structures))]
    # Create header as the first row
    plddt_rows =  [["Positions"] + rank_names]
    res_id_col = list(range(len(plddt_cols[0])))
    plddt_rows.extend(zip(res_id_col, *plddt_cols))  # Combine lists column-wise to make rows
    write_tsv(f"{name}_plddt.tsv", plddt_rows)

def read_pkl(name, pkl_files):
    """
    Adapted from the Galaxy AlphaFold tool (https://github.com/usegalaxy-au/tools-au/blob/de94df520c8dc7b8652aedb92e90f6ebb312f95f/tools/alphafold/scripts/outputs.py), originally authored by @neoformit and @graceahall and funded by Australian Biocommons and QCIF Australia.
    """
    for pkl_file in pkl_files:
        print(f"Processing {pkl_file}")
        data = pickle.load(open(pkl_file, "rb"))

        # Process MSA data
        if pkl_file.endswith("final_features.pkl"): # HelixFold3 - This one must be first
            write_tsv(f"{name}_msa.tsv", format_msa_rows(data["feat"]["msa"]))
        elif pkl_file.endswith("features.pkl"): # AlphaFold2.3
            # TODO: AlphaFold2.3 fills end rows with 0s in AlpahFold muliter for an alanine  nf-core/proteinfold Issue #300
            write_tsv(f"{name}_msa.tsv", format_msa_rows(data["msa"]))
    # AlphaFold2.3 non-summary, for each pkl. TODO: Need to either read in ranking_debug.json to get the ranking order, or do it later in the workflow.
        else:
            model_id = os.path.basename(pkl_file).replace("result_model_", "").replace(".pkl", "")

            if 'predicted_aligned_error' not in data.keys():
                print(f"No PAE output in {pkl_file}, it was likely a monomer calculation")
            else:
                write_tsv(f"{name}_{model_id}_pae.tsv", format_pae_rows(data["predicted_aligned_error"]))

            if 'ptm' not in data.keys():
                print(f"No pTM/iPTM output in {pkl_file}, it was likely a monomer calculation")
            else:
                with open(f"{name}_{model_id}_ptm.tsv", 'w') as f:
                    f.write(str(np.round(data['ptm'],3)))
                with open(f"{name}_{model_id}_iptm.tsv", 'w') as f:
                    f.write(str(np.round(data['iptm'],3)))


def read_a3m(name, a3m_files):
    # ColabFold, RosettaFold-All-Atom, Boltz-1
    for a3m_file in a3m_files:
        int_seqs = a3m_to_int(a3m_file)
        write_tsv(f"{name}_msa.tsv", format_msa_rows(int_seqs))

def read_npz(name, npz_files):
   for idx, npz_file in enumerate(npz_files):
        data = np.load(npz_file)
       #Boltz PAE files if --write_full_pae is used
        if npz_file.split('/')[-1].startswith('pae') and npz_file.endswith('.npz'):
            write_tsv(f"{name}_{idx}_pae.tsv", format_pae_rows(data["pae"]))

def read_json(name, json_files):
    for idx, json_file in enumerate(json_files):
        with open(json_file, 'r') as f:
            data = json.load(f)
            if json_file.endswith("_data.json"): #AF3 output with MSA info
                # Can't just used format_msa_rows since there's FASTA headers in the json content
                unpaired_MSAs = data['sequences'][0]['protein']['unpairedMsa']
                msa_lines = [line for line in unpaired_MSAs.split("\n") if not line.startswith(">") and line.strip()]
                msa_rows = [[str(AA_to_int.get(residue, 20)) for residue in line] for line in msa_lines]
                write_tsv(f"{name}_msa.tsv", msa_rows)
            #AF3 output with PAE info, or HF3 PAE data. TODO: Need to make sure the workflow points to [protein]/[protein]_rank1/all_results.json

        # TODO: I think I need to capture model_id and inference_id
            if '_alphafold2_ptm_model_' in json_file: # ColabFold, multimer or monomer
            # Might want to cut more if I just want ${meta.id}_[metric].tsv
                model_id = os.path.basename(json_file)
                print(model_id)
            if 'all_results' in json_file: # Individual predictions in HF3
                # TODO: iPTM is 0 in some HF3 files. Check that's just no the one case
                model_id = os.path.dirname(json_file).split('-rank')[1] #Use re-ranked output
            if 'predictions' in json_file: # Boltz-1 confnameences in predictions/[protein]/confidence_[protein]_model_*.json
            # TODO: haven't tested this for multiple models with --diffusion_samples
                model_id = os.path.basename(json_file).split('_model_')[1]

            if "pae" not in data.keys():
                print(f"No PAE output in {json_file}, it was likely a monomer calculation")
            else:
                write_tsv(f"{name}_{idx}_pae.tsv", format_pae_rows(data["pae"]))

def read_pt(name, pt_files):
    import torch # moved to a conditional import since too bulky import if not used
    for pt_file in pt_files:
        with open(pt_file, 'rb') as f:   # TODO: point to [protein]_aux.pt
            data = torch.load(f, map_location="cpu")
            if 'pae' in data:
                # The pt file contains a tensor that needs to be cast as an array
                # Squeeze leading dimension (batch?)
                write_tsv(f"{name}_pae.tsv", format_pae_rows(np.squeeze(data["pae"].numpy())))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pkls", dest="pkls", required=False, nargs="+") # For reading both HelixFold3 and AlphaFold2 MSA formats
    parser.add_argument("--npzs", dest="npzs", required=False, nargs="+") # For reading the Boltz-1 PAE formats. TODO: Boltz-1 MSA not implemented (go straight to .a3m file), implement
    parser.add_argument("--a3ms", dest="a3ms", required=False, nargs="+") # For reading the RosettaFold-All-Atom, ColabFold, and Boltz-1 MSA formats
    parser.add_argument("--jsons", dest="jsons", required=False, nargs="+") # For reading the AF3 MSA & PAE, HF3 PAE
    parser.add_argument("--pts", dest="pts", required=False, nargs="+") # For read RFAA pytorch model to get PAE data
    parser.add_argument("--structs", dest="structs", required=False, nargs="+")
    parser.add_argument("--name", default="untitled", dest="name") # might need a --name $meta.id
    args = parser.parse_args()

    if args.pkls:
        read_pkl(args.name, args.pkls)
    if args.a3ms:
        read_a3m(args.name, args.a3ms)
    if args.npzs:
        read_npz(args.name, args.npzs)
    if args.jsons:
        read_json(args.name, args.jsons)
    if args.pts:
        read_pt(args.name, args.pts)
    if args.structs:
        extract_structs_plddt_to_tsv(args.name, args.structs)

if __name__ == "__main__":
    main()
