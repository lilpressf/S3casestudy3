from flask import Flask, request, jsonify
from db import dynamodb_table
import uuid

app = Flask(__name__)

@app.route("/employee", methods=["POST"])
def create_employee():
    data = request.json
    employee_id = str(uuid.uuid4())

    item = {
        "employee_id": employee_id,
        "name": data.get("name"),
        "email": data.get("email"),
        "department": data.get("department"),
        "status": "pending_onboarding"
    }

    table = dynamodb_table("innovatech-employees")
    table.put_item(Item=item)

    return jsonify({"message": "Employee created", "employee_id": employee_id}), 201

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
