FROM ubuntu:22.04

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    nginx \
    supervisor \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install Yarn
RUN npm install -g yarn

# Create application directories
RUN mkdir -p /app /data/db /var/log/supervisor

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser && \
    chown -R appuser:appuser /app /data/db /var/log/supervisor

# Copy application files
WORKDIR /app
COPY requirements.txt .

# Install Python dependencies
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy application code
COPY --chown=appuser:appuser . .

# Create supervisor configuration
RUN cat > /etc/supervisor/conf.d/supervisord.conf << 'EOF'
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:nginx]
command=nginx -g "daemon off;"
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/nginx.err.log
stdout_logfile=/var/log/supervisor/nginx.out.log
user=root

[program:flask-app]
command=python3 -m gunicorn -b 0.0.0.0:8080 -w 2 --access-logfile - app:app
directory=/app
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/flask.err.log
stdout_logfile=/var/log/supervisor/flask.out.log
user=appuser
environment=PYTHONUNBUFFERED=1

[program:frontend]
command=bash -c "if [ -f package.json ]; then npm start; else echo 'No frontend found, serving placeholder on 3000'; python3 -m http.server 3000; fi"
directory=/app
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/frontend.err.log
stdout_logfile=/var/log/supervisor/frontend.out.log
user=appuser

[program:backend-api]
command=python3 -c "from flask import Flask; app = Flask(__name__); @app.route('/health'): def health(): return {'status': 'healthy', 'service': 'backend-api'}; app.run(host='0.0.0.0', port=8001)"
directory=/app
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/backend.err.log
stdout_logfile=/var/log/supervisor/backend.out.log
user=appuser

[program:agent-tools]
command=python3 -c "from flask import Flask; app = Flask(__name__); @app.route('/health'): def health(): return {'status': 'healthy', 'service': 'agent-tools'}; app.run(host='0.0.0.0', port=8010)"
directory=/app
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/tools.err.log
stdout_logfile=/var/log/supervisor/tools.out.log
user=appuser
EOF

# Configure Nginx as reverse proxy
RUN cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 1111 default_server;
    server_name _;

    # Main Flask app (VSCode-like interface)
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }

    # Frontend service
    location /frontend/ {
        proxy_pass http://localhost:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Backend API
    location /api/ {
        proxy_pass http://localhost:8001/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Agent tools
    location /tools/ {
        proxy_pass http://localhost:8010/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://localhost:8080/health;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

# Expose all necessary ports
EXPOSE 1111 3000 8001 8010 8080

# Health check on the main nginx proxy port
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:1111/health || exit 1

# Set working directory
WORKDIR /app

# Start supervisor to manage all services
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
