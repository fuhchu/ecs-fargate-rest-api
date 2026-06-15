# syntax=docker/dockerfile:1
#
# Production Dockerfile for the Items API.
#
# This is a MULTI-STAGE build. Stage 1 ("builder") installs the Python
# dependencies. Stage 2 (the final image) copies ONLY the finished result.
# The build tools and caches used to install packages never make it into the
# shipped image -> smaller image, smaller attack surface.

# ---------------------------------------------------------------------------
# Stage 1: builder — install dependencies into an isolated virtual environment
# ---------------------------------------------------------------------------
FROM python:3.13-slim AS builder

# Create a virtual environment we can later copy wholesale into the final
# image. Because both stages use the *same* base image, the venv is portable
# between them.
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app

# Copy ONLY requirements first, then install. Docker caches each layer; as long
# as requirements.txt is unchanged, this expensive install layer is reused even
# when your application code changes. Big speed win on rebuilds.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---------------------------------------------------------------------------
# Stage 2: final runtime image — lean, and runs as a non-root user
# ---------------------------------------------------------------------------
FROM python:3.13-slim

# PYTHONDONTWRITEBYTECODE: don't litter the image with .pyc files.
# PYTHONUNBUFFERED: send logs straight to stdout/stderr with no buffering, so
#   CloudWatch (Milestone 4) sees them immediately instead of in delayed chunks.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Create an unprivileged user. Containers run as root by default; if the app is
# ever compromised, root inside the container is a far bigger problem than a
# locked-down user. Running as non-root is a baseline security control.
RUN useradd --create-home --uid 1000 appuser

WORKDIR /app

# Bring in the ready-made virtual environment from the builder stage.
COPY --from=builder /opt/venv /opt/venv

# Copy the application code. (Tests, docs, Terraform, etc. are excluded by
# .dockerignore — the image contains only what is needed to RUN.)
COPY app ./app

# Drop privileges for everything from here on.
USER appuser

# Documents the port the app listens on. (Informational; the actual published
# port is set by ECS/Docker at run time.)
EXPOSE 8000

# Start the API. --host 0.0.0.0 makes it listen on all interfaces, which is
# required for traffic from outside the container to reach it.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
