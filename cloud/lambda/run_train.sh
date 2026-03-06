#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

if [ -f "$REPO_ROOT/.dreamdojo-cloud.env" ]; then
  # shellcheck disable=SC1091
  source "$REPO_ROOT/.dreamdojo-cloud.env"
fi

if [ "$#" -lt 1 ]; then
  echo "Usage: bash cloud/lambda/run_train.sh <experiment> [extra hydra args ...]"
  echo "Example: bash cloud/lambda/run_train.sh dreamdojo_2b_480_640_pretrain"
  exit 1
fi

EXPERIMENT="$1"
shift || true

# Derive GPU count for sensible default NPROC
GPU_COUNT=1
if command -v nvidia-smi >/dev/null 2>&1; then
  GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | wc -l | tr -d ' ')
  if [ -z "$GPU_COUNT" ] || [ "$GPU_COUNT" = "0" ]; then
    GPU_COUNT=1
  fi
fi

export NNODES="${NNODES:-1}"
export NPROC="${NPROC:-$GPU_COUNT}"
export MASTER_ADDR="${MASTER_ADDR:-127.0.0.1}"
export MASTER_PORT="${MASTER_PORT:-12341}"
export NODE_RANK="${NODE_RANK:-0}"
export WANDB_MODE="${WANDB_MODE:-online}"
export HF_HOME="${HF_HOME:-$REPO_ROOT/.cache/huggingface}"
export IMAGINAIRE_OUTPUT_ROOT="${IMAGINAIRE_OUTPUT_ROOT:-$REPO_ROOT/outputs/training}"
export TRAIN_DATASET_PATH="${TRAIN_DATASET_PATH:-$REPO_ROOT/datasets/PhysicalAI-Robotics-GR00T-Teleop-GR1/GR1_robot}"

mkdir -p "$HF_HOME" "$IMAGINAIRE_OUTPUT_ROOT"

if [ -f "$REPO_ROOT/.venv/bin/activate" ]; then
  # shellcheck disable=SC1091
  source "$REPO_ROOT/.venv/bin/activate"
fi

echo "Launching training"
echo "  experiment: $EXPERIMENT"
echo "  repo_root: $REPO_ROOT"
echo "  train_dataset_path: $TRAIN_DATASET_PATH"
echo "  output_root: $IMAGINAIRE_OUTPUT_ROOT"
echo "  nnodes/nproc: $NNODES x $NPROC"

overrides=(
  "dataloader_train.dataset.dataset_path=$TRAIN_DATASET_PATH"
  "dataloader_train.dataset.data_split=train"
)

cd "$REPO_ROOT"
bash launch.sh "$EXPERIMENT" "${overrides[@]}" "$@"
