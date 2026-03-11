from flask import Flask, jsonify, render_template
import os
import socket
import platform
import time

app = Flask(__name__)
START_TIME = time.time()
REQUEST_COUNT = 0

def get_cloud_provider():
    if os.getenv("AWS_REGION") or os.getenv("EKS_CLUSTER"):
        return "AWS EKS", "#FF9900"
    if os.getenv("AKS_CLUSTER") or os.getenv("AZURE_REGION"):
        return "Azure AKS", "#0078D4"
    return "Local Docker", "#2496ED"

@app.route("/")
def home():
    global REQUEST_COUNT
    REQUEST_COUNT += 1
    cloud_name, cloud_color = get_cloud_provider()
    return render_template(
        "index.html",
        hostname=socket.gethostname(),
        environment=os.getenv("APP_ENV", "development"),
        cloud_name=cloud_name,
        cloud_color=cloud_color,
        uptime=int(time.time() - START_TIME),
        request_count=REQUEST_COUNT,
        python_version=platform.python_version(),
    )

@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200

@app.route("/ready")
def ready():
    return jsonify({"status": "ready"}), 200

@app.route("/api/stats")
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
        "python_version": platform.python_version(),
    })

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
