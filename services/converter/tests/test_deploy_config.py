from pathlib import Path


def test_railway_dockerfiles_bind_public_ipv4_for_healthchecks():
    project_root = Path(__file__).resolve().parents[3]

    for relative_path in ("Dockerfile", "services/converter/Dockerfile"):
        dockerfile = (project_root / relative_path).read_text(encoding="utf-8")

        assert "--host 0.0.0.0" in dockerfile
        assert "--host ::" not in dockerfile
