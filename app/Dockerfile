# Build stage for Python dependencies
FROM ubuntu:22.04 AS python-builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip3 install --no-cache-dir --user -r requirements.txt

# Build stage for Node/Yarn
FROM ubuntu:22.04 AS node-builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    npm \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g yarn

# Build stage for VSCode Server
FROM ubuntu:22.04 AS vscode-builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://code-server.dev/install.sh | sh

# Final runtime stage
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install only runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    vim \
    nginx \
    supervisor \
    python3 \
    nodejs \
    mongodb \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy Python packages from builder
COPY --from=python-builder /root/.local /root/.local

# Copy Yarn from builder
COPY --from=node-builder /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node-builder /usr/local/bin/yarn /usr/local/bin/yarn
COPY --from=node-builder /usr/local/bin/yarnpkg /usr/local/bin/yarnpkg

# Copy VSCode Server from builder
COPY --from=vscode-builder /usr/bin/code-server /usr/bin/code-server
COPY --from=vscode-builder /usr/lib/code-server /usr/lib/code-server

# Set Python path
ENV PATH=/root/.local/bin:$PATH

# Create application directories
RUN mkdir -p /app /data/db /var/log/supervisor

WORKDIR /app

# Copy application files
COPY . /app/

# Configure supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Configure Nginx
COPY nginx.conf /etc/nginx/nginx-code-server.conf

# Expose ports
EXPOSE 1111 3000 8001 8010 8080 27017

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
