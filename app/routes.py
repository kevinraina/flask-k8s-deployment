from flask import Blueprint, jsonify
import socket
import os
import time

main = Blueprint("main", __name__)
START_TIME = time.time()
REQUEST_COUNT = 0

def get_cloud_provider():
    if os.getenv("AWS_REGION") or os.getenv("EKS_CLUSTER"):
        return "AWS EKS", "#FF9900"
    if os.getenv("AKS_CLUSTER") or os.getenv("AZURE_REGION"):
        return "Azure AKS", "#0078D4"
    return "Local Docker", "#2496ED"

@main.route("/api/stats")
def stats():
    global REQUEST_COUNT
    REQUEST_COUNT += 1
    cloud_name, _ = get_cloud_provider()
    return jsonify({
        "hostname": socket.gethostname(),
        "environment": os.getenv("APP_ENV", "development"),
        "cloud": cloud_name,
        "uptime_seconds": int(time.time() - START_TIME),
        "request_count": REQUEST_COUNT,
    })

@main.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200

@main.route("/ready")
def ready():
    return jsonify({"status": "ready"}), 200
