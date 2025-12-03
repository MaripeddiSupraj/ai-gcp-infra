#!/bin/bash
# Removed set -e to prevent script from exiting on errors

echo "Starting container..."

# Check if required environment variables are set
if [ -z "${run_id}" ]; then
    echo "Error: 'run_id' environment variable is not set"
    exit 1
fi

if [ -z "${code_server_password}" ]; then
    echo "Error: 'code_server_password' environment variable is not set"
    exit 1
fi

if [ -z "${preview_endpoint}" ]; then
    echo "Error: 'preview_endpoint' environment variable is not set"
    exit 1
fi

if [ -z "${base_url}" ]; then
    echo "Error: 'base_url' environment variable is not set"
    exit 1
fi

if [ -z "${monitor_polling_interval}" ]; then
    echo "Error: 'monitor_polling_interval' environment variable is not set"
    exit 1
fi

# Set reload flag based on environment variable (default to --reload if not set)
if [ "${ENABLE_RELOAD:-true}" = "true" ]; then
    RELOAD_FLAG="--reload"
    DISABLE_HOT_RELOAD_FLAG=""
else
    RELOAD_FLAG=""
    DISABLE_HOT_RELOAD_FLAG="DISABLE_HOT_RELOAD=true"
fi

echo "Reload flag set to: ${RELOAD_FLAG}"
echo "Disable hot reload flag set to: ${DISABLE_HOT_RELOAD_FLAG}"

# Update frontend environment variables if .env file exists
if [ -f "/app/frontend/.env" ]; then
    # Update REACT_APP_BACKEND_URL
    sed -i "s|^REACT_APP_BACKEND_URL=.*|REACT_APP_BACKEND_URL=${preview_endpoint}|" "/app/frontend/.env"

    # Set REACT_APP_ENABLE_VISUAL_EDITS to false if it exists and is currently true
    if grep -q "^REACT_APP_ENABLE_VISUAL_EDITS=true" "/app/frontend/.env"; then
        sed -i "s|^REACT_APP_ENABLE_VISUAL_EDITS=true|REACT_APP_ENABLE_VISUAL_EDITS=false|" "/app/frontend/.env"
    fi
fi

# Directly set the password in the supervisor config file
sed -i "s|environment=PASSWORD=\".*\"|environment=PASSWORD=\"${code_server_password}\"|" /etc/supervisor/conf.d/supervisord_code_server.conf

# Update the reload flag in the supervisor config file
sed -i "s|{{RELOAD_FLAG}}|${RELOAD_FLAG}|g" /etc/supervisor/conf.d/supervisord.conf

# Update the disable hot reload flag in the supervisor config file
sed -i "s|{{DISABLE_HOT_RELOAD}}|${DISABLE_HOT_RELOAD_FLAG}|g" /etc/supervisor/conf.d/supervisord.conf

# Update the preview endpoint in the supervisor config file
sed -i "s|{{APP_URL}}|${preview_endpoint}|g" /etc/supervisor/conf.d/supervisord.conf

# Update the integration proxy url in the supervisor config file
sed -i "s|{{INTEGRATION_PROXY_URL}}|${integration_proxy_url}|g" /etc/supervisor/conf.d/supervisord.conf

nohup ${PLUGIN_VENV_PATH}/bin/e1_monitor ${run_id} ${base_url} --interval ${monitor_polling_interval} >> /var/log/monitor.log 2>&1 &

# Handle SIGTERM gracefully
trap 'echo "Received SIGTERM, shutting down..."; \
        killall supervisord || true; \
        kill -TERM $uvicorn_pid 2>/dev/null; \
        exit 0' SIGTERM

# Create log directory for supervisor
mkdir -p /var/log/supervisor

# Start supervisor
( sudo service supervisor start && sudo supervisorctl reread && sudo supervisorctl update ) &

while true; do
    echo "[$(date)] Starting uvicorn server with plugin environment..."

    ${PLUGIN_VENV_PATH}/bin/uvicorn plugins.tools.agent.server:app --host "0.0.0.0" --port 8010 --workers 1 --no-access-log &
    uvicorn_pid=$!
    echo "[$(date)] Uvicorn started with PID: $uvicorn_pid"

    # Wait for the process but don't exit on failure
    wait $uvicorn_pid || true
    exit_code=$?
    echo "[$(date)] Uvicorn process $uvicorn_pid exited with code $exit_code"

    # Log the specific signal if it was killed
    if [ $exit_code -gt 128 ]; then
        signal=$((exit_code - 128))
        echo "[$(date)] Process was killed by signal $signal"
    fi

    echo "[$(date)] Restarting in 3 seconds..."
    sleep 3
done