FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml ./

RUN pip install uv

RUN uv pip install --system -r pyproject.toml

COPY . .

EXPOSE 8000

CMD ["python", "main.py"]
