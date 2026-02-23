swagger: "2.0"
info:
  title: "${api_title}"
  description: "Unified API Gateway for the Enterprise Serverless Platform"
  version: "1.0.0"
host: ""
schemes:
  - "https"
produces:
  - "application/json"

paths:
  /upload:
    post:
      summary: "Upload a file to Cloud Storage"
      operationId: "uploadFile"
      x-google-backend:
        address: "${function_upload_url}"
        protocol: "h2"
      consumes:
        - "multipart/form-data"
      parameters:
        - name: "file"
          in: "formData"
          type: "file"
          required: true
          description: "The file to upload"
      responses:
        201:
          description: "File uploaded successfully"
        400:
          description: "Bad request — no file provided"

  /api/items:
    get:
      summary: "List all items from the database"
      operationId: "listItems"
      x-google-backend:
        address: "${cloud_run_url}/items"
        protocol: "h2"
      responses:
        200:
          description: "A JSON array of items"

  /api/health:
    get:
      summary: "Health check endpoint"
      operationId: "healthCheck"
      x-google-backend:
        address: "${cloud_run_url}/health"
        protocol: "h2"
      responses:
        200:
          description: "Service is healthy"
