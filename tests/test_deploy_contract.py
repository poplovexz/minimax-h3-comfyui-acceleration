import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).parents[1]
DEPLOY = ROOT / "deploy"


def read_script(name: str) -> str:
    return (DEPLOY / name).read_text(encoding="utf-8")


def test_all_deploy_scripts_have_valid_shell_syntax():
    scripts = sorted(DEPLOY.glob("*.sh"))
    assert scripts
    for script in scripts:
        subprocess.run(["bash", "-n", str(script)], check=True)


def test_notebook_uses_non_blocking_launcher_and_status_checker():
    notebook = json.loads((ROOT / "notebooks/deploy_h3.ipynb").read_text(encoding="utf-8"))
    code = ["".join(cell["source"]) for cell in notebook["cells"] if cell["cell_type"] == "code"]

    assert code[0] == "!bash ../deploy/launch.sh"
    assert code[1] == "!bash ../deploy/check_status.sh"


def test_bootstrap_is_single_instance_and_reports_real_result():
    script = read_script("bootstrap.sh")

    assert "flock -n 8" in script
    assert 'write_h3_status "models" "ready"' in script
    assert 'write_h3_status "models" "downloading"' in script
    assert 'write_h3_status "services" "failed"' in script
    assert "bootstrap 未通过完整健康检查" in script


def test_ssh_install_waits_for_apt_lock_and_has_network_timeouts():
    script = read_script("enable_ssh.sh")

    assert "DPkg::Lock::Timeout" in script
    assert "Acquire::http::Timeout" in script
    assert "Acquire::https::Timeout" in script
    assert 'timeout --kill-after=10s "$APT_TIMEOUT_SEC"' in script


def test_comfyui_setup_preserves_rocm_torch_and_requires_dependencies():
    script = read_script("setup_instance.sh")

    assert 'staging_dir="${COMFY_DIR}.clone.${clone_index}.$$"' in script
    assert "所有 ComfyUI 镜像源均克隆失败" in script
    assert "grep -Ev '^(torch|torchvision|torchaudio)" in script
    assert 'timeout "${H3_PIP_TIMEOUT_SEC:-900}"' in script
    assert "install_into_comfyui.py" in script
    assert "--force || true" not in script


def test_model_download_has_dedicated_worker_and_completion_marker():
    bootstrap = read_script("bootstrap.sh")
    downloader = read_script("download_models_modelscope.sh")
    worker = read_script("model_worker.sh")

    assert 'MODEL_PID_FILE="$H3_RUNTIME_DIR/model-worker.pid"' in bootstrap
    assert 'touch "$MODELS/.core.complete"' in downloader
    assert 'write_h3_status "models" "ready"' in worker


def test_comfyui_health_check_is_quiet_and_long_enough_for_first_boot():
    script = read_script("start_comfyui.sh")

    assert '${H3_READY_TIMEOUT_SEC:-180}' in script
    assert '2>/dev/null' in script
    assert "comfyui-process.log" in script
