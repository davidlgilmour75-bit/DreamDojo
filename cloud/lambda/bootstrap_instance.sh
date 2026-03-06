#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/davidlgilmour75-bit/DreamDojo.git}"
REPO_DIR="${REPO_DIR:-$HOME/DreamDojo}"
BRANCH="${BRANCH:-main}"
FORCE_INSTALL="${FORCE_INSTALL:-0}"

if [ -d /lambda/nfs ]; then
  STORAGE_ROOT_DEFAULT="/lambda/nfs/dreamdojo"
else
  STORAGE_ROOT_DEFAULT="$HOME/dreamdojo-storage"
fi
STORAGE_ROOT="${DREAMDOJO_STORAGE_ROOT:-$STORAGE_ROOT_DEFAULT}"

mkdir -p "$STORAGE_ROOT"/{datasets,checkpoints,outputs,hf_cache}

echo "[1/4] Clone or update repo"
if [ -d "$REPO_DIR/.git" ]; then
  git -C "$REPO_DIR" fetch origin
  git -C "$REPO_DIR" checkout "$BRANCH"
  git -C "$REPO_DIR" pull --ff-only origin "$BRANCH"
else
  git clone "$REPO_URL" "$REPO_DIR"
  git -C "$REPO_DIR" checkout "$BRANCH"
fi

echo "[2/4] Install DreamDojo environment"
cd "$REPO_DIR"
if [ ! -d .venv ] || [ "$FORCE_INSTALL" = "1" ]; then
  bash install.sh
else
  echo "  .venv already exists, skipping install (set FORCE_INSTALL=1 to reinstall)"
fi

echo "[3/4] Write cloud env file"
ENV_FILE="$REPO_DIR/.dreamdojo-cloud.env"
cat > "$ENV_FILE" <<EOF
export REPO_ROOT="$REPO_DIR"
export DREAMDOJO_STORAGE_ROOT="$STORAGE_ROOT"
export HF_HOME="${HF_HOME:-$STORAGE_ROOT/hf_cache}"
export IMAGINAIRE_OUTPUT_ROOT="${IMAGINAIRE_OUTPUT_ROOT:-$STORAGE_ROOT/outputs/training}"
export CHECKPOINTS_DIR="${CHECKPOINTS_DIR:-$STORAGE_ROOT/checkpoints}"
export SAVE_DIR="${SAVE_DIR:-$STORAGE_ROOT/outputs/eval}"
export DATASET_ROOT="${DATASET_ROOT:-$STORAGE_ROOT/datasets/PhysicalAI-Robotics-GR00T-Teleop-GR1}"
export TRAIN_DATASET_PATH="${TRAIN_DATASET_PATH:-$STORAGE_ROOT/datasets/PhysicalAI-Robotics-GR00T-Teleop-GR1/GR1_robot}"
export EVAL_DATASET_PATH="${EVAL_DATASET_PATH:-$STORAGE_ROOT/datasets/PhysicalAI-Robotics-GR00T-Teleop-GR1/GR1_robot}"
export NNODES="${NNODES:-1}"
export NPROC="${NPROC:-8}"
export MASTER_ADDR="${MASTER_ADDR:-127.0.0.1}"
export MASTER_PORT="${MASTER_PORT:-12341}"
export NODE_RANK="${NODE_RANK:-0}"
export WANDB_MODE="${WANDB_MODE:-online}"
EOF

echo "[4/4] Done"
echo
cat <<EONEXT
Next steps:
  cd "$REPO_DIR"
  source .dreamdojo-cloud.env

  # (optional) add your W&B key for online logging
  export WANDB_API_KEY=<your_key>

  # First training run command pack:
  bash cloud/lambda/run_train.sh dreamdojo_2b_480_640_pretrain

  # First eval run command pack:
  bash cloud/lambda/run_eval.sh
EONEXT
