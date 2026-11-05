#!/bin/sh
set -eu

: "${MODEL_PATH:=/models/qwen2.5-0.5b-instruct}"
: "${SERVED_MODEL_NAME:=qwen2.5-0.5b-instruct}"
: "${API_ACCESS_TOKEN:?API_ACCESS_TOKEN must be set from Kubernetes Secret}"
: "${MAX_MODEL_LEN:=2048}"
: "${MAX_NUM_SEQS:=4}"
: "${CPU_OMP_THREADS:=4}"
: "${CPU_KVCACHE_SPACE:=4}"

export VLLM_CPU_OMP_THREADS_BIND=0
export OMP_NUM_THREADS="${CPU_OMP_THREADS}"
export VLLM_CPU_KVCACHE_SPACE="${CPU_KVCACHE_SPACE}"

exec vllm serve "${MODEL_PATH}" \
  --host 0.0.0.0 \
  --port 8000 \
  --api-key "${API_ACCESS_TOKEN}" \
  --served-model-name "${SERVED_MODEL_NAME}" \
  --dtype float32 \
  --max-model-len "${MAX_MODEL_LEN}" \
  --max-num-seqs "${MAX_NUM_SEQS}" \
  --tensor-parallel-size 1 \
  --load-format safetensors \
  --disable-log-requests \
  --middleware privacy_logging.RequestAuditMiddleware
