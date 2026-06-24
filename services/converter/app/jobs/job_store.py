from pathlib import Path
from shutil import rmtree
from uuid import uuid4

from fastapi import HTTPException

from services.converter.app.jobs.models import JobSnapshot, JobStatus


class JobStore:
    def __init__(self, data_dir: Path | None = None) -> None:
        converter_root = Path(__file__).resolve().parents[2]
        self._data_dir = data_dir or converter_root / ".data" / "jobs"
        self._jobs: dict[str, JobSnapshot] = {}

    def reserve(self) -> tuple[str, Path]:
        job_id = str(uuid4())
        job_dir = self._data_dir / job_id
        job_dir.mkdir(parents=True, exist_ok=False)
        return job_id, job_dir / "source.pdf"

    def commit(self, job_id: str) -> JobSnapshot:
        snapshot = JobSnapshot(jobId=job_id, status=JobStatus.queued)
        self._jobs[job_id] = snapshot
        return snapshot

    def discard(self, job_id: str) -> None:
        self._jobs.pop(job_id, None)
        rmtree(self._data_dir / job_id, ignore_errors=True)

    def create(self, data: bytes) -> JobSnapshot:
        job_id, source_path = self.reserve()
        source_path.write_bytes(data)
        return self.commit(job_id)

    def get_or_404(self, job_id: str) -> JobSnapshot:
        try:
            return self._jobs[job_id]
        except KeyError as exc:
            raise HTTPException(status_code=404, detail="Job not found") from exc


job_store = JobStore()
