# ============================================================================
# EMERGENT AGENT ENVIRONMENT - DOCKERFILE
# ============================================================================
# This creates the base container image with all system tools.
# Persistent storage is handled via Kubernetes PVC mounts (see k8s config below)
# ============================================================================

FROM ubuntu:22.04

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# ============================================================================
# STAGE 1: System Dependencies & Base Tools
# ============================================================================

RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    git \
    curl \
    wget \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release \
    # System utilities
    sudo \
    supervisor \
    nginx \
    software-properties-common \
    apt-transport-https \
    # Utilities
    vim \
    nano \
    htop \
    net-tools \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# STAGE 2: Install MongoDB 7.0
# ============================================================================

RUN wget -qO - https://www.mongodb.org/static/pgp/server-7.0.asc | apt-key add - && \
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
    tee /etc/apt/sources.list.d/mongodb-org-7.0.list && \
    apt-get update && \
    apt-get install -y \
        mongodb-org=7.0.25 \
        mongodb-org-database=7.0.25 \
        mongodb-org-server=7.0.25 \
        mongodb-org-mongos=7.0.25 \
        mongodb-org-tools=7.0.25 \
        mongodb-mongosh \
    && rm -rf /var/lib/apt/lists/*

# Create MongoDB data directory (will be mounted from PVC)
RUN mkdir -p /data/db && chown -R mongodb:mongodb /data/db

# ============================================================================
# STAGE 3: Install Node.js & Yarn
# ============================================================================

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn && \
    rm -rf /var/lib/apt/lists/*

# ============================================================================
# STAGE 4: Install Python 3.11
# ============================================================================

RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y \
        python3.11 \
        python3.11-venv \
        python3.11-dev \
        python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.11 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

# ============================================================================
# STAGE 5: Create Python Virtual Environment in /root
# ============================================================================
# NOTE: /root will be mounted from PVC, so venv persists across restarts

RUN python3.11 -m venv /root/.venv && \
    /root/.venv/bin/pip install --upgrade pip setuptools wheel

# Add venv to PATH
ENV PATH="/root/.venv/bin:$PATH"

# Install base Python packages
RUN /root/.venv/bin/pip install \
    fastapi==0.110.1 \
    uvicorn==0.25.0 \
    motor==3.3.1 \
    pymongo==4.5.0 \
    pydantic>=2.6.4 \
    python-dotenv>=1.0.1 \
    python-multipart>=0.0.9 \
    requests>=2.31.0

# ============================================================================
# STAGE 6: Setup Workspace Structure
# ============================================================================
# These directories will be mounted from PVC in production

# Create workspace directories
RUN mkdir -p /app/backend /app/frontend /app/tests /app/scripts

# Create log directories (will be mounted from PVC)
RUN mkdir -p /var/log/supervisor /var/log/mongodb

# Create supervisor config directory (will be mounted from PVC)
RUN mkdir -p /etc/supervisor/conf.d

# ============================================================================
# STAGE 7: Configure Supervisor (Base Config)
# ============================================================================
# The actual service configs will be on PVC at /etc/supervisor/conf.d/

RUN cat > /etc/supervisor/supervisord.conf << 'SUPERVISORD'
[unix_http_server]
file=/var/run/supervisor.sock
chmod=0700

[supervisord]
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid
childlogdir=/var/log/supervisor
nodaemon=true

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///var/run/supervisor.sock

[include]
files = /etc/supervisor/conf.d/*.conf
SUPERVISORD

# ============================================================================
# STAGE 8: Configure Nginx for Code Server Proxy
# ============================================================================

RUN cat > /etc/nginx/nginx-code-server.conf << 'NGINX'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
daemon off;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

    server {
        listen 8080;
        server_name _;

        location / {
            proxy_pass http://localhost:8000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection upgrade;
            proxy_set_header Accept-Encoding gzip;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
NGINX

# ============================================================================
# STAGE 9: Setup Entrypoint Script
# ============================================================================

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ============================================================================
# STAGE 10: Environment Variables & Defaults
# ============================================================================

# Python environment
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Plugin venv path (for e1_monitor tool)
ENV PLUGIN_VENV_PATH=/usr/local/plugin-venv

# Create plugin venv and install monitor tool
RUN python3.11 -m venv ${PLUGIN_VENV_PATH} && \
    ${PLUGIN_VENV_PATH}/bin/pip install --upgrade pip

# Expose ports
EXPOSE 3000 8001 8010 27017

# ============================================================================
# STAGE 11: Working Directory & Entrypoint
# ============================================================================

WORKDIR /app

# Use entrypoint script
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]

# ============================================================================
# END OF DOCKERFILE
# ============================================================================
# 
# Key Points:
# 1. System tools (MongoDB, Node, Python) are in the IMAGE
# 2. /root/.venv is created in image but will be OVERWRITTEN by PVC mount
# 3. Supervisor/Nginx configs are in image as defaults
# 4. Actual persistence comes from Kubernetes PVC mounts (see k8s config)
# ============================================================================
