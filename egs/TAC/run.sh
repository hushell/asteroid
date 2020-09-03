#!/bin/bash

# Exit on error
set -e
set -o pipefail

# Main storage directory where dataset will be stored
storage_dir=/media/sam/ee430d77-96af-4264-8a84-1e24f308bd27/TAC/adhoc/ #./datasets

librispeech_dir=$storage_dir/LibriSpeech #$storage_dir/LibriSpeech
noise_dir=$storage_dir/Nonspeech #$storage_dir/rir_data
# After running the recipe a first time, you can run it from stage 3 directly to train new models.

# Path to the python you'll use for the experiment. Defaults to the current python
# You can run ./utils/prepare_python_env.sh to create a suitable python environment, paste the output here.
python_path=python

# Example usage
# ./run.sh --stage 3 --tag my_tag --task sep_noisy --id 0,1

# General
stage=0  # Controls from which stage to start
tag=""  # Controls the directory name associated to the experiment
# You can ask for several GPUs using id (passed to CUDA_VISIBLE_DEVICES)
id=$CUDA_VISIBLE_DEVICES

# Dataset option
dataset_type=adhoc

. utils/parse_options.sh

dumpdir=data/$suffix  # directory to put generated json file

# Install pysndfx if not instaled
if not python -c "import gpuRIR" &> /dev/null; then
  echo 'This recipe requires gpuRIR. Please install gpuRIR.'
fi

if [[ $stage -le  0 ]]; then
  echo "Stage 0: Downloading required Datasets"

  if ! test -e $librispeech_dir/train-clean-100; then
    echo "Downloading LibriSpeech/train-clean-100 into $storage_dir"
    wget -c --tries=0 --read-timeout=20 http://www.openslr.org/resources/12/train-clean-100.tar.gz -P $storage_dir
	  tar -xzf $storage_dir/train-clean-100.tar.gz -C $storage_dir
	  rm -rf $storage_dir/train-clean-100.tar.gz
	fi

  if ! test -e $librispeech_dir/dev-clean; then
    echo "Downloading LibriSpeech/dev-clean into $storage_dir"
	  wget -c --tries=0 --read-timeout=20 http://www.openslr.org/resources/12/dev-clean.tar.gz -P $storage_dir
	  tar -xzf $storage_dir/dev-clean.tar.gz -C $storage_dir
	  rm -rf $storage_dir/dev-clean.tar.gz
	fi

  if ! test -e $librispeech_dir/test-clean; then
    echo "Downloading LibriSpeech/dev-clean into $storage_dir"
	  wget -c --tries=0 --read-timeout=20 http://www.openslr.org/resources/12/test-clean.tar.gz -P $storage_dir
	  tar -xzf $storage_dir/test-clean.tar.gz -C $storage_dir
	  rm -rf $storage_dir/test-clean.tar.gz
	fi

  if ! test -e $storage_dir/Nonspeech; then
       echo "Downloading Noises into $storage_dir"
	  wget -c --tries=0 --read-timeout=20 http://web.cse.ohio-state.edu/pnl/corpus/HuNonspeech/Nonspeech.zip -P $storage_dir
	  unzip $storage_dir/Nonspeech.zip -d $storage_dir
	  rm -rf $storage_dir/Nonspeech.zip
  fi

fi

if [[ $stage -le  1 ]]; then
  echo "Stage 1: Creating Synthetic Datasets"
  $python_path local/create_dataset.py \
                --output-path=$(readlink -m $storage_dir) \
		--dataset=$dataset_type \
		--libri-path=$(readlink -m $librispeech_dir) \
		--noise-path=$(readlink -m $noise_dir)
fi

if [[ $stage -le 2 ]]; then
  echo "Parsing dataset to json to speed up subsequent experiments"
  for split in train validation test; do
  $python_path local/parse_data.py --in_dir $storage_dir/MC_Libri_${dataset_type}/$split --out_json $dumpdir/${split}.json
  done
fi

# Generate a random ID for the run if no tag is specified
uuid=$($python_path -c 'import uuid, sys; print(str(uuid.uuid4())[:8])')
if [[ -z ${tag} ]]; then
	tag=${uuid}
fi
expdir=exp/train_TAC_${tag}
mkdir -p $expdir && echo $uuid >> $expdir/run_uuid.txt
echo "Results from the following experiment will be stored in $expdir"

if [[ $stage -le 3 ]]; then
  echo "Stage 3: Training"
  mkdir -p logs
  CUDA_VISIBLE_DEVICES=$id $python_path train.py \
		--train_json $dumpdir/train.json \
		--dev_json $dumpdir/validation.json \
		--exp_dir ${expdir}/ | tee logs/train_${tag}.log
	cp logs/train_${tag}.log $expdir/train.log

	# Get ready to publish
	mkdir -p $expdir/publish_dir
	echo "TAC" > $expdir/publish_dir/recipe_name.txt
fi