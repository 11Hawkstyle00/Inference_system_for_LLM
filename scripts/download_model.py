import os
from pathlib import Path

from huggingface_hub import snapshot_download

model_id = os.getenv("MODEL_ID", "Qwen/Qwen2.5-0.5B-Instruct")
model_dir = Path(os.getenv("MODEL_PATH", "/models/qwen2.5-0.5b-instruct"))
token = os.getenv("HF_TOKEN")

model_dir.mkdir(parents=True, exist_ok=True)

if (model_dir / "config.json").is_file() and any(model_dir.glob("*.safetensors")):
    print("Model files already exist in the persistent volume; download skipped.")
else:
    print(f"Downloading model {model_id} to persistent volume.")
    snapshot_download(
        repo_id=model_id,
        local_dir=str(model_dir),
        token=token or None,
        resume_download=True,
    )
    if not (model_dir / "config.json").is_file():
        raise RuntimeError("Download finished but config.json is missing.")
    if not any(model_dir.glob("*.safetensors")):
        raise RuntimeError("Download finished but safetensors weights are missing.")
    print("Model download completed.")
