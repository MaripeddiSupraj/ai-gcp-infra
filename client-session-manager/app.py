from flask import Flask, request, jsonify
from kubernetes import client, config
from kubernetes.client.rest import ApiException
import redis
import uuid
import os
import logging
import time
from functools import wraps
from datetime import datetime
import json

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration - CLIENT SPECIFIC
REDIS_HOST = os.getenv('REDIS_HOST', 'client-redis')
REDIS_PORT = int(os.getenv('REDIS_PORT', 6379))
USER_POD_IMAGE = os.getenv('USER_POD_IMAGE', 'us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/emergent-agent:latest')
USER_POD_PORT = int(os.getenv('USER_POD_PORT', 8080))
API_KEY = os.getenv('API_KEY', 'client-api-key-2024')
SESSION_TTL = int(os.getenv('SESSION_TTL', 86400))
VERSION = '1.0.0-CLIENT'  # CLIENT: Single PVC with 5 subPaths for system persistence

# Load k8s config
try:
    config.load_incluster_config()
    logger.info("Loaded in-cluster Kubernetes config")
except:
    config.load_kube_config()
    logger.info("Loaded local Kubernetes config")

v1 = client.AppsV1Api()
core_v1 = client.CoreV1Api()
networking_v1 = client.NetworkingV1Api()

# Initialize Redis with error handling
def init_redis():
    try:
        r = redis.Redis(
            host=REDIS_HOST,
            port=REDIS_PORT,
            decode_responses=True,
            socket_connect_timeout=5,
            socket_keepalive=True,
            health_check_interval=30
        )
        r.ping()
        logger.info(f"✅ CLIENT Redis connected at {REDIS_HOST}:{REDIS_PORT}")
        return r
    except Exception as e:
        logger.error(f"❌ CLIENT Redis connection failed: {str(e)}")
        raise

try:
    r = init_redis()
except Exception as e:
    logger.error(f"CLIENT Redis initialization failed: {str(e)}")
    r = None

# ============================================================================
# AUTHENTICATION & ERROR HANDLING
# ============================================================================

def require_api_key(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        api_key = request.headers.get('X-API-Key') or request.headers.get('Authorization', '').replace('Bearer ', '')
        
        if not api_key:
            logger.warning(f"⚠️ Missing API key from {request.remote_addr}")
            return {'error': 'API key required', 'message': 'Include X-API-Key header'}, 401
        
        if api_key != API_KEY:
            logger.warning(f"⚠️ Invalid API key from {request.remote_addr}")
            return {'error': 'Invalid API key'}, 403
        
        return f(*args, **kwargs)
    return decorated_function

def handle_errors(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        try:
            return f(*args, **kwargs)
        except ApiException as e:
            logger.error(f"Kubernetes API error: {str(e)}")
            return {'error': f'Kubernetes error: {e.reason}'}, 500
        except redis.RedisError as e:
            logger.error(f"Redis error: {str(e)}")
            return {'error': 'Database error'}, 503
        except ValueError as e:
            logger.error(f"Validation error: {str(e)}")
            return {'error': str(e)}, 400
        except Exception as e:
            logger.error(f"Unexpected error in {f.__name__}: {str(e)}", exc_info=True)
            return {'error': 'Internal server error'}, 500
    return decorated_function

def log_event(session_uuid, event_type, details=None):
    if r:
        try:
            event = {
                'timestamp': datetime.utcnow().isoformat(),
                'type': event_type,
                'details': details or {}
            }
            r.lpush(f"client-events:{session_uuid}", json.dumps(event))
            r.ltrim(f"client-events:{session_uuid}", 0, 99)
            logger.info(f"📝 CLIENT [{session_uuid}] {event_type}: {details}")
        except Exception as e:
            logger.warning(f"Failed to log event: {str(e)}")

def check_session_exists(session_uuid):
    if not r:
        raise Exception("Redis unavailable")
    
    if not r.exists(f'client-session:{session_uuid}'):
        raise ValueError(f"CLIENT session {session_uuid} not found")
    
    return r.hgetall(f'client-session:{session_uuid}')

def set_session_ttl(session_uuid):
    if r:
        try:
            r.expire(f'client-session:{session_uuid}', SESSION_TTL)
        except Exception as e:
            logger.warning(f"Failed to set TTL for {session_uuid}: {str(e)}")

@app.route('/session/create', methods=['POST'])
@require_api_key
@handle_errors
def create_session():
    """Create CLIENT session with single PVC + 5 subPaths architecture"""
    start_time = time.time()
    
    if not r:
        return {'error': 'Redis unavailable'}, 503
    
    session_uuid = str(uuid.uuid4())[:8]
    user_id = request.json.get('user_id')
    
    if not user_id:
        raise ValueError("user_id is required")
    
    # Sanitize user_id for Kubernetes labels
    user_id_label = user_id.replace('@', '-').replace('/', '-').replace(':', '-')
    
    logger.info(f"🆕 Creating CLIENT session for user: {user_id}")
    
    # Create CLIENT'S SINGLE PVC with 5 subPaths
    pvc = client.V1PersistentVolumeClaim(
        metadata=client.V1ObjectMeta(
            name=f"client-pvc-{session_uuid}",
            labels={"type": "client-single-pvc", "session": session_uuid}
        ),
        spec=client.V1PersistentVolumeClaimSpec(
            access_modes=["ReadWriteOnce"],
            resources=client.V1ResourceRequirements(requests={"storage": "10Gi"})
        )
    )
    core_v1.create_namespaced_persistent_volume_claim(namespace="default", body=pvc)
    
    # Create deployment with 5 subPath mounts
    deployment = client.V1Deployment(
        metadata=client.V1ObjectMeta(
            name=f"client-{session_uuid}",
            labels={"session": session_uuid, "type": "client-pod"}
        ),
        spec=client.V1DeploymentSpec(
            replicas=1,
            selector=client.V1LabelSelector(match_labels={"app": f"client-{session_uuid}"}),
            template=client.V1PodTemplateSpec(
                metadata=client.V1ObjectMeta(labels={"app": f"client-{session_uuid}"}),
                spec=client.V1PodSpec(
                    containers=[client.V1Container(
                        name="client-pod",
                        image=USER_POD_IMAGE,
                        ports=[client.V1ContainerPort(container_port=8080)],
                        resources=client.V1ResourceRequirements(
                            requests={"memory": "512Mi", "cpu": "500m"},
                            limits={"memory": "1Gi", "cpu": "1000m"}
                        ),
                        env=[
                            client.V1EnvVar(name="SESSION_UUID", value=session_uuid),
                            client.V1EnvVar(name="USER_ID", value=user_id)
                        ],
                        volume_mounts=[
                            client.V1VolumeMount(name="storage", mount_path="/app", sub_path="app"),
                            client.V1VolumeMount(name="storage", mount_path="/root", sub_path="root"),
                            client.V1VolumeMount(name="storage", mount_path="/etc/supervisor", sub_path="etc/supervisor"),
                            client.V1VolumeMount(name="storage", mount_path="/var/log", sub_path="var/log"),
                            client.V1VolumeMount(name="storage", mount_path="/data/db", sub_path="data/db")
                        ]
                    )],
                    volumes=[client.V1Volume(
                        name="storage",
                        persistent_volume_claim=client.V1PersistentVolumeClaimVolumeSource(
                            claim_name=f"client-pvc-{session_uuid}"
                        )
                    )]
                )
            )
        )
    )
    v1.create_namespaced_deployment(namespace="default", body=deployment)
    
    # Create service
    service = client.V1Service(
        metadata=client.V1ObjectMeta(name=f"client-{session_uuid}"),
        spec=client.V1ServiceSpec(
            selector={"app": f"client-{session_uuid}"},
            ports=[client.V1ServicePort(port=80, target_port=8080)]
        )
    )
    core_v1.create_namespaced_service(namespace="default", body=service)
    
    # Create ingress
    ingress = client.V1Ingress(
        metadata=client.V1ObjectMeta(
            name=f"client-{session_uuid}",
            annotations={
                "kubernetes.io/ingress.class": "nginx",
                "cert-manager.io/cluster-issuer": "letsencrypt-prod"
            }
        ),
        spec=client.V1IngressSpec(
            rules=[client.V1IngressRule(
                host=f"client-{session_uuid}.preview.hyperbola.in",
                http=client.V1HTTPIngressRuleValue(
                    paths=[client.V1HTTPIngressPath(
                        path="/",
                        path_type="Prefix",
                        backend=client.V1IngressBackend(
                            service=client.V1IngressServiceBackend(
                                name=f"client-{session_uuid}",
                                port=client.V1ServiceBackendPort(number=80)
                            )
                        )
                    )]
                )
            )],
            tls=[client.V1IngressTLS(
                hosts=[f"client-{session_uuid}.preview.hyperbola.in"],
                secret_name=f"client-tls-{session_uuid}"
            )]
        )
    )
    networking_v1.create_namespaced_ingress(namespace="default", body=ingress)
    
    # Store in Redis
    r.hset(f'client-session:{session_uuid}', mapping={
        'user_id': user_id,
        'status': 'created',
        'created_at': datetime.utcnow().isoformat(),
        'last_activity': datetime.utcnow().isoformat()
    })
    set_session_ttl(session_uuid)
    
    log_event(session_uuid, 'client_session_created', {'user_id': user_id})
    
    elapsed = time.time() - start_time
    logger.info(f"🎉 CLIENT session created in {elapsed:.2f}s: {session_uuid}")
    logger.info(f"   📁 Single PVC: client-pvc-{session_uuid} (10Gi)")
    logger.info(f"   📁 5 subPaths: /app, /root, /etc/supervisor, /var/log, /data/db")
    
    workspace_url = f"https://client-{session_uuid}.preview.hyperbola.in"
    
    return jsonify({
        'uuid': session_uuid,
        'user_id': user_id,
        'status': 'created',
        'created_at': datetime.utcnow().isoformat(),
        'workspace_url': workspace_url
    }), 201

@app.route('/session/<session_uuid>', methods=['DELETE'])
@require_api_key
@handle_errors
def delete_session(session_uuid):
    """Delete CLIENT session and cleanup all resources"""
    if not r:
        return {'error': 'Redis unavailable'}, 503
    
    try:
        session_data = check_session_exists(session_uuid)
        user_id = session_data.get('user_id', 'unknown')
    except ValueError:
        logger.warning(f"CLIENT session not found for deletion: {session_uuid}")
        return {'error': 'Session not found'}, 404
    
    logger.info(f"🗑️ Deleting CLIENT session: {session_uuid}")
    
    # Delete deployment
    try:
        v1.delete_namespaced_deployment(name=f"client-{session_uuid}", namespace="default")
    except:
        pass
    
    # Delete service
    try:
        core_v1.delete_namespaced_service(name=f"client-{session_uuid}", namespace="default")
    except:
        pass
    
    # Delete ingress
    try:
        networking_v1.delete_namespaced_ingress(name=f"client-{session_uuid}", namespace="default")
    except:
        pass
    
    # Delete PVC
    try:
        core_v1.delete_namespaced_persistent_volume_claim(name=f"client-pvc-{session_uuid}", namespace="default")
    except:
        pass
    
    # Clean Redis
    r.delete(f'client-session:{session_uuid}')
    r.delete(f'client-events:{session_uuid}')
    
    log_event(session_uuid, 'client_session_terminated', {'user_id': user_id})
    
    logger.info(f"✅ CLIENT session deleted: {session_uuid}")
    return jsonify({
        'uuid': session_uuid,
        'status': 'terminated',
        'message': 'CLIENT session and all resources deleted'
    }), 200

@app.route('/session/<session_uuid>/status')
@require_api_key
@handle_errors
def session_status(session_uuid):
    """Get CLIENT session status"""
    if not r:
        return {'error': 'Redis unavailable'}, 503
    
    session_data = check_session_exists(session_uuid)
    
    try:
        deployment = v1.read_namespaced_deployment(name=f"client-{session_uuid}", namespace="default")
        replicas = deployment.status.replicas or 0
    except ApiException as e:
        logger.warning(f"CLIENT deployment not found: {session_uuid}")
        replicas = 0
    
    return jsonify({
        'uuid': session_uuid,
        'session': session_data,
        'replicas': replicas,
        'timestamp': datetime.utcnow().isoformat()
    }), 200

@app.route('/health')
def health():
    """CLIENT health check endpoint"""
    redis_status = "healthy"
    if r:
        try:
            r.ping()
        except:
            redis_status = "unhealthy"
    
    return jsonify({
        'status': 'healthy',
        'service': 'client-session-manager',
        'redis': redis_status,
        'version': VERSION,
        'timestamp': datetime.utcnow().isoformat()
    }), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)