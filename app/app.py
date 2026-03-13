from flask import Flask, render_template
from routes import main
from config import Config
import os
import socket
import platform
import time

app = Flask(__name__)
app.config.from_object(Config)
app.register_blueprint(main)

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

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
