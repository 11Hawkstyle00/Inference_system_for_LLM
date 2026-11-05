ARG VLLM_VERSION=0.27.0
FROM vllm/vllm-openai-cpu:v${VLLM_VERSION}-x86_64

USER root
WORKDIR /opt/llm-app

COPY requirements.txt ./requirements.txt
COPY app/ ./app/
COPY --chmod=0555 app/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN python -c "import vllm; assert vllm.__version__ == '${VLLM_VERSION}', vllm.__version__" \
    && python -m pip check \
    && mkdir -p /tmp/vllm-cache /home/nonroot/.cache \
    && chown -R 10001:10001 /opt/llm-app /tmp/vllm-cache /home/nonroot

ENV HOME=/home/nonroot \
    PYTHONPATH=/opt/llm-app/app \
    HF_HOME=/tmp/vllm-cache \
    VLLM_LOGGING_LEVEL=INFO \
    PYTHONUNBUFFERED=1

USER 10001:10001
EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
