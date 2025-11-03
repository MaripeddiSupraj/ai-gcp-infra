from flask import Flask, jsonify
import os
import socket

app = Flask(__name__)

@app.route('/')
def hello():
    return jsonify({
        'message': 'AI Development Environment - Multi-Service Platform',
        'status': 'running',
        'hostname': socket.gethostname(),
        'services': {
            'main_app': 'http://localhost:8080',
            'frontend': 'http://localhost:3000',
            'backend_api': 'http://localhost:8001',
            'agent_tools': 'http://localhost:8010',
            'nginx_proxy': 'http://localhost:1111'
        }
    })

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'service': 'main-app',
        'version': '2.0.0',
        'environment': os.getenv('ENVIRONMENT', 'development')
    })

@app.route('/version')
def version():
    return jsonify({
        'version': '2.0.0',
        'app': 'ai-development-platform',
        'environment': os.getenv('ENVIRONMENT', 'development'),
        'features': [
            'multi-service-architecture',
            'nginx-reverse-proxy',
            'supervisor-process-management',
            'health-monitoring'
        ]
    })

@app.route('/services')
def services():
    return jsonify({
        'services': [
            {'name': 'main-app', 'port': 8080, 'status': 'running'},
            {'name': 'frontend', 'port': 3000, 'status': 'running'},
            {'name': 'backend-api', 'port': 8001, 'status': 'running'},
            {'name': 'agent-tools', 'port': 8010, 'status': 'running'},
            {'name': 'nginx-proxy', 'port': 1111, 'status': 'running'}
        ]
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)
