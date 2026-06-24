from enum import Enum

from pydantic import BaseModel


class JobStatus(str, Enum):
    queued = "queued"
    processing = "processing"
    succeeded = "succeeded"
    failed = "failed"


class JobSnapshot(BaseModel):
    jobId: str
    status: JobStatus
    error: str | None = None
