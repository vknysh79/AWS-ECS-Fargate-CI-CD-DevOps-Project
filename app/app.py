from flask import Flask, jsonify
import socket
import os

app = Flask(__name__)

@app.route("/")
def health_check():
    return jsonify({
        "status": "healthy",
        "message": "AWS ECS Fargate CI/CD Pipeline Running Successfully! 🚀",
        "hostname": socket.gethostname(),
        "environment": os.getenv("ENVIRONMENT", "production")
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
