from flask import Flask, request, jsonify
from db import dynamodb_table
from automation import Automation
import os
import uuid
import time
import json
import urllib.request
from jose import jwt, JWTError

app = Flask(__name__)

EMP_TABLE = os.getenv("EMPLOYEE_TABLE", "innovatech-employees")
AUDIT_TABLE = os.getenv("AUDIT_TABLE", "innovatech-audit-logs")
COGNITO_POOL_ID = os.getenv("COGNITO_POOL_ID")
COGNITO_CLIENT_ID = os.getenv("COGNITO_CLIENT_ID")
COGNITO_REGION = os.getenv("AWS_REGION", "eu-central-1")
WORKSPACES_DIRECTORY_ID = os.getenv("WORKSPACES_DIRECTORY_ID", "")
WORKSPACES_BUNDLE_ID = os.getenv("WORKSPACES_BUNDLE_ID", "")
automator = Automation()


def write_audit(action, email, status="started", detail=None):
    audit = {
        "log_id": str(uuid.uuid4()),
        "action": action,
        "email": email,
        "status": status,
        "timestamp": int(time.time()),
    }
    if detail:
        audit["detail"] = detail
    dynamodb_table(AUDIT_TABLE).put_item(Item=audit)


def get_jwks():
    url = f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{COGNITO_POOL_ID}/.well-known/jwks.json"
    with urllib.request.urlopen(url) as resp:
        body = resp.read()
    return json.loads(body.decode("utf-8"))


def verify_token(auth_header: str):
    if not auth_header or not auth_header.startswith("Bearer "):
        raise ValueError("Missing or invalid Authorization header")
    token = auth_header.split(" ", 1)[1]
    jwks = get_jwks()
    try:
        unverified = jwt.get_unverified_header(token)
        kid = unverified.get("kid")
        key = next((k for k in jwks["keys"] if k["kid"] == kid), None)
        if not key:
            raise ValueError("No matching JWK")
        claims = jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            audience=COGNITO_CLIENT_ID,
            issuer=f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{COGNITO_POOL_ID}",
        )
        return claims
    except JWTError as exc:
        raise ValueError(f"Token validation failed: {exc}") from exc


def require_auth(fn):
    def wrapper(*args, **kwargs):
        if not COGNITO_POOL_ID or not COGNITO_CLIENT_ID:
            return jsonify({"error": "Auth not configured"}), 500
        auth = request.headers.get("Authorization")
        try:
            claims = verify_token(auth)
            request.claims = claims
        except ValueError as err:
            return jsonify({"error": str(err)}), 401
        return fn(*args, **kwargs)

    wrapper.__name__ = fn.__name__
    return wrapper


@app.route("/api/health", methods=["GET"])
def health():
    return {"status": "ok"}, 200


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
    workspace = automator.provision_workspace(email=data["email"])

    detail = {"identity": identity, "workspace": workspace}
    write_audit("onboard", data["email"], status="submitted", detail=json.dumps(detail))
    return jsonify({"message": "Onboarding started", "employee_id": employee_id, "detail": detail}), 201


@app.route("/api/offboard", methods=["POST"])
@require_auth
def offboard():
    data = request.json or {}
    email = data.get("email")
    if not email:
        return jsonify({"error": "Missing email"}), 400

    write_audit("offboard", email, status="started")
    ws_status = automator.terminate_workspace(data.get("workspace_id", ""))
    identity_status = automator.disable_identity(email)
    detail = {"workspace": ws_status, "identity": identity_status}
    write_audit("offboard", email, status="submitted", detail=json.dumps(detail))
    return jsonify({"message": "Offboarding started", "email": email, "detail": detail}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
