FROM python:3.13.3-slim-bookworm AS builder

WORKDIR /app

RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --upgrade pip --no-cache-dir

COPY requirements.txt .
RUN /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

COPY . .

FROM python:3.13.3-slim-bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    apt-get upgrade -y && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN groupadd -r appgroup && useradd -r -g appgroup appuser

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app /app

ENV PATH="/opt/venv/bin:$PATH"

RUN chown -R appuser:appgroup /app /opt/venv

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/ || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]