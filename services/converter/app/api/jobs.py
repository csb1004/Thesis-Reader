from fastapi import APIRouter, HTTPException, UploadFile

from services.converter.app.jobs.job_store import job_store
from services.converter.app.jobs.models import JobSnapshot

router = APIRouter()

MAX_UPLOAD_BYTES = 50 * 1024 * 1024
UPLOAD_CHUNK_BYTES = 1024 * 1024


@router.post("/jobs", response_model=JobSnapshot, status_code=201)
async def create_job(file: UploadFile) -> JobSnapshot:
    if file.content_type != "application/pdf":
        raise HTTPException(status_code=415, detail="Only PDF uploads are supported")

    job_id, source_path = job_store.reserve()
    total_bytes = 0

    try:
        with source_path.open("wb") as output:
            while chunk := await file.read(UPLOAD_CHUNK_BYTES):
                total_bytes += len(chunk)
                if total_bytes > MAX_UPLOAD_BYTES:
                    raise HTTPException(status_code=413, detail="Upload exceeds maximum size")
                output.write(chunk)
    except Exception:
        job_store.discard(job_id)
        raise

    return job_store.commit(job_id)


@router.get("/jobs/{job_id}", response_model=JobSnapshot)
def get_job(job_id: str) -> JobSnapshot:
    return job_store.get_or_404(job_id)
