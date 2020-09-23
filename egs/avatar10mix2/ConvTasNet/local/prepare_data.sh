#!/bin/bash

storage_dir=/mnt/scratch07/hushell/UploadAI/datasets
n_src=2
python_path=python

#. ./utils/parse_options.sh

#current_dir=$(pwd)
# Clone LibriMix repo
#git clone https://github.com/JorisCos/LibriMix

# Run generation script
#cd LibriMix
#. generate_librimix.sh $storage_dir

#cd $current_dir
$python_path local/create_local_metadata.py --librimix_dir $storage_dir/Avatar10Mix$n_src

