from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello():
    return {'message': 'Hello from GKE!', 'status': 'running'}

@app.route('/health')
def health():
    return {'status': 'healthy'}

@app.route('/version')
def version():
    return {'version': '1.0.3', 'app': 'gke-demo', 'environment': 'production'}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)

# Trigger workflow



