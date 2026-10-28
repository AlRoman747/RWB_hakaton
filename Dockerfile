FROM python:3.12.6-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt requirements-dev.txt ./
RUN pip install --no-cache-dir -r requirements-dev.txt

COPY scripts scripts
COPY model model
COPY queries queries
COPY tests tests

RUN useradd --uid 10001 --create-home appuser \
    && chown -R appuser:appuser /app
USER appuser

CMD ["python", "-m", "scripts.load_data"]
