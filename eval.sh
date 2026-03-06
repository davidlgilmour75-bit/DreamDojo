#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PYTHONPATH="${PROJECT_ROOT}:${PYTHONPATH:-}"
export HF_HOME="${HF_HOME:-${PROJECT_ROOT}/.cache/huggingface}"

VENV_PATH="${VENV_PATH:-${PROJECT_ROOT}/.venv}"
if [ -f "${VENV_PATH}/bin/activate" ]; then
  # shellcheck disable=SC1090
  source "${VENV_PATH}/bin/activate"
fi

OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/outputs/action_conditioned/basic}"
CHECKPOINTS_DIR="${CHECKPOINTS_DIR:-${PROJECT_ROOT}/checkpoints}"
EXPERIMENT="${EXPERIMENT:-dreamdojo_2b_480_640_gr1}"
SAVE_DIR="${SAVE_DIR:-${PROJECT_ROOT}/outputs/eval}"
NUM_FRAMES="${NUM_FRAMES:-49}"
NUM_SAMPLES="${NUM_SAMPLES:-100}"
DATASET_PATH="${DATASET_PATH:-${PROJECT_ROOT}/datasets/PhysicalAI-Robotics-GR00T-Teleop-GR1/GR1_robot}"
DATA_SPLIT="${DATA_SPLIT:-test}"
CHECKPOINT_INTERVAL="${CHECKPOINT_INTERVAL:-5000}"
INFINITE="${INFINITE:-0}"
DETERMINISTIC_UNIFORM_SAMPLING="${DETERMINISTIC_UNIFORM_SAMPLING:-1}"

mkdir -p "${OUTPUT_DIR}" "${SAVE_DIR}" "${HF_HOME}"

echo "Running DreamDojo evaluation"
echo "  project_root:    ${PROJECT_ROOT}"
echo "  experiment:      ${EXPERIMENT}"
echo "  checkpoints_dir: ${CHECKPOINTS_DIR}"
echo "  save_dir:        ${SAVE_DIR}"
echo "  dataset_path:    ${DATASET_PATH}"

args=(
  -o "${OUTPUT_DIR}"
  --checkpoints-dir "${CHECKPOINTS_DIR}"
  --experiment "${EXPERIMENT}"
  --save-dir "${SAVE_DIR}"
  --num-frames "${NUM_FRAMES}"
  --num-samples "${NUM_SAMPLES}"
  --dataset-path "${DATASET_PATH}"
  --data-split "${DATA_SPLIT}"
  --checkpoint-interval "${CHECKPOINT_INTERVAL}"
)

if [ "${DETERMINISTIC_UNIFORM_SAMPLING}" = "1" ]; then
  args+=(--deterministic-uniform-sampling)
fi

if [ "${INFINITE}" = "1" ]; then
  args+=(--infinite)
fi

python examples/action_conditioned.py "${args[@]}" "$@"
