# Lambda GPU runbook (DreamDojo)

This runbook gives you a direct path from fresh Lambda GPU instance to first DreamDojo train/eval runs.

## 0) Launch instance

Recommended starter shape for first run:
- 1x H100 or 1x A100 (for smoke test)
- 8x H100 (for real throughput)

Attach a persistent filesystem in the same region so checkpoints/data survive restarts.

## 1) SSH in

```bash
ssh ubuntu@<instance-ip>
```

## 2) Bootstrap DreamDojo on the instance

```bash
git clone https://github.com/davidlgilmour75-bit/DreamDojo.git
cd DreamDojo
bash cloud/lambda/bootstrap_instance.sh
source .dreamdojo-cloud.env
```

## 3) Set logging key (optional but recommended)

```bash
export WANDB_API_KEY=<your_wandb_key>
export WANDB_MODE=online
```

## 4) Dataset placement

Expected path by default:

```text
$DREAMDOJO_STORAGE_ROOT/datasets/PhysicalAI-Robotics-GR00T-Teleop-GR1/GR1_robot
```

If your dataset is elsewhere, override before launch:

```bash
export TRAIN_DATASET_PATH=/path/to/your/train_dataset
export EVAL_DATASET_PATH=/path/to/your/eval_dataset
```

## 5) First training command pack

### 5.1 Pretraining (2B)

```bash
cd ~/DreamDojo
source .dreamdojo-cloud.env
bash cloud/lambda/run_train.sh dreamdojo_2b_480_640_pretrain
```

### 5.2 Post-training (GR1)

```bash
cd ~/DreamDojo
source .dreamdojo-cloud.env
bash cloud/lambda/run_train.sh dreamdojo_2b_480_640_gr1
```

### 5.3 Post-training variants

```bash
bash cloud/lambda/run_train.sh dreamdojo_2b_480_640_g1
bash cloud/lambda/run_train.sh dreamdojo_2b_480_640_agibot
bash cloud/lambda/run_train.sh dreamdojo_2b_480_640_yam
```

## 6) Evaluation command pack

```bash
cd ~/DreamDojo
source .dreamdojo-cloud.env
bash cloud/lambda/run_eval.sh
```

You can override eval settings inline:

```bash
EXPERIMENT=dreamdojo_2b_480_640_gr1 \
NUM_SAMPLES=20 \
DATA_SPLIT=test \
INFINITE=0 \
bash cloud/lambda/run_eval.sh
```

## 7) Common knobs

```bash
# Distributed process count (defaults to detected GPU count)
export NPROC=8

# Training outputs + checkpoints
export IMAGINAIRE_OUTPUT_ROOT=/lambda/nfs/dreamdojo/outputs/training
export CHECKPOINTS_DIR=/lambda/nfs/dreamdojo/checkpoints

# Hugging Face cache
export HF_HOME=/lambda/nfs/dreamdojo/hf_cache
```

## 8) Notes

- This repo’s training flow targets Linux + NVIDIA CUDA.
- Your local Mac is ideal for editing/orchestration, while Lambda handles actual training.
- For long runs, keep all mutable data under the persistent filesystem path.
