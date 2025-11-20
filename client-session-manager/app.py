from flask import Flask, request, jsonify
from kubernetes import client, config
from kubernetes.client.rest import ApiException
import redis
import uuid
import os
import yaml
import logging
import time
import requests
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

# Configuration - CLIENT VERSION
REDIS_HOST = os.getenv('REDIS_HOST', 'client-redis')  # CLIENT REDIS
REDIS_PORT_STR = os.getenv('REDIS_PORT', '6379')
REDIS_PORT = int(REDIS_PORT_STR.split(':')[-1]) if 'tcp://' in REDIS_PORT_STR else int(REDIS_PORT_STR)
REDIS_PASSWORD = os.getenv('REDIS_PASSWORD', None)
SESSION_TTL = int(os.getenv('SESSION_TTL', 86400))  # 24 hours default
USER_POD_IMAGE = os.getenv('USER_POD_IMAGE', 'us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/emergent-agent:latest')
USER_POD_PORT = int(os.getenv('USER_POD_PORT', 8080))
API_KEY = os.getenv('API_KEY', 'client-api-key-2024')  # CLIENT API KEY
VERSION = '4.0.0-CLIENT'  # CLIENT: Single PVC with 5 subPaths for system persistence

# Load k8s config
try:
    config.load_incluster_config()
    logger.info("Loaded in-cluster Kubernetes config")
except:
    config.load_kube_config()
    logger.info("Loaded local Kubernetes config")

v1 = client.AppsV1Api()
core_v1 = client.CoreV1Api()
custom_api = client.CustomObjectsApi()

# Initialize Redis with error handling
def init_redis():
    """Initialize Redis connection with validation"""
    try:
        r = redis.Redis(
            host=REDIS_HOST,
            port=REDIS_PORT,
            password=REDIS_PASSWORD,
            decode_responses=True,
            socket_connect_timeout=5,
            socket_keepalive=True,
            health_check_interval=30
        )
        r.ping()
        logger.info(f"✅ CLIENT Redis connected successfully at {REDIS_HOST}:{REDIS_PORT}")
        return r
    except Exception as e:
        logger.error(f"❌ Failed to connect to CLIENT Redis: {str(e)}")
        raise

try:
    r = init_redis()
except Exception as e:
    logger.error(f"CLIENT Redis initialization failed: {str(e)}")
    r = None


# ============================================================================
# AUTHENTICATION & AUTHORIZATION
# ============================================================================

def require_api_key(f):
    """API key authentication decorator"""
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


# ============================================================================
# RATE LIMITING & ERROR HANDLING
# ============================================================================

def rate_limit(max_requests=10, window=60):
    """Rate limiting decorator - max_requests per window (seconds)"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if not r:
                return {'error': 'Redis unavailable'}, 503
            
            client_ip = request.headers.get('X-Forwarded-For', request.remote_addr).split(',')[0].strip()
            rate_key = f"rate:{client_ip}:{f.__name__}"
            
            try:
                current = r.incr(rate_key)
                if current == 1:
                    r.expire(rate_key, window)
                
                if current > max_requests:
                    logger.warning(f"⚠️ Rate limit exceeded for {client_ip}")
                    return {'error': 'Too many requests', 'retry_after': window}, 429
            except Exception as e:
                logger.error(f"Rate limiting error: {str(e)}")
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator


def handle_errors(f):
    """Error handling wrapper for API endpoints"""
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


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def log_event(session_uuid, event_type, details=None):
    """Log session events for monitoring"""
    if r:
        try:
            event = {
                'timestamp': datetime.utcnow().isoformat(),
                'type': event_type,
                'details': details or {}
            }
            r.lpush(f"client-events:{session_uuid}", json.dumps(event))
            r.ltrim(f"client-events:{session_uuid}", 0, 99)  # Keep last 100 events
            logger.info(f"📝 CLIENT [{session_uuid}] {event_type}: {details}")
        except Exception as e:
            logger.warning(f"Failed to log event: {str(e)}")


def check_session_exists(session_uuid):
    """Validate session exists in Redis"""
    if not r:
        raise Exception("Redis unavailable")
    
    if not r.exists(f'client-session:{session_uuid}'):
        raise ValueError(f"CLIENT session {session_uuid} not found")
    
    return r.hgetall(f'client-session:{session_uuid}')


def set_session_ttl(session_uuid):
    """Set TTL for session data"""
    if r:
        try:
            r.expire(f'client-session:{session_uuid}', SESSION_TTL)
            r.expire(f'client-queue:{session_uuid}', SESSION_TTL)
        except Exception as e:
            logger.warning(f"Failed to set TTL for {session_uuid}: {str(e)}")

@app.route('/session/create', methods=['POST'])
@require_api_key
@handle_errors
@rate_limit(max_requests=100, window=60)
def create_session():
    """Create CLIENT session with single PVC + 5 subPaths"""
    start_time = time.time()
    
    if not r:
        return {'error': 'Redis unavailable'}, 503
    
    session_uuid = str(uuid.uuid4())[:8]
    user_id = request.json.get('user_id')
    
    if not user_id:
        raise ValueError("user_id is required")
    
    # Sanitize user_id for Kubernetes labels (alphanumeric, -, _, .)
    user_id_label = user_id.replace('@', '-').replace('/', '-').replace(':', '-')
    
    logger.info(f"🆕 Creating CLIENT session for user: {user_id}")
    
    try:
        # Create deployment for this user - CLIENT VERSION
        deployment = client.V1Deployment(
            metadata=client.V1ObjectMeta(
                name=f"client-{session_uuid}",
                labels={"session-uuid": session_uuid, "user-id": user_id_label, "type": "client"}
            ),
            spec=client.V1DeploymentSpec(
                replicas=1,  # Start pod immediately
                selector=client.V1LabelSelector(
                    match_labels={"app": f"client-{session_uuid}"}
                ),
                template=client.V1PodTemplateSpec(
                    metadata=client.V1ObjectMeta(
                        labels={"app": f"client-{session_uuid}", "uuid": session_uuid, "user-id": user_id_label}
                    ),
                    spec=client.V1PodSpec(
                        containers=[
                            client.V1Container(
                                name="client-pod",
                                image=USER_POD_IMAGE,
                                ports=[client.V1ContainerPort(container_port=USER_POD_PORT)],
                                resources=client.V1ResourceRequirements(
                                    requests={"memory": "512Mi", "cpu": "500m"},
                                    limits={"memory": "1Gi", "cpu": "1000m"}
                                ),
                                env=[
                                    client.V1EnvVar(name="SESSION_UUID", value=session_uuid),
                                    client.V1EnvVar(name="USER_ID", value=user_id)
                                ],
                                volume_mounts=[
                                    client.V1VolumeMount(name="persistent-storage", mount_path="/app", sub_path="app"),
                                    client.V1VolumeMount(name="persistent-storage", mount_path="/root", sub_path="root"),
                                    client.V1VolumeMount(name="persistent-storage", mount_path="/etc/supervisor", sub_path="etc/supervisor"),
                                    client.V1VolumeMount(name="persistent-storage", mount_path="/var/log", sub_path="var/log"),
                                    client.V1VolumeMount(name="persistent-storage", mount_path="/data/db", sub_path="data/db")
                                ]
                            )
                        ],
                        volumes=[
                            client.V1Volume(
                                name="persistent-storage",
                                persistent_volume_claim=client.V1PersistentVolumeClaimVolumeSource(
                                    claim_name=f"client-pvc-{session_uuid}"
                                )
                            )
                        ]
                    )
                )
            )
        )
        
        # Create CLIENT'S SINGLE 10GB PVC with 5 subPaths
        pvc = client.V1PersistentVolumeClaim(
            metadata=client.V1ObjectMeta(
                name=f"client-pvc-{session_uuid}",
                labels={"session-uuid": session_uuid, "type": "client-single-pvc"}
            ),
            spec=client.V1PersistentVolumeClaimSpec(
                access_modes=["ReadWriteOnce"],
                resources=client.V1ResourceRequirements(
                    requests={"storage": "10Gi"}
                )
            )
        )
        
        core_v1.create_namespaced_persistent_volume_claim(namespace="default", body=pvc)
        logger.info(f"✅ CLIENT PVC created: client-pvc-{session_uuid} (10Gi) - single PVC with 5 subPaths")
        logger.info(f"   📁 /app ← subPath: app (workspace)")
        logger.info(f"   📁 /root ← subPath: root (Python venv)")
        logger.info(f"   📁 /etc/supervisor ← subPath: etc/supervisor (configs)")
        logger.info(f"   📁 /var/log ← subPath: var/log (logs)")
        logger.info(f"   📁 /data/db ← subPath: data/db (MongoDB)")
        
        v1.create_namespaced_deployment(namespace="default", body=deployment)
        logger.info(f"✅ CLIENT Deployment created: client-{session_uuid}")
        
        # Create ClusterIP service (internal)
        service = client.V1Service(
            metadata=client.V1ObjectMeta(
                name=f"client-{session_uuid}",
                labels={"session-uuid": session_uuid}
            ),
            spec=client.V1ServiceSpec(
                selector={"app": f"client-{session_uuid}"},
                ports=[client.V1ServicePort(port=80, target_port=USER_POD_PORT)]
            )
        )
        
        core_v1.create_namespaced_service(namespace="default", body=service)
        logger.info(f"✅ CLIENT Service created: client-{session_uuid}")
        
        # Create Ingress for external access via subdomain
        ingress = client.V1Ingress(
            metadata=client.V1ObjectMeta(
                name=f"client-{session_uuid}",
                labels={"session-uuid": session_uuid},
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
        
        networking_v1 = client.NetworkingV1Api()
        networking_v1.create_namespaced_ingress(namespace="default", body=ingress)
        logger.info(f"✅ CLIENT Ingress created: client-{session_uuid}")
        
        # Store session with TTL
        r.hset(f'client-session:{session_uuid}', mapping={
            'user_id': user_id,
            'status': 'created',
            'created_at': datetime.utcnow().isoformat(),
            'last_activity': datetime.utcnow().isoformat()
        })
        set_session_ttl(session_uuid)
        
        log_event(session_uuid, 'client_session_created', {'user_id': user_id})
        
        elapsed = time.time() - start_time
        logger.info(f"🎉 CLIENT session created successfully in {elapsed:.2f}s: {session_uuid}")
        
        # Construct workspace URL with subdomain
        workspace_url = f"https://client-{session_uuid}.preview.hyperbola.in"
        
        return jsonify({
            'uuid': session_uuid,
            'user_id': user_id,
            'status': 'created',
            'created_at': datetime.utcnow().isoformat(),
            'workspace_url': workspace_url
        }), 201
        
    except Exception as e:
        logger.error(f"❌ Failed to create CLIENT session: {str(e)}", exc_info=True)
        raise

@app.route('/session/<session_uuid>/wake', methods=['POST'])
@require_api_key
@handle_errors
@rate_limit(max_requests=50, window=60)
def wake_session(session_uuid):
    """Wake up sleeping CLIENT pod"""
    if not r:
        return {'error': 'Redis unavailable'}, 503
    
    session_data = check_session_exists(session_uuid)
    
    try:
        # Scale deployment to 1
        deployment = v1.read_namespaced_deployment(name=f"client-{session_uuid}", namespace="default")
        if deployment.spec.replicas == 0:
            deployment.spec.replicas = 1
            v1.patch_namespaced_deployment(
                name=f"client-{session_uuid}",
                namespace="default",
                body=deployment
            )
            logger.info(f"⏰ Waking up CLIENT session: {session_uuid}")
        
        r.hset(f'client-session:{session_uuid}', 'last_activity', datetime.utcnow().isoformat())
        r.hset(f'client-session:{session_uuid}', 'status', 'running')
        set_session_ttl(session_uuid)
        
        log_event(session_uuid, 'client_session_woken', {'user_id': session_data.get('user_id')})
        
        return jsonify({
            'uuid': session_uuid,
            'action': 'wake',
            'status': 'waking'
        }), 200
    except Exception as e:
        logger.error(f"❌ Failed to wake CLIENT session: {str(e)}", exc_info=True)
        raise

@app.route('/session/<session_uuid>/sleep', methods=['POST'])
@require_api_key
@handle_errors
@rate_limit(max_requests=50, window=60)
def sleep_session(session_uuid):
    """Manually put CLIENT session to sleep"""
    if not r:
        return {'error': 'Redis unavailable'}, 503
    
    session_data = check_session_exists(session_uuid)
    
    try:
        # Clear the queue
        r.delete(f'client-queue:{session_uuid}')
        
        # Scale deployment to 0
        deployment = v1.read_namespaced_deployment(name=f"client-{session_uuid}", namespace="default")
        deployment.spec.replicas = 0
        v1.patch_namespaced_deployment(
            name=f"client-{session_uuid}",
            namespace="default",
            body=deployment
        )
        
        logger.info(f"😴 Putting CLIENT session to sleep: {session_uuid}")
        
        # Update session status
        r.hset(f'client-session:{session_uuid}', 'status', 'sleeping')
        set_session_ttl(session_uuid)
        
        log_event(session_uuid, 'client_session_sleeping', {'user_id': session_data.get('user_id')})
        
        return jsonify({
            'uuid': session_uuid,
            'action': 'sleep',
            'status': 'sleeping',
            'message': 'CLIENT pod queued for sleep'
        }), 200
        
    except Exception as e:
        logger.error(f"❌ Failed to sleep CLIENT session: {str(e)}", exc_info=True)
        raise

@app.route('/session/<session_uuid>/status')
@require_api_key
@handle_errors
@rate_limit(max_requests=200, window=60)
def session_status(session_uuid):
    """Get current CLIENT session status"""
    if not r:
        return {'error': 'Redis unavailable'}, 503
    
    session_data = check_session_exists(session_uuid)
    queue_length = r.llen(f'client-queue:{session_uuid}')
    
    try:
        deployment = v1.read_namespaced_deployment(name=f"client-{session_uuid}", namespace="default")
        replicas = deployment.status.replicas or 0
    except ApiException as e:
        logger.warning(f"CLIENT deployment not found: {session_uuid}")
        replicas = 0
    
    return jsonify({
        'uuid': session_uuid,
        'session': session_data,
        'queue_length': queue_length,
        'replicas': replicas,
        'timestamp': datetime.utcnow().isoformat()
    }), 200

@app.route('/session/<session_uuid>', methods=['DELETE'])
@require_api_key
@handle_errors
@rate_limit(max_requests=50, window=60)
def delete_session(session_uuid):
    """Terminate CLIENT session and cleanup all resources"""
    if not r:
        return {'error': 'Redis unavailable'}, 503
    
    try:
        session_data = check_session_exists(session_uuid)
        user_id = session_data.get('user_id', 'unknown')
    except ValueError:
        logger.warning(f"CLIENT session not found for deletion: {session_uuid}")
        return {'error': 'Session not found'}, 404
    
    logger.info(f"🗑️ Deleting CLIENT session: {session_uuid}")
    
    try:
        # Delete deployment
        try:
            v1.delete_namespaced_deployment(
                name=f"client-{session_uuid}",
                namespace="default",
                body=client.V1DeleteOptions(grace_period_seconds=30)
            )
            logger.info(f"✅ CLIENT Deployment deleted: client-{session_uuid}")
        except ApiException as e:
            if e.status != 404:
                raise
            logger.warning(f"CLIENT Deployment not found: client-{session_uuid}")
        
        # Delete service
        try:
            core_v1.delete_namespaced_service(
                name=f"client-{session_uuid}",
                namespace="default"
            )
            logger.info(f"✅ CLIENT Service deleted: client-{session_uuid}")
        except ApiException as e:
            if e.status != 404:
                raise
            logger.warning(f"CLIENT Service not found: client-{session_uuid}")
        
        # Delete Ingress
        try:
            networking_v1.delete_namespaced_ingress(
                name=f"client-{session_uuid}",
                namespace="default"
            )
            logger.info(f"✅ CLIENT Ingress deleted: client-{session_uuid}")
        except ApiException as e:
            if e.status != 404:
                raise
            logger.warning(f"CLIENT Ingress not found: client-{session_uuid}")
        
        # Delete CLIENT PVC
        try:
            core_v1.delete_namespaced_persistent_volume_claim(
                name=f"client-pvc-{session_uuid}",
                namespace="default"
            )
            logger.info(f"✅ CLIENT PVC deleted: client-pvc-{session_uuid}")
        except ApiException as e:
            if e.status != 404:
                raise
            logger.warning(f"CLIENT PVC not found: client-pvc-{session_uuid}")
        
        # Clean up Redis data
        r.delete(f'client-session:{session_uuid}')
        r.delete(f'client-queue:{session_uuid}')
        r.delete(f'client-events:{session_uuid}')
        logger.info(f"✅ CLIENT Redis data cleaned: {session_uuid}")
        
        log_event(session_uuid, 'client_session_terminated', {'user_id': user_id})
        
        return jsonify({
            'uuid': session_uuid,
            'status': 'terminated',
            'message': 'CLIENT session and all resources deleted'
        }), 200
        
    except Exception as e:
        logger.error(f"❌ Failed to delete CLIENT session: {str(e)}", exc_info=True)
        raise

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