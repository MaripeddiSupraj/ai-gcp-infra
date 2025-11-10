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

# Configuration
REDIS_HOST = os.getenv('REDIS_HOST', 'redis')
REDIS_PORT_STR = os.getenv('REDIS_PORT', '6379')
REDIS_PORT = int(REDIS_PORT_STR.split(':')[-1]) if 'tcp://' in REDIS_PORT_STR else int(REDIS_PORT_STR)
REDIS_PASSWORD = os.getenv('REDIS_PASSWORD', None)
SESSION_TTL = int(os.getenv('SESSION_TTL', 86400))  # 24 hours default
USER_POD_IMAGE = os.getenv('USER_POD_IMAGE', 'us-central1-docker.pkg.dev/hyperbola-476507/docker-repo/ai-environment:latest')
USER_POD_PORT = int(os.getenv('USER_POD_PORT', 1111))

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
        logger.info(f"✅ Redis connected successfully at {REDIS_HOST}:{REDIS_PORT}")
        return r
    except Exception as e:
        logger.error(f"❌ Failed to connect to Redis: {str(e)}")
        raise

try:
    r = init_redis()
except Exception as e:
    logger.error(f"Redis initialization failed: {str(e)}")
    r = None


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
            r.lpush(f"events:{session_uuid}", json.dumps(event))
            r.ltrim(f"events:{session_uuid}", 0, 99)  # Keep last 100 events
            logger.info(f"📝 [{session_uuid}] {event_type}: {details}")
        except Exception as e:
            logger.warning(f"Failed to log event: {str(e)}")


def check_session_exists(session_uuid):
    """Validate session exists in Redis"""
    if not r:
        raise Exception("Redis unavailable")
    
    if not r.exists(f'session:{session_uuid}'):
        raise ValueError(f"Session {session_uuid} not found")
    
    return r.hgetall(f'session:{session_uuid}')


def set_session_ttl(session_uuid):
    """Set TTL for session data"""
    if r:
        try:
            r.expire(f'session:{session_uuid}', SESSION_TTL)
            r.expire(f'queue:{session_uuid}', SESSION_TTL)
        except Exception as e:
            logger.warning(f"Failed to set TTL for {session_uuid}: {str(e)}")

@app.route('/session/create', methods=['POST'])
@handle_errors
@rate_limit(max_requests=100, window=60)
def create_session():
    """Create new session with dedicated pod resources"""
    start_time = time.time()
    
    if not r:
        return {'error': 'Redis unavailable'}, 503
    
    session_uuid = str(uuid.uuid4())[:8]
    user_id = request.json.get('user_id')
    
    if not user_id:
        raise ValueError("user_id is required")
    
    # Sanitize user_id for Kubernetes labels (alphanumeric, -, _, .)
    user_id_label = user_id.replace('@', '-').replace('/', '-').replace(':', '-')
    
    logger.info(f"🆕 Creating session for user: {user_id}")
    
    try:
        # Create deployment for this user
        deployment = client.V1Deployment(
            metadata=client.V1ObjectMeta(
                name=f"user-{session_uuid}",
                labels={"session-uuid": session_uuid, "user-id": user_id_label}
            ),
            spec=client.V1DeploymentSpec(
                replicas=0,
                selector=client.V1LabelSelector(
                    match_labels={"app": f"user-{session_uuid}"}
                ),
                template=client.V1PodTemplateSpec(
                    metadata=client.V1ObjectMeta(
                        labels={"app": f"user-{session_uuid}", "uuid": session_uuid, "user-id": user_id_label}
                    ),
                    spec=client.V1PodSpec(
                        containers=[
                            client.V1Container(
                                name="user-pod",
                                image=USER_POD_IMAGE,
                                ports=[client.V1ContainerPort(container_port=USER_POD_PORT)],
                                resources=client.V1ResourceRequirements(
                                    requests={"memory": "256Mi", "cpu": "250m"},
                                    limits={"memory": "512Mi", "cpu": "500m"}
                                ),
                                env=[
                                    client.V1EnvVar(name="SESSION_UUID", value=session_uuid),
                                    client.V1EnvVar(name="USER_ID", value=user_id)
                                ]
                            )
                        ]
                    )
                )
            )
        )
        
        v1.create_namespaced_deployment(namespace="default", body=deployment)
        logger.info(f"✅ Deployment created: user-{session_uuid}")
        
        # Create service
        service = client.V1Service(
            metadata=client.V1ObjectMeta(
                name=f"user-{session_uuid}",
                labels={"session-uuid": session_uuid}
            ),
            spec=client.V1ServiceSpec(
                selector={"app": f"user-{session_uuid}"},
                ports=[client.V1ServicePort(port=80, target_port=USER_POD_PORT)]
            )
        )
        
        core_v1.create_namespaced_service(namespace="default", body=service)
        logger.info(f"✅ Service created: user-{session_uuid}")
        
        # Create KEDA ScaledObject for this user
        scaledobject = {
            "apiVersion": "keda.sh/v1alpha1",
            "kind": "ScaledObject",
            "metadata": {"name": f"user-{session_uuid}-scaler"},
            "spec": {
                "scaleTargetRef": {"name": f"user-{session_uuid}"},
                "minReplicaCount": 0,
                "maxReplicaCount": 1,
                "pollingInterval": 30,
                "cooldownPeriod": 120,
                "idleReplicaCount": 0,
                "triggers": [{
                    "type": "redis",
                    "metadata": {
                        "address": "redis.default.svc.cluster.local:6379",
                        "listName": f"queue:{session_uuid}",
                        "listLength": "1",
                        "activationListLength": "1",
                        "passwordFromEnv": "REDIS_PASSWORD"
                    },
                    "authenticationRef": {
                        "name": f"redis-auth-{session_uuid}"
                    }
                }]
            }
        }
        
        # Create TriggerAuthentication for Redis password
        trigger_auth = {
            "apiVersion": "keda.sh/v1alpha1",
            "kind": "TriggerAuthentication",
            "metadata": {"name": f"redis-auth-{session_uuid}"},
            "spec": {
                "secretTargetRef": [{
                    "parameter": "password",
                    "name": "redis-credentials",
                    "key": "password"
                }]
            }
        }
        
        custom_api.create_namespaced_custom_object(
            group="keda.sh",
            version="v1alpha1",
            namespace="default",
            plural="triggerauthentications",
            body=trigger_auth
        )
        logger.info(f"✅ KEDA TriggerAuthentication created: redis-auth-{session_uuid}")
        
        custom_api.create_namespaced_custom_object(
            group="keda.sh",
            version="v1alpha1",
            namespace="default",
            plural="scaledobjects",
            body=scaledobject
        )
        logger.info(f"✅ KEDA ScaledObject created: user-{session_uuid}-scaler")
        
        # Store session with TTL
        r.hset(f'session:{session_uuid}', mapping={
            'user_id': user_id,
            'status': 'created',
            'created_at': datetime.utcnow().isoformat(),
            'last_activity': datetime.utcnow().isoformat()
        })
        set_session_ttl(session_uuid)
        
        log_event(session_uuid, 'session_created', {'user_id': user_id})
        
        elapsed = time.time() - start_time
        logger.info(f"🎉 Session created successfully in {elapsed:.2f}s: {session_uuid}")
        
        return jsonify({
            'uuid': session_uuid,
            'user_id': user_id,
            'status': 'created',
            'created_at': datetime.utcnow().isoformat()
        }), 201
        
    except Exception as e:
        logger.error(f"❌ Failed to create session: {str(e)}", exc_info=True)
        raise

@app.route('/session/<session_uuid>/wake', methods=['POST'])
@handle_errors
@rate_limit(max_requests=50, window=60)
def wake_session(session_uuid):
    """Wake up sleeping pod by pushing to Redis queue"""
    if not r:
        return {'error': 'Redis unavailable'}, 503
    
    session_data = check_session_exists(session_uuid)
    
    r.lpush(f'queue:{session_uuid}', 'wake')
    r.hset(f'session:{session_uuid}', 'last_activity', datetime.utcnow().isoformat())
    set_session_ttl(session_uuid)
    
    log_event(session_uuid, 'session_woken', {'user_id': session_data.get('user_id')})
    logger.info(f"⏰ Session woken: {session_uuid}")
    
    return jsonify({
        'uuid': session_uuid,
        'action': 'wake',
        'status': 'queued'
    }), 200

@app.route('/session/<session_uuid>/status')
@handle_errors
@rate_limit(max_requests=200, window=60)
def session_status(session_uuid):
    """Get current session status"""
    if not r:
        return {'error': 'Redis unavailable'}, 503
    
    session_data = check_session_exists(session_uuid)
    queue_length = r.llen(f'queue:{session_uuid}')
    
    try:
        deployment = v1.read_namespaced_deployment(name=f"user-{session_uuid}", namespace="default")
        replicas = deployment.status.replicas or 0
    except ApiException as e:
        logger.warning(f"Deployment not found: {session_uuid}")
        replicas = 0
    
    return jsonify({
        'uuid': session_uuid,
        'session': session_data,
        'queue_length': queue_length,
        'replicas': replicas,
        'timestamp': datetime.utcnow().isoformat()
    }), 200


# ============================================================================
# PRIORITY 1: CHAT ROUTING - Route messages to user pods
# ============================================================================

@app.route('/session/<session_uuid>/chat', methods=['POST'])
@handle_errors
@rate_limit(max_requests=100, window=60)
def chat_message(session_uuid):
    """Route chat message to user's pod"""
    if not r:
        return {'error': 'Redis unavailable'}, 503
    
    session_data = check_session_exists(session_uuid)
    message = request.json.get('message', '')
    
    if not message:
        raise ValueError("message is required")
    
    logger.info(f"💬 Chat message for {session_uuid}: {message[:50]}...")
    
    try:
        # Push message to user's queue (this wakes the pod via KEDA)
        r.lpush(f'queue:{session_uuid}', 'chat')
        
        # Store chat message in session queue with timestamp
        chat_record = {
            'timestamp': datetime.utcnow().isoformat(),
            'type': 'user_message',
            'content': message
        }
        r.lpush(f'chat:{session_uuid}', json.dumps(chat_record))
        r.ltrim(f'chat:{session_uuid}', 0, 999)  # Keep last 1000 messages
        
        # Update activity
        r.hset(f'session:{session_uuid}', 'last_activity', datetime.utcnow().isoformat())
        set_session_ttl(session_uuid)
        
        log_event(session_uuid, 'chat_received', {'message_length': len(message)})
        
        # Wait briefly for pod to start
        time.sleep(0.5)
        
        # Try to forward to user pod
        try:
            deployment = v1.read_namespaced_deployment(name=f"user-{session_uuid}", namespace="default")
            if deployment.status.replicas and deployment.status.replicas > 0:
                pod_service = f"user-{session_uuid}.default.svc.cluster.local"
                response = requests.post(
                    f"http://{pod_service}:80/chat",
                    json={"message": message},
                    timeout=5
                )
                logger.info(f"✅ Message forwarded to pod: {session_uuid}")
                return jsonify({
                    'uuid': session_uuid,
                    'status': 'processed',
                    'pod_response': response.json() if response.ok else None
                }), 200
        except Exception as e:
            logger.warning(f"Pod not ready yet: {str(e)}")
        
        return jsonify({
            'uuid': session_uuid,
            'status': 'queued',
            'message': 'Pod is waking up, message queued'
        }), 202
        
    except Exception as e:
        logger.error(f"❌ Chat routing failed: {str(e)}", exc_info=True)
        raise


# ============================================================================
# PRIORITY 1: SESSION CLEANUP - Delete/Terminate session
# ============================================================================

@app.route('/session/<session_uuid>', methods=['DELETE'])
@handle_errors
@rate_limit(max_requests=50, window=60)
def delete_session(session_uuid):
    """Terminate session and cleanup all resources"""
    if not r:
        return {'error': 'Redis unavailable'}, 503
    
    try:
        session_data = check_session_exists(session_uuid)
        user_id = session_data.get('user_id', 'unknown')
    except ValueError:
        logger.warning(f"Session not found for deletion: {session_uuid}")
        return {'error': 'Session not found'}, 404
    
    logger.info(f"🗑️ Deleting session: {session_uuid}")
    
    try:
        # Delete deployment
        try:
            v1.delete_namespaced_deployment(
                name=f"user-{session_uuid}",
                namespace="default",
                body=client.V1DeleteOptions(grace_period_seconds=30)
            )
            logger.info(f"✅ Deployment deleted: user-{session_uuid}")
        except ApiException as e:
            if e.status != 404:
                raise
            logger.warning(f"Deployment not found: user-{session_uuid}")
        
        # Delete service
        try:
            core_v1.delete_namespaced_service(
                name=f"user-{session_uuid}",
                namespace="default"
            )
            logger.info(f"✅ Service deleted: user-{session_uuid}")
        except ApiException as e:
            if e.status != 404:
                raise
            logger.warning(f"Service not found: user-{session_uuid}")
        
        # Delete KEDA ScaledObject
        try:
            custom_api.delete_namespaced_custom_object(
                group="keda.sh",
                version="v1alpha1",
                namespace="default",
                plural="scaledobjects",
                name=f"user-{session_uuid}-scaler"
            )
            logger.info(f"✅ KEDA ScaledObject deleted: user-{session_uuid}-scaler")
        except ApiException as e:
            if e.status != 404:
                raise
            logger.warning(f"KEDA ScaledObject not found: user-{session_uuid}-scaler")
        
        # Delete KEDA TriggerAuthentication
        try:
            custom_api.delete_namespaced_custom_object(
                group="keda.sh",
                version="v1alpha1",
                namespace="default",
                plural="triggerauthentications",
                name=f"redis-auth-{session_uuid}"
            )
            logger.info(f"✅ KEDA TriggerAuthentication deleted: redis-auth-{session_uuid}")
        except ApiException as e:
            if e.status != 404:
                raise
            logger.warning(f"KEDA TriggerAuthentication not found: redis-auth-{session_uuid}")
        
        # Clean up Redis data
        r.delete(f'session:{session_uuid}')
        r.delete(f'queue:{session_uuid}')
        r.delete(f'chat:{session_uuid}')
        r.delete(f'events:{session_uuid}')
        logger.info(f"✅ Redis data cleaned: {session_uuid}")
        
        log_event(session_uuid, 'session_terminated', {'user_id': user_id})
        
        return jsonify({
            'uuid': session_uuid,
            'status': 'terminated',
            'message': 'Session and all resources deleted'
        }), 200
        
    except Exception as e:
        logger.error(f"❌ Failed to delete session: {str(e)}", exc_info=True)
        raise


# ============================================================================
# PRIORITY 2: SLEEP ENDPOINT - Manual pod sleep
# ============================================================================

@app.route('/session/<session_uuid>/sleep', methods=['POST'])
@handle_errors
@rate_limit(max_requests=50, window=60)
def sleep_session(session_uuid):
    """Manually put session to sleep"""
    if not r:
        return {'error': 'Redis unavailable'}, 503
    
    session_data = check_session_exists(session_uuid)
    
    try:
        # Clear the queue to let KEDA scale to zero
        r.delete(f'queue:{session_uuid}')
        
        # Scale to zero immediately via KEDA
        logger.info(f"😴 Putting session to sleep: {session_uuid}")
        
        # Update session status
        r.hset(f'session:{session_uuid}', 'status', 'sleeping')
        set_session_ttl(session_uuid)
        
        log_event(session_uuid, 'session_sleeping', {'user_id': session_data.get('user_id')})
        
        return jsonify({
            'uuid': session_uuid,
            'action': 'sleep',
            'status': 'sleeping',
            'message': 'Pod queued for sleep'
        }), 200
        
    except Exception as e:
        logger.error(f"❌ Failed to sleep session: {str(e)}", exc_info=True)
        raise


# ============================================================================
# MONITORING & METRICS
# ============================================================================

@app.route('/health')
def health():
    """Health check endpoint"""
    redis_status = "healthy"
    if r:
        try:
            r.ping()
        except:
            redis_status = "unhealthy"
    
    return jsonify({
        'status': 'healthy',
        'redis': redis_status,
        'timestamp': datetime.utcnow().isoformat()
    }), 200


@app.route('/metrics')
@handle_errors
def get_metrics():
    """Get session metrics for monitoring"""
    if not r:
        return {'error': 'Redis unavailable'}, 503
    
    # Get all sessions using pattern match
    session_keys = r.keys('session:*')
    
    metrics = {
        'total_sessions': len(session_keys),
        'active_sessions': 0,
        'sleeping_sessions': 0,
        'timestamp': datetime.utcnow().isoformat()
    }
    
    for key in session_keys:
        session = r.hgetall(key)
        if session.get('status') == 'created':
            metrics['active_sessions'] += 1
        elif session.get('status') == 'sleeping':
            metrics['sleeping_sessions'] += 1
    
    logger.info(f"📊 Metrics: {metrics}")
    return jsonify(metrics), 200


@app.route('/sessions')
@handle_errors
def list_sessions():
    """List all active sessions (for admin/monitoring)"""
    if not r:
        return {'error': 'Redis unavailable'}, 503
    
    session_keys = r.keys('session:*')
    sessions = []
    
    for key in session_keys:
        session_uuid = key.split(':')[1]
        session_data = r.hgetall(key)
        sessions.append({
            'uuid': session_uuid,
            'user_id': session_data.get('user_id'),
            'status': session_data.get('status'),
            'created_at': session_data.get('created_at'),
            'last_activity': session_data.get('last_activity')
        })
    
    return jsonify({
        'total': len(sessions),
        'sessions': sessions
    }), 200

