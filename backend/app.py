from flask import Flask, request, jsonify
from boto3.dynamodb.conditions import Key
from db import dynamodb_table
from automation import Automation
from botocore.exceptions import BotoCoreError, ClientError
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
ADMIN_GROUPS = [
    g.strip()
    for g in os.getenv("ADMIN_GROUPS", "IT_Admin").split(",")
    if g.strip()
]

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
    try:
        dynamodb_table(AUDIT_TABLE).put_item(Item=audit)
    except (ClientError, BotoCoreError) as exc:
        # Best-effort only; if DynamoDB is temporarily unreachable,
        # do not fail the whole request.
        print(f"Audit write failed: {exc!r}")


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
    Extract a JWT token from ALB/Cognito headers or Authorization header.

    - For local/dev use, we support Authorization: Bearer <token>
    - Behind the ALB, we primarily rely on X-Amzn-Oidc-Data (ID token)
      and fall back to X-Amzn-Oidc-Accesstoken if needed.
    """
    # Local dev / direct calls
    auth_header = request.headers.get("Authorization")
    if auth_header and auth_header.lower().startswith("bearer "):
        return auth_header.split(" ", 1)[1]

    # ALB OIDC headers (ID token)
    id_token = request.headers.get("X-Amzn-Oidc-Data") or request.headers.get(
        "x-amzn-oidc-data"
    )
    if id_token:
        return id_token

    # Fallback: ALB access token header if present
    alb_access = request.headers.get("X-Amzn-Oidc-Accesstoken") or request.headers.get(
        "x-amzn-oidc-accesstoken"
    )
    if alb_access:
        return alb_access

    raise ValueError("Missing ID/access token")




def verify_token(token: str):
    try:
        jwks = get_jwks()
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
    except Exception as exc:  # noqa: BLE001
        # Normalize any other errors (network, parsing, etc.) into a ValueError
        # so require_auth can always surface a 401 with a readable message.
        raise ValueError(f"Token validation failed: {exc}") from exc



def require_auth(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        if not COGNITO_POOL_ID or not COGNITO_CLIENT_ID:
            return jsonify({"error": "Auth not configured"}), 500

        try:
            token = extract_token()
            # We trust ALB + Cognito to validate the token signature and expiry,
            # so here we only parse claims without re-validating the signature.
            claims = jwt.get_unverified_claims(token)
            request.claims = claims
        except (JWTError, ValueError) as err:
            return jsonify({"error": f"Token parse failed: {err}"}), 401

        return fn(*args, **kwargs)

    return wrapper


def require_admin(fn):
    @require_auth
    @wraps(fn)
    def wrapper(*args, **kwargs):
        claims = getattr(request, "claims", {}) or {}
        groups = claims.get("cognito:groups", [])
        if isinstance(groups, str):
            groups = [groups]
        if not any(g in ADMIN_GROUPS for g in groups):
            return jsonify({"error": "Forbidden"}), 403
        return fn(*args, **kwargs)

    return wrapper


def with_error_handling(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        try:
            return fn(*args, **kwargs)
        except Exception as exc:  # noqa: BLE001
            return (
                jsonify(
                    {
                        "error": "Internal server error",
                        "detail": repr(exc),
                        "exception_type": type(exc).__name__,
                    }
                ),
                500,
            )

    return wrapper


@app.route("/api/health", methods=["GET"])
def health():
    # No bypass flag anymore
    return {"status": "ok"}, 200


@app.route("/api/debug-headers", methods=["GET"])
@require_auth
def debug_headers():
    """
    Debug endpoint so we can see exactly what headers are arriving
    from the ALB after Cognito auth.
    """
    return jsonify(dict(request.headers)), 200


@app.route("/api/onboard", methods=["POST"])
@with_error_handling
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

    try:
        dynamodb_table(EMP_TABLE).put_item(Item=item)
    except (ClientError, BotoCoreError) as exc:
        print(f"Employee put_item failed: {exc!r}")
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

    # Strip sensitive fields (like temporary passwords) from identity details
    identity_safe = identity
    if isinstance(identity_safe, dict):
        # shallow copy
        identity_safe = dict(identity_safe)
        # remove any obvious temp password fields
        identity_safe.pop("temp_password", None)
        for section in ("cognito", "directory"):
            section_val = identity_safe.get(section)
            if isinstance(section_val, dict):
                cleaned = dict(section_val)
                cleaned.pop("temp_password", None)
                identity_safe[section] = cleaned

    workstation_instance_id = (
        workstation.get("instance_id") if isinstance(workstation, dict) else None
    )

    detail = {
        "identity": identity_safe,
        "workstation": workstation,
    }
    identity_status = (
        identity.get("status") if isinstance(identity, dict) else None
    )
    workstation_status = (
        workstation.get("status") if isinstance(workstation, dict) else None
    )

    has_error = False
    if identity_status == "error":
        has_error = True
    if workstation_status == "error":
        has_error = True

    if workstation_status == "skipped":
        has_error = True

    new_status = "onboard_failed" if has_error else "onboard_submitted"

    try:
        dynamodb_table(EMP_TABLE).update_item(
            Key={"employee_id": employee_id},
            UpdateExpression=(
                "SET #s = :status, detail = :detail, workstation_instance_id = :iid"
            ),
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={
                ":status": new_status,
                ":detail": json.dumps(detail),
                ":iid": workstation_instance_id,
            },
        )
    except (ClientError, BotoCoreError) as exc:
        print(f"Employee update_item failed: {exc!r}")

    write_audit(
        "onboard",
        data["email"],
        status="failed" if has_error else "submitted",
        detail=json.dumps(detail),
    )
    response_body = {
        "employee_id": employee_id,
        "detail": detail,
    }
    if has_error:
        response_body["message"] = "Onboarding encountered errors"
        return jsonify(response_body), 500
    else:
        response_body["message"] = "Onboarding started"
        return jsonify(response_body), 201


@app.route("/api/offboard", methods=["POST"])
@with_error_handling
@require_auth
def offboard():
    data = request.json or {}
    email = data.get("email")
    if not email:
        return jsonify({"error": "Missing email"}), 400

    db_unavailable = False
    try:
        resp = dynamodb_table(EMP_TABLE).query(
            IndexName="email-index",
            KeyConditionExpression=Key("email").eq(email),
            Limit=1,
        )
        items = resp.get("Items", [])
    except (ClientError, BotoCoreError) as exc:
        print(f"Employee query in offboard failed: {exc!r}")
        db_unavailable = True
        items = []
    if not items and not db_unavailable:
        return jsonify({"error": "Employee not found"}), 404

    employee = items[0] if items else None
    workstation_instance_id = data.get("workstation_instance_id") or (
        employee.get("workstation_instance_id", "") if employee else ""
    )

    write_audit("offboard", email, status="started")
    identity_status = automator.disable_identity(email)
    workstation_status = automator.terminate_workstation(workstation_instance_id)
    detail = {
        "identity": identity_status,
        "workstation": workstation_status,
    }

    identity_status_value = (
        identity_status.get("status") if isinstance(identity_status, dict) else None
    )
    workstation_status_value = (
        workstation_status.get("status")
        if isinstance(workstation_status, dict)
        else None
    )
    has_error = False
    if identity_status_value == "error":
        has_error = True
    if workstation_status_value == "error":
        has_error = True

    try:
        dynamodb_table(EMP_TABLE).update_item(
            Key={"employee_id": employee["employee_id"]},
            UpdateExpression="SET #s = :status, last_offboard_detail = :detail",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={
                ":status": "offboard_failed" if has_error else "offboard_submitted",
                ":detail": json.dumps(detail),
            },
        )
    except (ClientError, BotoCoreError) as exc:
        print(f"Employee update_item in offboard failed: {exc!r}")

    write_audit(
        "offboard",
        email,
        status="failed" if has_error else "submitted",
        detail=json.dumps(detail),
    )
    response_body = {
        "email": email,
        "detail": detail,
    }
    if has_error:
        response_body["message"] = "Offboarding encountered errors"
        return jsonify(response_body), 500
    else:
        response_body["message"] = "Offboarding started"
        return jsonify(response_body), 200


@app.route("/api/workstation/create", methods=["POST"])
@with_error_handling
@require_auth
def create_workstation():
    data = request.json or {}
    email = data.get("email")
    department = data.get("department")
    if not email or not department:
        return jsonify({"error": "Missing email or department"}), 400

    db_unavailable = False
    try:
        resp = dynamodb_table(EMP_TABLE).query(
            IndexName="email-index",
            KeyConditionExpression=Key("email").eq(email),
            Limit=1,
        )
        items = resp.get("Items", [])
    except (ClientError, BotoCoreError) as exc:
        print(f"Employee query in workstation/create failed: {exc!r}")
        db_unavailable = True
        items = []
    if not items and not db_unavailable:
        return jsonify({"error": "Employee not found"}), 404

    employee = items[0] if items else None

    ws = automator.create_workstation(email=email, department=department)
    detail = {"workstation": ws}

    instance_id = ws.get("instance_id") if isinstance(ws, dict) else None
    status = ws.get("status") if isinstance(ws, dict) else None
    if not instance_id or status in ("error", "skipped"):
        write_audit(
            "create_workstation",
            email,
            status="failed",
            detail=json.dumps(detail),
        )
        return (
            jsonify(
                {
                    "message": "Error creating workstation",
                    "detail": detail,
                }
            ),
            500,
        )

    if employee:
        try:
            dynamodb_table(EMP_TABLE).update_item(
                Key={"employee_id": employee["employee_id"]},
                UpdateExpression="SET workstation_instance_id = :iid",
                ExpressionAttributeValues={":iid": instance_id},
            )
        except (ClientError, BotoCoreError) as exc:
            print(f"Employee update_item in workstation/create failed: {exc!r}")

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
@with_error_handling
@require_auth
def terminate_workstation():
    data = request.json or {}
    email = data.get("email")
    instance_id = data.get("instance_id")
    if not email:
        return jsonify({"error": "Missing email"}), 400

    if not instance_id:
        db_unavailable = False
        try:
            resp = dynamodb_table(EMP_TABLE).query(
                IndexName="email-index",
                KeyConditionExpression=Key("email").eq(email),
                Limit=1,
            )
            items = resp.get("Items", [])
        except (ClientError, BotoCoreError) as exc:
            print(f"Employee query in workstation/terminate failed: {exc!r}")
            db_unavailable = True
            items = []
        if not items and not db_unavailable:
            return jsonify({"error": "Employee not found"}), 404
        employee = items[0] if items else None
        instance_id = employee.get("workstation_instance_id") if employee else None
        if not instance_id:
            return (
                jsonify(
                    {
                        "error": "No workstation_instance_id stored for employee",
                    }
                ),
                400,
            )

    ws_status = automator.terminate_workstation(instance_id)
    detail = {"workstation": ws_status}

    status_value = (
        ws_status.get("status") if isinstance(ws_status, dict) else None
    )
    write_audit(
        "terminate_workstation",
        email,
        status="failed"
        if status_value in ("error", "skipped")
        else "submitted",
        detail=json.dumps(detail),
    )
    if status_value in ("error", "skipped"):
        return (
            jsonify(
                {
                    "message": "Error terminating workstation",
                    "detail": detail,
                }
            ),
            500,
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
