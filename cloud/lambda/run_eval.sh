#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

if [ -f "$REPO_ROOT/.dreamdojo-cloud.env" ]; then
  # shellcheck disable=SC1091
  source "$REPO_ROOT/.dreamdojo-cloud.env"
fi

export HF_HOME="${HF_HOME:-$REPO_ROOT/.cache/huggingface}"
export CHECKPOINTS_DIR="${CHECKPOINTS_DIR:-$REPO_ROOT/checkpoints}"
export SAVE_DIR="${SAVE_DIR:-$REPO_ROOT/outputs/eval}"
export EVAL_DATASET_PATH="${EVAL_DATASET_PATH:-$REPO_ROOT/datasets/PhysicalAI-Robotics-GR00T-Teleop-GR1/GR1_robot}"
export EXPERIMENT="${EXPERIMENT:-dreamdojo_2b_480_640_gr1}"
export NUM_FRAMES="${NUM_FRAMES:-49}"
export NUM_SAMPLES="${NUM_SAMPLES:-100}"
export DATA_SPLIT="${DATA_SPLIT:-test}"
export CHECKPOINT_INTERVAL="${CHECKPOINT_INTERVAL:-5000}"
export DETERMINISTIC_UNIFORM_SAMPLING="${DETERMINISTIC_UNIFORM_SAMPLING:-1}"
export INFINITE="${INFINITE:-0}"

mkdir -p "$HF_HOME" "$SAVE_DIR"

if [ -f "$REPO_ROOT/.venv/bin/activate" ]; then
  # shellcheck disable=SC1091
  source "$REPO_ROOT/.venv/bin/activate"
fi

echo "Launching evaluation"
echo "  experiment: $EXPERIMENT"
echo "  checkpoints_dir: $CHECKPOINTS_DIR"
echo "  save_dir: $SAVE_DIR"
echo "  dataset_path: $EVAL_DATASET_PATH"

cd "$REPO_ROOT"
CHECKPOINTS_DIR="$CHECKPOINTS_DIR" \
SAVE_DIR="$SAVE_DIR" \
DATASET_PATH="$EVAL_DATASET_PATH" \
EXPERIMENT="$EXPERIMENT" \
NUM_FRAMES="$NUM_FRAMES" \
NUM_SAMPLES="$NUM_SAMPLES" \
DATA_SPLIT="$DATA_SPLIT" \
CHECKPOINT_INTERVAL="$CHECKPOINT_INTERVAL" \
DETERMINISTIC_UNIFORM_SAMPLING="$DETERMINISTIC_UNIFORM_SAMPLING" \
INFINITE="$INFINITE" \
bash eval.sh "$@"
