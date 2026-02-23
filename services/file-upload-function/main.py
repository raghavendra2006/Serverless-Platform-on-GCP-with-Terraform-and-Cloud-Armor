"""
File Upload Cloud Function (2nd Gen) — HTTP Trigger

Accepts multipart/form-data POST requests, saves the uploaded file
to a GCS bucket, and returns 201 with filename and bucket info.
"""

import json
import os
import sys
import traceback

import functions_framework
from google.cloud import storage


# Structured JSON logger
def log(severity: str, message: str, **kwargs):
    """Emit structured JSON logs for Cloud Logging."""
    entry = {
        "severity": severity,
        "message": message,
        "service_context": {"service": "file-upload-function"},
        **kwargs,
    }
    print(json.dumps(entry), file=sys.stdout if severity != "ERROR" else sys.stderr)


# Initialize GCS client
storage_client = storage.Client()
BUCKET_NAME = os.environ.get("GCS_BUCKET_NAME", "")


@functions_framework.http
def upload_file(request):
    """HTTP Cloud Function entry point for file uploads.

    Args:
        request (flask.Request): The incoming HTTP request.

    Returns:
        tuple: (response_body, status_code, headers)
    """
    headers = {"Content-Type": "application/json"}

    # Only accept POST
    if request.method != "POST":
        log("WARNING", "Method not allowed", method=request.method)
        return json.dumps({"error": "Method not allowed. Use POST."}), 405, headers

    try:
        # Check for file in the request
        if "file" not in request.files:
            log("WARNING", "No file provided in request")
            return json.dumps({"error": "No file provided. Include a 'file' field."}), 400, headers

        uploaded_file = request.files["file"]

        if uploaded_file.filename == "":
            log("WARNING", "Empty filename in upload request")
            return json.dumps({"error": "No file selected."}), 400, headers

        filename = uploaded_file.filename

        # Upload to GCS
        bucket = storage_client.bucket(BUCKET_NAME)
        blob = bucket.blob(filename)
        blob.upload_from_file(
            uploaded_file.stream,
            content_type=uploaded_file.content_type or "application/octet-stream",
        )

        log(
            "INFO",
            f"File uploaded successfully: {filename}",
            filename=filename,
            bucket=BUCKET_NAME,
            content_type=uploaded_file.content_type,
        )

        response = {
            "filename": filename,
            "bucket": BUCKET_NAME,
        }
        return json.dumps(response), 201, headers

    except Exception as e:
        log(
            "ERROR",
            f"File upload failed: {str(e)}",
            error=str(e),
            traceback=traceback.format_exc(),
        )
        return json.dumps({"error": "Internal server error"}), 500, headers
