#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NNODES="${NNODES:-1}"
NPROC="${NPROC:-8}"
MASTER_ADDR="${MASTER_ADDR:-localhost}"
MASTER_PORT="${MASTER_PORT:-12341}"
NODE_RANK="${NODE_RANK:-0}"
SEED="${SEED:-42}"

export TORCH_NCCL_ENABLE_MONITORING="${TORCH_NCCL_ENABLE_MONITORING:-0}"
export TORCH_NCCL_HEARTBEAT_TIMEOUT_SEC="${TORCH_NCCL_HEARTBEAT_TIMEOUT_SEC:-1800}"
export PYTORCH_CUDA_ALLOC_CONF="${PYTORCH_CUDA_ALLOC_CONF:-expandable_segments:True}"
export FI_EFA_USE_DEVICE_RDMA="${FI_EFA_USE_DEVICE_RDMA:-1}"
export RDMAV_FORK_SAFE="${RDMAV_FORK_SAFE:-1}"
export TORCH_DIST_INIT_BARRIER="${TORCH_DIST_INIT_BARRIER:-1}"

# CUDA runtime compatibility defaults
export CUDA_MODULE_LOADING="${CUDA_MODULE_LOADING:-LAZY}"

export OMP_NUM_THREADS="${OMP_NUM_THREADS:-8}"
export PYTHONPATH="${PROJECT_ROOT}:${PYTHONPATH:-}"
export HF_HOME="${HF_HOME:-${PROJECT_ROOT}/.cache/huggingface}"
export IMAGINAIRE_OUTPUT_ROOT="${IMAGINAIRE_OUTPUT_ROOT:-${PROJECT_ROOT}/outputs/training}"

VENV_PATH="${VENV_PATH:-${PROJECT_ROOT}/.venv}"
if [ -f "${VENV_PATH}/bin/activate" ]; then
  # shellcheck disable=SC1090
  source "${VENV_PATH}/bin/activate"
fi

if [ "$#" -lt 1 ]; then
  echo "Usage: bash launch.sh <experiment_name> [extra hydra args ...]"
  echo "Example: bash launch.sh dreamdojo_2b_480_640_pretrain"
  exit 1
fi

CONFIG_NAME="$1"
shift || true

WANDB_MODE="${WANDB_MODE:-disabled}"
if [ -n "${WANDB_API_KEY:-}" ] && [ "${WANDB_MODE}" = "disabled" ]; then
  WANDB_MODE="online"
fi

mkdir -p "${HF_HOME}" "${IMAGINAIRE_OUTPUT_ROOT}"

echo "Running DreamDojo training"
echo "  project_root: ${PROJECT_ROOT}"
echo "  config:       ${CONFIG_NAME}"
echo "  nodes/proc:   ${NNODES} x ${NPROC}"
echo "  master:       ${MASTER_ADDR}:${MASTER_PORT}"
echo "  wandb_mode:   ${WANDB_MODE}"
echo "  output_root:  ${IMAGINAIRE_OUTPUT_ROOT}"

torchrun \
  --nnodes="${NNODES}" \
  --nproc_per_node="${NPROC}" \
  --master_port="${MASTER_PORT}" \
  --master_addr="${MASTER_ADDR}" \
  --node_rank="${NODE_RANK}" \
  -m scripts.train \
  --config=cosmos_predict2/_src/predict2/action/configs/action_conditioned/config.py -- \
  experiment="${CONFIG_NAME}" \
  job.seed="${SEED}" \
  job.wandb_mode="${WANDB_MODE}" \
  ~dataloader_train.dataloaders \
  "$@"
