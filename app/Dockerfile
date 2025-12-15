# Build stage for Python dependencies
FROM ubuntu:24.04 AS python-builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip3 install --no-cache-dir --user --break-system-packages -r requirements.txt

# Build stage for Node/Yarn
FROM ubuntu:24.04 AS node-builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_VERSION=20.19.6

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js v20.19.6 (exact)
RUN curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz \
    | tar -xJ -C /usr/local --strip-components=1

# Install npm v10.8.2 (exact)
RUN npm install -g npm@10.8.2

# Verify versions
RUN node -v && npm -v

# Install Yarn
RUN npm install -g yarn

# Build stage for VSCode Server
FROM ubuntu:24.04 AS vscode-builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://code-server.dev/install.sh | sh

# Final runtime stage
FROM ubuntu:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

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
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy Python packages from builder
COPY --from=python-builder /root/.local /root/.local

# Copy Node.js and npm from builder
COPY --from=node-builder /usr/local/bin/node /usr/local/bin/node
COPY --from=node-builder /usr/local/bin/npm /usr/local/bin/npm
COPY --from=node-builder /usr/local/bin/npx /usr/local/bin/npx
COPY --from=node-builder /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node-builder /usr/local/bin/yarn /usr/local/bin/yarn
COPY --from=node-builder /usr/local/bin/yarnpkg /usr/local/bin/yarnpkg

# Copy VSCode Server from builder
COPY --from=vscode-builder /usr/bin/code-server /usr/bin/code-server
COPY --from=vscode-builder /usr/lib/code-server /usr/lib/code-server

# Set Python path
ENV PATH=/root/.local/bin:$PATH

# Create application directories and persistence mount points
RUN mkdir -p /app /data/db /var/log/supervisor \
    /usr/local/persistent \
    /opt/user-packages \
    /var/lib/dpkg/persistent

# Create package persistence hooks
RUN echo '#!/bin/bash\n\
# Persistent apt wrapper\n\
if [[ "$1" == "install" ]]; then\n\
    /usr/bin/apt "$@"\n\
    # Save installed packages\n\
    shift\n\
    for pkg in "$@"; do\n\
        [[ "$pkg" != "-y" ]] && echo "$pkg" >> /usr/local/persistent/installed-packages.txt\n\
    done\n\
    sort -u /usr/local/persistent/installed-packages.txt -o /usr/local/persistent/installed-packages.txt\n\
else\n\
    /usr/bin/apt "$@"\n\
fi' > /usr/local/bin/persistent-apt && chmod +x /usr/local/bin/persistent-apt

# Set up package persistence aliases
RUN echo 'alias apt="sudo /usr/local/bin/persistent-apt"' >> /etc/bash.bashrc && \
    echo 'alias pip="pip install --user"' >> /etc/bash.bashrc && \
    echo 'export NPM_CONFIG_PREFIX=/usr/local' >> /etc/bash.bashrc

WORKDIR /app

# Copy configuration files
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY nginx.conf /etc/nginx/nginx-code-server.conf

# Copy application files
COPY . /app/

# Expose ports
EXPOSE 1111 3000 8001 8010 8080 27017

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
