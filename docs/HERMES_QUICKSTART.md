# DreamDojo quickstart (Hermes implementation)

This fork includes launcher scripts that are no longer hardcoded to a specific internal NVIDIA path.

## What was implemented

- `launch.sh` now uses repo-relative defaults and env overrides.
- `eval.sh` now uses repo-relative defaults and env overrides.
- Both scripts auto-use `.venv` when present.
- Both scripts support custom paths entirely through environment variables.

## 1) Clone your fork

```bash
git clone https://github.com/davidlgilmour75-bit/DreamDojo.git
cd DreamDojo
```

## 2) Environment setup

### Linux + NVIDIA GPU (recommended for real runs)

```bash
bash install.sh
```

### macOS / non-NVIDIA (dev-only)

DreamDojo training/inference in this repo is designed for CUDA + multi-GPU and is not expected to run fully on Apple Silicon. You can still use this machine for:

- repo setup
- config editing
- script authoring
- preparing dataset/checkpoint paths

## 3) Training launch (GPU machine)

```bash
# required
export WANDB_API_KEY=<your_wandb_key_if_logging_enabled>

# optional overrides
export HF_HOME=$PWD/.cache/huggingface
export IMAGINAIRE_OUTPUT_ROOT=$PWD/outputs/training
export NNODES=1
export NPROC=8

# example
bash launch.sh dreamdojo_2b_480_640_pretrain
```

## 4) Evaluation launch

```bash
export CHECKPOINTS_DIR=$PWD/checkpoints
export SAVE_DIR=$PWD/outputs/eval
export DATASET_PATH=$PWD/datasets/PhysicalAI-Robotics-GR00T-Teleop-GR1/GR1_robot

bash eval.sh
```

## 5) Useful runtime overrides

- `WANDB_MODE=online|offline|disabled`
- `MASTER_ADDR`, `MASTER_PORT`, `NODE_RANK`
- `NUM_FRAMES`, `NUM_SAMPLES`, `DATA_SPLIT`
- `INFINITE=1` for checkpoint polling in eval
- `DETERMINISTIC_UNIFORM_SAMPLING=1`

## Notes

- Upstream docs still apply for model/data specifics:
  - `docs/SETUP.md`
  - `docs/LAM.md`
  - `docs/PRETRAIN.md`
  - `docs/POSTTRAIN.md`
  - `docs/EVAL.md`
