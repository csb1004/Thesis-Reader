FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app

WORKDIR /app

COPY services/converter/requirements.txt services/converter/requirements.txt
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r services/converter/requirements.txt

COPY services services

CMD ["sh", "-c", "uvicorn services.converter.app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
