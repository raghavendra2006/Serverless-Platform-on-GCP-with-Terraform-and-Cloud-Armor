"""
File Process Cloud Function (2nd Gen) — Eventarc Trigger

Triggered when a new object is finalized in the GCS uploads bucket.
Logs file metadata and increments a custom Cloud Monitoring metric.
"""

import json
import os
import sys
import traceback

import functions_framework
from cloudevents.http import CloudEvent
from google.cloud import monitoring_v3


# Structured JSON logger
def log(severity: str, message: str, **kwargs):
    """Emit structured JSON logs for Cloud Logging."""
    entry = {
        "severity": severity,
        "message": message,
        "service_context": {"service": "file-process-function"},
        **kwargs,
    }
    print(json.dumps(entry), file=sys.stdout if severity != "ERROR" else sys.stderr)


# GCP project for metrics
GCP_PROJECT_ID = os.environ.get("GCP_PROJECT_ID", "")

# Custom metric descriptor
METRIC_TYPE = "custom.googleapis.com/files_processed_count"


def increment_custom_metric():
    """Increment the files_processed_count custom metric in Cloud Monitoring."""
    try:
        client = monitoring_v3.MetricServiceClient()
        project_name = f"projects/{GCP_PROJECT_ID}"

        series = monitoring_v3.TimeSeries()
        series.metric.type = METRIC_TYPE
        series.resource.type = "global"

        now = monitoring_v3.TimeInterval()
        from google.protobuf import timestamp_pb2
        import time

        seconds = int(time.time())
        now_ts = timestamp_pb2.Timestamp(seconds=seconds)
        now.end_time = now_ts

        point = monitoring_v3.Point()
        point.interval = now
        point.value.int64_value = 1
        series.points = [point]

        client.create_time_series(
            request={"name": project_name, "time_series": [series]}
        )
        log("INFO", "Custom metric incremented successfully", metric=METRIC_TYPE)

    except Exception as e:
        log("ERROR", f"Failed to write custom metric: {str(e)}", error=str(e))


@functions_framework.cloud_event
def process_file(cloud_event: CloudEvent):
    """Process a newly uploaded file in GCS.

    Triggered by google.cloud.storage.object.v1.finalized events via Eventarc.

    Args:
        cloud_event (CloudEvent): The CloudEvent payload from GCS.
    """
    try:
        data = cloud_event.data

        bucket_name = data.get("bucket", "unknown")
        file_name = data.get("name", "unknown")
        file_size = data.get("size", "unknown")
        content_type = data.get("contentType", "unknown")
        time_created = data.get("timeCreated", "unknown")
        metageneration = data.get("metageneration", "unknown")

        log(
            "INFO",
            f"Processing new file: {file_name}",
            file_metadata={
                "bucket": bucket_name,
                "name": file_name,
                "size": file_size,
                "content_type": content_type,
                "time_created": time_created,
                "metageneration": metageneration,
            },
        )

        # ──────────────────────────────────────────────
        # Add custom processing logic here
        # e.g., extract metadata, generate thumbnails,
        # validate file types, etc.
        # ──────────────────────────────────────────────

        # Increment custom metric
        increment_custom_metric()

        log(
            "INFO",
            f"File processed successfully: {file_name}",
            filename=file_name,
            bucket=bucket_name,
            size=file_size,
        )

    except Exception as e:
        log(
            "ERROR",
            f"File processing failed: {str(e)}",
            error=str(e),
            traceback=traceback.format_exc(),
        )
        raise
