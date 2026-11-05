# CPU LLM inference on Kubernetes with vLLM

Решение тестового задания Data Engineer. Используются vLLM на CPU, PVC для весов, 
Secret для токенов и ConfigMap для параметров запуска.

Реализован бонус 2: загрузка модели вынесена в отдельный rootless `initContainer`, 
собранный из `docker/Dockerfile.downloader`.

## Структура

```text
Dockerfile
requirements.txt
requirements-downloader.txt
docker/Dockerfile.downloader
app/entrypoint.sh
app/privacy_logging.py
scripts/download_model.py
k8s/{namespace,configmap,deployment,service}.yaml
```

## Архитектура
* initContainer проверяет PVC. Если весов нет, скачивает модель из Hugging Face в `/models/qwen2.5-0.5b-instruct`.
* Основной контейнер монтирует тот же PVC read-only и запускает vLLM по локальному пути. 
* API защищён Bearer-токеном через параметр `--api-key`.
* ConfigMap управляет параметрами vLLM. Secret передаёт HF_TOKEN в initContainer и API_ACCESS_TOKEN в основной контейнер.
* Middleware пишет только HTTP method/path для `/v1/*`. Тело запроса не читается и не логируется.


Основной образ использует `vllm/vllm-openai-cpu:v0.27.0-x86_64`. 

## Сборка образов

Из корня проекта:
```bash
docker build -t vllm-cpu:0.27.0 -f Dockerfile .
docker build -t model-downloader:0.1.0 -f docker/Dockerfile.downloader .
```

Для Minikube:
```bash
eval "$(minikube docker-env)"
docker build -t vllm-cpu:0.27.0 -f Dockerfile .
docker build -t model-downloader:0.1.0 -f docker/Dockerfile.downloader .
```

## Secret

```bash
kubectl create namespace llm-inference
kubectl -n llm-inference create secret generic llm-secrets --from-literal=API_ACCESS_TOKEN=' '
```
> сгенерировать из openssl rand -hex 32

## Деплой

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

kubectl -n llm-inference get pods
kubectl -n llm-inference logs deployment/vllm-cpu -c model-downloader
kubectl -n llm-inference logs deployment/vllm-cpu -c vllm
```

При первом старте initContainer скачает веса в PVC. При рестарте скрипт обнаружит config.json и *.safetensors и пропустит скачивание.

Локальный запрос:
```bash
kubectl -n llm-inference port-forward service/vllm 8000:8000
```

терминал 2:
```bash
export API_ACCESS_TOKEN='из Secret'

curl http://127.0.0.1:8000/v1/models   -H "Authorization: Bearer ${API_ACCESS_TOKEN}"

curl http://127.0.0.1:8000/v1/chat/completions   -H "Authorization: Bearer ${API_ACCESS_TOKEN}"   -H "Content-Type: application/json"   -d '{
    "model": "qwen2.5-0.5b-instruct",
    "messages": [{"role": "user", "content": "Кратко объясни, что такое Kubernetes."}],
    "max_tokens": 100
  }'
```

## Конфигурация

`k8s/configmap.yaml` содержит `MODEL_ID`, `MODEL_PATH`, `SERVED_MODEL_NAME`, `MAX_MODEL_LEN`, `MAX_NUM_SEQS`, `CPU_OMP_THREADS`, `CPU_KVCACHE_SPACE`.

После изменения ConfigMap:
```bash
kubectl apply -f k8s/configmap.yaml
kubectl -n llm-inference rollout restart deployment/vllm-cpu
```

## Безопасность и логирование
- Оба прикладных контейнера запускаются как UID/GID 10001, без privilege escalation и Linux capabilities.
- Основной контейнер использует read-only root filesystem.
- `--disable-log-requests` отключает подробное логирование запросов vLLM.
- `RequestAuditMiddleware` пишет только method/path, не читая request body.
- Токены передаются из Kubernetes Secret, не из ConfigMap.
- PVC сохраняет веса между пересозданиями Pod.

## Проверки

```bash
kubectl -n llm-inference get pvc,svc,pods
kubectl -n llm-inference exec deployment/vllm-cpu -c vllm --   python -c 'import vllm; print(vllm.__version__)'
```

__Cсылка на репозиторий сохранена в файле repo.txt__
