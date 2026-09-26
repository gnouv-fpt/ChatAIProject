FROM python:3.10-slim

WORKDIR /app

# Install system dependencies if required
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Generate gRPC protobuf code
RUN python generate_protos.py

EXPOSE 50051

ENV PYTHONUNBUFFERED=1
ENV GRPC_PORT=50051

CMD ["python", "server.py"]
