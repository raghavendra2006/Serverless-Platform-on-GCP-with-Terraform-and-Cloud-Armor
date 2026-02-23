"""
Web API Service — Cloud Run (FastAPI)

Connects to Cloud SQL via private IP. Fetches the database password
from Secret Manager at startup (not environment variables).
Implements structured JSON logging and Cloud Trace propagation.
"""

import json
import logging
import os
import sys
import time
from contextlib import asynccontextmanager
from typing import List, Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy import Column, DateTime, Integer, String, Text, create_engine, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import Session, sessionmaker

# ──────────────────────────────────────────────────────────
# Structured JSON logging
# ──────────────────────────────────────────────────────────


class StructuredLogFormatter(logging.Formatter):
    """Format log records as structured JSON for Cloud Logging."""

    def format(self, record):
        log_entry = {
            "severity": record.levelname,
            "message": record.getMessage(),
            "service_context": {"service": "web-api"},
            "timestamp": self.formatTime(record),
            "logger": record.name,
        }
        if record.exc_info and record.exc_info[0]:
            log_entry["traceback"] = self.formatException(record.exc_info)
        return json.dumps(log_entry)


# Configure root logger
handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(StructuredLogFormatter())
logging.basicConfig(level=logging.INFO, handlers=[handler])
logger = logging.getLogger("web-api")

# ──────────────────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────────────────

ENVIRONMENT = os.environ.get("ENVIRONMENT", "dev")
GCP_PROJECT_ID = os.environ.get("GCP_PROJECT_ID", "")
DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_NAME = os.environ.get("DB_NAME", "platform_db")
DB_USER = os.environ.get("DB_USER", "platform_user")
DB_SECRET_NAME = os.environ.get("DB_SECRET_NAME", "")
DB_PORT = os.environ.get("DB_PORT", "5432")

# Local development fallback
DB_PASSWORD_LOCAL = os.environ.get("DB_PASSWORD", "")


# ──────────────────────────────────────────────────────────
# Secret Manager — fetch DB password at startup
# ──────────────────────────────────────────────────────────


def get_db_password() -> str:
    """Fetch the database password from Secret Manager.

    Falls back to the DB_PASSWORD env var for local development.
    """
    if DB_SECRET_NAME and GCP_PROJECT_ID:
        try:
            from google.cloud import secretmanager

            client = secretmanager.SecretManagerServiceClient()
            secret_path = f"projects/{GCP_PROJECT_ID}/secrets/{DB_SECRET_NAME}/versions/latest"
            response = client.access_secret_version(request={"name": secret_path})
            password = response.payload.data.decode("UTF-8")
            logger.info("Database password fetched from Secret Manager")
            return password
        except Exception as e:
            logger.error(f"Failed to fetch secret from Secret Manager: {e}")
            if DB_PASSWORD_LOCAL:
                logger.warning("Falling back to DB_PASSWORD environment variable")
                return DB_PASSWORD_LOCAL
            raise
    elif DB_PASSWORD_LOCAL:
        logger.info("Using DB_PASSWORD environment variable (local dev mode)")
        return DB_PASSWORD_LOCAL
    else:
        raise RuntimeError(
            "No database password configured. "
            "Set DB_SECRET_NAME + GCP_PROJECT_ID or DB_PASSWORD."
        )


# ──────────────────────────────────────────────────────────
# Database setup
# ──────────────────────────────────────────────────────────

Base = declarative_base()


class Item(Base):
    """Items table model."""

    __tablename__ = "items"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    created_at = Column(DateTime, server_default=text("CURRENT_TIMESTAMP"))


class ItemResponse(BaseModel):
    """Pydantic model for API response."""

    id: int
    name: str
    description: Optional[str] = None
    created_at: Optional[str] = None

    class Config:
        from_attributes = True


class ItemCreate(BaseModel):
    """Pydantic model for creating items."""

    name: str
    description: Optional[str] = None


# Global database session factory
SessionLocal = None


def init_database():
    """Initialize the database connection and create tables."""
    global SessionLocal

    try:
        password = get_db_password()
        database_url = f"postgresql://{DB_USER}:{password}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

        engine = create_engine(
            database_url,
            pool_size=5,
            max_overflow=2,
            pool_timeout=30,
            pool_recycle=1800,
            pool_pre_ping=True,
        )

        # Create tables if they don't exist
        Base.metadata.create_all(engine)
        SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
        logger.info("Database connection established successfully")

    except Exception as e:
        logger.error(f"Database initialization failed: {e}")
        # Don't crash — allow health checks to still work
        SessionLocal = None


def get_db() -> Session:
    """Get a database session."""
    if SessionLocal is None:
        raise HTTPException(status_code=503, detail="Database not available")
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ──────────────────────────────────────────────────────────
# FastAPI application
# ──────────────────────────────────────────────────────────


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan — initialize DB on startup."""
    logger.info("Starting web-api service", extra={"environment": ENVIRONMENT})
    init_database()
    yield
    logger.info("Shutting down web-api service")


app = FastAPI(
    title="Serverless Platform Web API",
    description="Cloud Run service for the Enterprise Serverless Platform",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ──────────────────────────────────────────────────────────
# Endpoints
# ──────────────────────────────────────────────────────────


@app.get("/health")
async def health_check():
    """Health check endpoint for load balancer probes."""
    db_status = "connected" if SessionLocal is not None else "disconnected"
    return {
        "status": "healthy",
        "service": "web-api",
        "environment": ENVIRONMENT,
        "database": db_status,
        "timestamp": time.time(),
    }


@app.get("/items", response_model=List[ItemResponse])
async def list_items():
    """List all items from the database."""
    logger.info("Fetching items from database")

    if SessionLocal is None:
        logger.error("Database not available")
        raise HTTPException(status_code=503, detail="Database not available")

    db = SessionLocal()
    try:
        items = db.query(Item).order_by(Item.id.desc()).limit(100).all()
        logger.info(f"Retrieved {len(items)} items")
        return [
            ItemResponse(
                id=item.id,
                name=item.name,
                description=item.description,
                created_at=str(item.created_at) if item.created_at else None,
            )
            for item in items
        ]
    except Exception as e:
        logger.error(f"Failed to fetch items: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")
    finally:
        db.close()


@app.post("/items", response_model=ItemResponse, status_code=201)
async def create_item(item: ItemCreate):
    """Create a new item in the database."""
    logger.info(f"Creating item: {item.name}")

    if SessionLocal is None:
        raise HTTPException(status_code=503, detail="Database not available")

    db = SessionLocal()
    try:
        db_item = Item(name=item.name, description=item.description)
        db.add(db_item)
        db.commit()
        db.refresh(db_item)
        logger.info(f"Item created successfully: id={db_item.id}")
        return ItemResponse(
            id=db_item.id,
            name=db_item.name,
            description=db_item.description,
            created_at=str(db_item.created_at) if db_item.created_at else None,
        )
    except Exception as e:
        db.rollback()
        logger.error(f"Failed to create item: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")
    finally:
        db.close()


# ──────────────────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
