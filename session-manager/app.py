from flask import Flask, request, jsonify
from kubernetes import client, config
import redis
import uuid
import os

app = Flask(__name__)

# Load k8s config
try:
    config.load_incluster_config()
except:
    config.load_kube_config()

v1 = client.AppsV1Api()
core_v1 = client.CoreV1Api()
r = redis.Redis(host='redis', port=6379, decode_responses=True)

@app.route('/health')
def health():
    return {'status': 'healthy'}

@app.route('/session/create', methods=['POST'])
def create_session():
    session_uuid = str(uuid.uuid4())[:8]
    user_id = request.json.get('user_id', 'anonymous')
    
    # Create deployment for this user
    deployment = client.V1Deployment(
        metadata=client.V1ObjectMeta(name=f"user-{session_uuid}"),
        spec=client.V1DeploymentSpec(
            replicas=0,
            selector=client.V1LabelSelector(
                match_labels={"app": f"user-{session_uuid}"}
            ),
            template=client.V1PodTemplateSpec(
                metadata=client.V1ObjectMeta(
                    labels={"app": f"user-{session_uuid}", "uuid": session_uuid}
                ),
                spec=client.V1PodSpec(
                    containers=[
                        client.V1Container(
                            name="user-pod",
                            image="us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/ai-environment:latest",
                            ports=[client.V1ContainerPort(container_port=1111)],
                            resources=client.V1ResourceRequirements(
                                requests={"memory": "256Mi", "cpu": "250m"},
                                limits={"memory": "512Mi", "cpu": "500m"}
                            )
                        )
                    ]
                )
            )
        )
    )
    
    v1.create_namespaced_deployment(namespace="default", body=deployment)
    
    # Create service
    service = client.V1Service(
        metadata=client.V1ObjectMeta(name=f"user-{session_uuid}"),
        spec=client.V1ServiceSpec(
            selector={"app": f"user-{session_uuid}"},
            ports=[client.V1ServicePort(port=80, target_port=1111)]
        )
    )
    
    core_v1.create_namespaced_service(namespace="default", body=service)
    
    # Store session
    r.hset(f'session:{session_uuid}', mapping={'user_id': user_id, 'status': 'created'})
    
    return jsonify({'uuid': session_uuid, 'user_id': user_id, 'status': 'created'})

@app.route('/session/<session_uuid>/wake', methods=['POST'])
def wake_session(session_uuid):
    r.lpush(f'queue:{session_uuid}', 'wake')
    return jsonify({'uuid': session_uuid, 'action': 'wake'})

@app.route('/session/<session_uuid>/status')
def session_status(session_uuid):
    session_data = r.hgetall(f'session:{session_uuid}')
    queue_length = r.llen(f'queue:{session_uuid}')
    
    try:
        deployment = v1.read_namespaced_deployment(name=f"user-{session_uuid}", namespace="default")
        replicas = deployment.status.replicas or 0
    except:
        replicas = 0
    
    return jsonify({
        'uuid': session_uuid,
        'session': session_data,
        'queue_length': queue_length,
        'replicas': replicas
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
