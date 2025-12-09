from flask import Flask, request, jsonify
from boto3.dynamodb.conditions import Key
from db import dynamodb_table
from automation import Automation
import os
import uuid
import time
import json
import urllib.request
from jose import jwt, JWTError
from functools import wraps

app = Flask(__name__)

EMP_TABLE = os.getenv("EMPLOYEE_TABLE", "innovatech-employees")
AUDIT_TABLE = os.getenv("AUDIT_TABLE", "innovatech-audit-logs")
COGNITO_POOL_ID = os.getenv("COGNITO_POOL_ID")
COGNITO_CLIENT_ID = os.getenv("COGNITO_CLIENT_ID")
COGNITO_REGION = os.getenv("AWS_REGION", "eu-central-1")

automator = Automation()

# Simple in-memory JWKS cache
_JWKS_CACHE = None
_JWKS_CACHE_TS = 0
_JWKS_TTL_SECONDS = 300  # 5 minutes


def write_audit(action, email, status="started", detail=None):
    audit = {
        "log_id": str(uuid.uuid4()),
        "action": action,
        "email": email,
        "status": status,
        "timestamp": int(time.time()),
    }
    if detail is not None:
        audit["detail"] = detail
    dynamodb_table(AUDIT_TABLE).put_item(Item=audit)


def get_jwks():
    """Fetch JWKS from Cognito, with a small in-memory cache."""
    global _JWKS_CACHE, _JWKS_CACHE_TS

    now = time.time()
    if _JWKS_CACHE is not None and now - _JWKS_CACHE_TS < _JWKS_TTL_SECONDS:
        return _JWKS_CACHE

    if not COGNITO_POOL_ID:
        raise RuntimeError("COGNITO_POOL_ID is not configured")

    url = (
        f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/"
        f"{COGNITO_POOL_ID}/.well-known/jwks.json"
    )
    with urllib.request.urlopen(url) as resp:
        body = resp.read()
    jwks = json.loads(body.decode("utf-8"))

    _JWKS_CACHE = jwks
    _JWKS_CACHE_TS = now
    return jwks


def extract_token():
    """
    Extract JWT from Authorization header or ALB OIDC headers.
    We support multiple header shapes to handle ALB/Cognito variants.
    """
    # Standard Authorization header
    auth_header = request.headers.get("Authorization")
    if auth_header and auth_header.startswith("Bearer "):
        return auth_header.split(" ", 1)[1]

    # ALB OIDC authentication can inject the token in x-amzn-oidc-data
    alb_oidc = request.headers.get("x-amzn-oidc-data")
    if alb_oidc:
        return alb_oidc

    # Some configurations put the access token in this header
    alb_access = request.headers.get("x-amzn-oidc-accesstoken")
    if alb_access:
        return alb_access

    raise ValueError("Missing or invalid Authorization header")


def verify_token(token: str):
    jwks = get_jwks()
    try:
        unverified = jwt.get_unverified_header(token)
        kid = unverified.get("kid")
        key = next((k for k in jwks["keys"] if k.get("kid") == kid), None)
        if not key:
            raise ValueError("No matching JWK for token")

        claims = jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            audience=COGNITO_CLIENT_ID,
            issuer=(
                f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/"
                f"{COGNITO_POOL_ID}"
            ),
        )
        return claims
    except JWTError as exc:
        raise ValueError(f"Token validation failed: {exc}") from exc


def require_auth(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        if not COGNITO_POOL_ID or not COGNITO_CLIENT_ID:
            return jsonify({"error": "Auth not configured"}), 500

        try:
            token = extract_token()
            claims = verify_token(token)
            # attach claims to the request for downstream handlers
            request.claims = claims
        except ValueError as err:
            return jsonify({"error": str(err)}), 401

        return fn(*args, **kwargs)

    return wrapper


@app.route("/api/health", methods=["GET"])
def health():
    # No bypass flag anymore
    return {"status": "ok"}, 200


@app.route("/api/debug-headers", methods=["GET"])
def debug_headers():
    """
    Debug endpoint so we can see exactly what headers are arriving
    from the ALB after Cognito auth.
    """
    return jsonify(dict(request.headers)), 200


@app.route("/api/onboard", methods=["POST"])
@require_auth
def onboard():
    data = request.json or {}
    required = ["name", "email", "department", "role"]
    missing = [f for f in required if not data.get(f)]
    if missing:
        return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

    employee_id = str(uuid.uuid4())
    item = {
        "employee_id": employee_id,
        "name": data["name"],
        "email": data["email"],
        "department": data["department"],
        "role": data["role"],
        "status": "pending_onboarding",
    }

    dynamodb_table(EMP_TABLE).put_item(Item=item)
    write_audit("onboard", data["email"], status="started")

    identity = automator.onboard_identity(
        email=data["email"],
        name=data["name"],
        group=data["department"],
    )
    workstation = automator.create_workstation(
        email=data["email"],
        department=data["department"],
    )

    workstation_instance_id = (
        workstation.get("instance_id") if isinstance(workstation, dict) else None
    )
    detail = {
        "identity": identity,
        "workstation": workstation,
    }

    # Persist workstation instance id and status
    dynamodb_table(EMP_TABLE).update_item(
        Key={"employee_id": employee_id},
        UpdateExpression=(
            "SET #s = :status, detail = :detail, workstation_instance_id = :iid"
        ),
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={
            ":status": "onboard_submitted",
            ":detail": json.dumps(detail),
            ":iid": workstation_instance_id,
        },
    )

    write_audit(
        "onboard",
        data["email"],
        status="submitted",
        detail=json.dumps(detail),
    )
    return (
        jsonify(
            {
                "message": "Onboarding started",
                "employee_id": employee_id,
                "detail": detail,
            }
        ),
        201,
    )


@app.route("/api/offboard", methods=["POST"])
@require_auth
def offboard():
    data = request.json or {}
    email = data.get("email")
    if not email:
        return jsonify({"error": "Missing email"}), 400

    # Lookup employee record by email (GSI)
    resp = dynamodb_table(EMP_TABLE).query(
        IndexName="email-index",
        KeyConditionExpression=Key("email").eq(email),
        Limit=1,
    )
    items = resp.get("Items", [])
    if not items:
        return jsonify({"error": "Employee not found"}), 404

    employee = items[0]
    workstation_instance_id = data.get("workstation_instance_id") or employee.get(
        "workstation_instance_id", ""
    )

    write_audit("offboard", email, status="started")
    identity_status = automator.disable_identity(email)
    workstation_status = automator.terminate_workstation(workstation_instance_id)
    detail = {
        "identity": identity_status,
        "workstation": workstation_status,
    }

    dynamodb_table(EMP_TABLE).update_item(
        Key={"employee_id": employee["employee_id"]},
        UpdateExpression="SET #s = :status, last_offboard_detail = :detail",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={
            ":status": "offboard_submitted",
            ":detail": json.dumps(detail),
        },
    )

    write_audit(
        "offboard",
        email,
        status="submitted",
        detail=json.dumps(detail),
    )
    return (
        jsonify(
            {
                "message": "Offboarding started",
                "email": email,
                "detail": detail,
            }
        ),
        200,
    )


@app.route("/api/workstation/create", methods=["POST"])
@require_auth
def create_workstation():
    data = request.json or {}
    email = data.get("email")
    department = data.get("department")
    if not email or not department:
        return jsonify({"error": "Missing email or department"}), 400

    # Validate that the employee exists
    resp = dynamodb_table(EMP_TABLE).query(
        IndexName="email-index",
        KeyConditionExpression=Key("email").eq(email),
        Limit=1,
    )
    items = resp.get("Items", [])
    if not items:
        return jsonify({"error": "Employee not found"}), 404

    employee = items[0]

    ws = automator.create_workstation(email=email, department=department)
    detail = {"workstation": ws}

    instance_id = ws.get("instance_id") if isinstance(ws, dict) else None
    if instance_id:
        dynamodb_table(EMP_TABLE).update_item(
            Key={"employee_id": employee["employee_id"]},
            UpdateExpression="SET workstation_instance_id = :iid",
            ExpressionAttributeValues={":iid": instance_id},
        )

    write_audit(
        "create_workstation",
        email,
        status="submitted",
        detail=json.dumps(detail),
    )
    return (
        jsonify(
            {
                "message": "Workstation creation started",
                "detail": detail,
            }
        ),
        201,
    )


@app.route("/api/workstation/terminate", methods=["POST"])
@require_auth
def terminate_workstation():
    data = request.json or {}
    email = data.get("email")
    instance_id = data.get("instance_id")
    if not email:
        return jsonify({"error": "Missing email"}), 400

    if not instance_id:
        resp = dynamodb_table(EMP_TABLE).query(
            IndexName="email-index",
            KeyConditionExpression=Key("email").eq(email),
            Limit=1,
        )
        items = resp.get("Items", [])
        if not items:
            return jsonify({"error": "Employee not found"}), 404
        employee = items[0]
        instance_id = employee.get("workstation_instance_id")

    ws_status = automator.terminate_workstation(instance_id)
    detail = {"workstation": ws_status}

    write_audit(
        "terminate_workstation",
        email,
        status="submitted",
        detail=json.dumps(detail),
    )
    return (
        jsonify(
            {
                "message": "Workstation termination started",
                "detail": detail,
            }
        ),
        200,
    )


if __name__ == "__main__":
    # For local dev only; in Kubernetes we use Gunicorn (see Dockerfile)
    app.run(host="0.0.0.0", port=5000)