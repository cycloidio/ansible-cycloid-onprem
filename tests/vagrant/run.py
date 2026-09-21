#!/usr/bin/env python3
"""Local Vagrant acceptance runner for the on-premise installer."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import time
import uuid
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence


HARNESS_ROOT = Path(__file__).resolve().parent
REPO_ROOT = HARNESS_ROOT.parents[1]
WORK_ROOT = HARNESS_ROOT / ".work"
MATRIX_PATH = HARNESS_ROOT / "matrix.json"
ANSI_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
SENSITIVE_RE = re.compile(
    r"(?i)((?:[a-z0-9_.-]*(?:password|passwd|pwd|secret|token|licen[cs]e|"
    r"private[_ -]?key|unseal[_ -]?key|access[_ -]?key)[a-z0-9_.-]*)"
    r"\s*(?:[:=]|\s)\s*)([^\s,;]+)"
)


class HarnessError(RuntimeError):
    pass


@dataclass
class Result:
    machine: str
    phase: str
    seconds: float
    error: str | None = None


def load_matrix(path: Path = MATRIX_PATH) -> dict:
    data = json.loads(path.read_text())
    if data.get("schema") != 1:
        raise HarnessError(f"unsupported matrix schema in {path}")
    if data.get("provider") != "libvirt":
        raise HarnessError("this harness currently supports the libvirt provider only")
    machines = data.get("machines")
    if not isinstance(machines, dict) or not machines:
        raise HarnessError("matrix must define at least one machine")
    required = {"distribution", "release", "box", "box_version"}
    for name, machine in machines.items():
        missing = sorted(required - set(machine))
        if missing:
            raise HarnessError(
                f"matrix machine {name!r} is missing: {', '.join(missing)}"
            )
    return data


def redact(text: str) -> str:
    text = ANSI_RE.sub("", text)
    text = SENSITIVE_RE.sub(lambda match: f"{match.group(1)}[REDACTED]", text)
    return re.sub(r"(?i)(authorization\s*:\s*bearer\s+)\S+", r"\1[REDACTED]", text)


def secure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=False)
    path.chmod(0o700)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def tracked_files(repo: Path = REPO_ROOT) -> list[Path]:
    completed = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=repo,
        check=True,
        stdout=subprocess.PIPE,
    )
    return [repo / item.decode() for item in completed.stdout.split(b"\0") if item]


def create_candidate_archive(destination: Path, repo: Path = REPO_ROOT) -> None:
    with tarfile.open(destination, "w:gz", format=tarfile.PAX_FORMAT) as archive:
        for path in tracked_files(repo):
            if path.is_file() or path.is_symlink():
                archive.add(
                    path,
                    arcname=Path("ansible-cycloid-onprem") / path.relative_to(repo),
                    recursive=False,
                )
    destination.chmod(0o600)


def vagrant_env(
    config: Path | None = None, run_dir: Path | None = None
) -> dict[str, str]:
    env = os.environ.copy()
    env["VAGRANT_CWD"] = str(HARNESS_ROOT)
    if config:
        env["CYCLOID_ACCEPTANCE_CONFIG"] = str(config)
    if run_dir:
        env["VAGRANT_DOTFILE_PATH"] = str(run_dir / "vagrant-state")
    return env


def tail(path: Path, lines: int = 35) -> str:
    if not path.exists():
        return ""
    return "\n".join(path.read_text(errors="replace").splitlines()[-lines:])


def run_logged(
    command: Sequence[str],
    log: Path,
    *,
    env: dict[str, str],
    check: bool = True,
) -> subprocess.CompletedProcess:
    log.parent.mkdir(parents=True, exist_ok=True)
    log.parent.chmod(0o700)
    descriptor = os.open(log, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "wb") as stream:
        completed = subprocess.run(
            list(command),
            cwd=HARNESS_ROOT,
            env=env,
            stdout=stream,
            stderr=subprocess.STDOUT,
        )
    if check and completed.returncode:
        raise HarnessError(
            f"command failed ({completed.returncode}): {' '.join(command)}; "
            f"restricted log: {log}"
        )
    return completed


def capture(command: Sequence[str], *, env: dict[str, str] | None = None) -> str:
    completed = subprocess.run(
        list(command),
        cwd=HARNESS_ROOT,
        env=env,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    return completed.stdout.strip()


def preflight(_: argparse.Namespace) -> int:
    matrix = load_matrix()
    if not shutil.which("vagrant"):
        raise HarnessError("vagrant is not installed or not on PATH")
    version = capture(["vagrant", "--version"])
    plugins = capture(["vagrant", "plugin", "list"])
    if "vagrant-libvirt" not in plugins:
        raise HarnessError("the vagrant-libvirt plugin is required")
    capture(["vagrant", "validate"], env=vagrant_env())
    if not shutil.which("virsh"):
        raise HarnessError("virsh is required for the libvirt preflight")
    capture(["virsh", "-r", "-c", "qemu:///system", "list", "--all"])
    print(f"Vagrant: {version}")
    print(
        f"Provider: {matrix['provider']} (vagrant-libvirt installed; system libvirt readable)"
    )
    for name, machine in matrix["machines"].items():
        print(
            f"{name}: {machine['distribution']} {machine['release']} — {machine['box']} {machine['box_version']}"
        )
    return 0


def machine_names(selection: str, matrix: dict) -> list[str]:
    known = matrix["machines"]
    if selection == "all":
        return list(known)
    names = [item.strip() for item in selection.split(",") if item.strip()]
    if not names:
        raise HarnessError("--os must name at least one machine")
    unknown = sorted(set(names) - set(known))
    if unknown:
        raise HarnessError(
            f"unknown OS in --os: {', '.join(unknown)}; known machines: {', '.join(known)}"
        )
    seen: list[str] = []
    for name in names:
        if name not in seen:
            seen.append(name)
    return seen


def write_junit(path: Path, results: Iterable[Result]) -> None:
    items = list(results)
    suite = ET.Element(
        "testsuite",
        name="ansible-cycloid-onprem-vagrant",
        tests=str(len(items)),
        failures=str(sum(result.error is not None for result in items)),
        time=f"{sum(result.seconds for result in items):.3f}",
    )
    for result in items:
        case = ET.SubElement(
            suite,
            "testcase",
            classname=result.machine,
            name=result.phase,
            time=f"{result.seconds:.3f}",
        )
        if result.error:
            failure = ET.SubElement(
                case, "failure", message=redact(result.error).splitlines()[0]
            )
            failure.text = redact(result.error)
    ET.ElementTree(suite).write(path, encoding="utf-8", xml_declaration=True)
    path.chmod(0o600)


def stage(results: list[Result], machine: str, phase: str, action) -> bool:
    started = time.monotonic()
    try:
        action()
    except Exception as exc:  # keep running the remaining matrix for a complete report
        results.append(Result(machine, phase, time.monotonic() - started, str(exc)))
        return False
    results.append(Result(machine, phase, time.monotonic() - started))
    return True


def ssh_config(machine: str, run_dir: Path, env: dict[str, str]) -> Path:
    path = run_dir / "ssh" / f"{machine}.config"
    output = capture(["vagrant", "ssh-config", machine], env=env)
    lines = output.splitlines()
    try:
        start = next(
            index for index, line in enumerate(lines) if line.startswith("Host ")
        )
    except StopIteration as exc:
        raise HarnessError(
            f"Vagrant did not return SSH configuration for {machine}"
        ) from exc
    path.parent.mkdir(parents=True, exist_ok=True)
    path.parent.chmod(0o700)
    path.write_text("\n".join(lines[start:]) + "\n")
    path.chmod(0o600)
    return path


def remote(
    machine: str, config: Path, script: str, phase: str | None = None
) -> list[str]:
    command = f"sudo /usr/local/lib/cycloid-acceptance/{script}"
    if phase:
        command += f" {phase}"
    return ["ssh", "-F", str(config), machine, command]


def valid_identifier(value: str, label: str) -> str:
    if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_.-]*", value):
        raise HarnessError(f"invalid {label}: {value!r}")
    return value


def collect_machine(
    machine: str,
    phase: str,
    run_dir: Path,
    env: dict[str, str],
    config: Path,
) -> None:
    valid_identifier(phase, "collection phase")
    run_logged(
        remote(machine, config, "collect.sh", phase),
        run_dir / "artifacts" / f"{machine}-{phase}.log",
        env=env,
    )


def collect_private_log(
    machine: str, config: Path, name: str, run_dir: Path, env: dict[str, str]
) -> None:
    valid_identifier(name, "guest log name")
    run_logged(
        [
            "ssh",
            "-F",
            str(config),
            machine,
            f"sudo cat /var/tmp/cycloid-acceptance/{name}.log",
        ],
        run_dir / "raw" / f"{machine}-guest-{name}.log",
        env=env,
        check=False,
    )


def test(args: argparse.Namespace) -> int:
    matrix = load_matrix()
    archive = args.archive.resolve()
    if not archive.is_file():
        raise HarnessError(f"archive does not exist: {archive}")
    upgrade_archive = args.upgrade_archive.resolve() if args.upgrade_archive else None
    if upgrade_archive and not upgrade_archive.is_file():
        raise HarnessError(f"upgrade archive does not exist: {upgrade_archive}")
    run_id = args.run_id or time.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:8]
    valid_identifier(run_id, "run id")
    WORK_ROOT.mkdir(mode=0o700, parents=True, exist_ok=True)
    WORK_ROOT.chmod(0o700)
    run_dir = WORK_ROOT / run_id
    secure_dir(run_dir)
    machines = machine_names(args.os, matrix)
    candidate = run_dir / "ansible-cycloid-onprem.tar.gz"
    needs_candidate = args.source == "checkout" or (
        upgrade_archive is not None and args.upgrade_source == "checkout"
    )
    if needs_candidate:
        create_candidate_archive(candidate)
    config = {
        "schema": 1,
        "run_id": run_id,
        "provider": matrix["provider"],
        "machines": machines,
        "archive": str(archive),
        "archive_sha256": sha256(archive),
        "source": args.source,
        "candidate_archive": str(candidate) if args.source == "checkout" else None,
        "upgrade_archive": str(upgrade_archive) if upgrade_archive else None,
        "upgrade_archive_sha256": sha256(upgrade_archive) if upgrade_archive else None,
        "upgrade_source": args.upgrade_source if upgrade_archive else None,
        "upgrade_candidate_archive": (
            str(candidate)
            if upgrade_archive and args.upgrade_source == "checkout"
            else None
        ),
        "tolerate_initial_failure": bool(args.tolerate_initial_failure),
    }
    config_path = run_dir / "config.json"
    config_path.write_text(json.dumps(config, indent=2) + "\n")
    config_path.chmod(0o600)
    env = vagrant_env(config_path, run_dir)
    results: list[Result] = []

    for machine in machines:
        machine_ok = stage(
            results,
            machine,
            "install",
            lambda m=machine: run_logged(
                ["vagrant", "up", m, f"--provider={matrix['provider']}"],
                run_dir / "raw" / f"{m}-install.log",
                env=env,
            ),
        )
        ssh_path: Path | None = None
        ssh_ok = stage(
            results,
            machine,
            "ssh-config",
            lambda m=machine: ssh_config(m, run_dir, env),
        )
        if ssh_ok:
            ssh_path = run_dir / "ssh" / f"{machine}.config"
        if not machine_ok and ssh_path:
            collect_private_log(machine, ssh_path, "install", run_dir, env)
        machine_ok = machine_ok and ssh_ok
        # install+ssh must succeed for anything else to be attempted, even
        # with --tolerate-initial-failure (there is no guest to talk to).
        guest_reachable = machine_ok
        # continue_phase gates whether the *next* primary phase runs; with
        # --tolerate-initial-failure it stays true even after a phase fails,
        # so every primary phase still gets attempted and its own junit
        # testcase, but a failure never aborts the lane early.
        continue_phase = machine_ok

        def run_primary_phase(
            phase: str,
            action,
            log_name: str | None = None,
        ) -> bool:
            nonlocal continue_phase
            if not continue_phase:
                return False
            ok = stage(results, machine, phase, action)
            if not ok and ssh_path:
                collect_private_log(machine, ssh_path, log_name or phase, run_dir, env)
            if not ok and not args.tolerate_initial_failure:
                continue_phase = False
            return ok

        if guest_reachable and ssh_path:
            run_primary_phase(
                "verify-initial",
                lambda m=machine: run_logged(
                    remote(m, ssh_path, "verify.sh", "initial"),
                    run_dir / "raw" / f"{m}-verify-initial.log",
                    env=env,
                ),
            )
        if guest_reachable and not args.skip_rerun:
            rerun_ok = run_primary_phase(
                "rerun",
                lambda m=machine: run_logged(
                    remote(m, ssh_path, "rerun.sh"),
                    run_dir / "raw" / f"{m}-rerun.log",
                    env=env,
                ),
            )
            if rerun_ok or args.tolerate_initial_failure:
                run_primary_phase(
                    "verify-post-rerun",
                    lambda m=machine: run_logged(
                        remote(m, ssh_path, "verify.sh", "post-rerun"),
                        run_dir / "raw" / f"{m}-verify-post-rerun.log",
                        env=env,
                    ),
                )
        if guest_reachable:
            run_primary_phase(
                "reboot",
                lambda m=machine: run_logged(
                    ["vagrant", "reload", m],
                    run_dir / "raw" / f"{m}-reboot.log",
                    env=env,
                ),
            )
            run_primary_phase(
                "verify-post-reboot",
                lambda m=machine: run_logged(
                    remote(m, ssh_path, "verify.sh", "post-reboot"),
                    run_dir / "raw" / f"{m}-verify-post-reboot.log",
                    env=env,
                ),
            )

        # The upgrade lane only needs a reachable guest; --tolerate-initial-failure
        # lets it run even if earlier primary phases failed.
        if upgrade_archive and guest_reachable and ssh_path:
            upgrade_ok = stage(
                results,
                machine,
                "upload-upgrade-archive",
                lambda m=machine: run_logged(
                    [
                        "vagrant",
                        "upload",
                        str(upgrade_archive),
                        "/tmp/cycloid-onprem-upgrade.tar",
                        m,
                    ],
                    run_dir / "raw" / f"{m}-upload-upgrade-archive.log",
                    env=env,
                ),
            )
            if upgrade_ok and args.upgrade_source == "checkout":
                upgrade_ok = stage(
                    results,
                    machine,
                    "upload-upgrade-candidate",
                    lambda m=machine: run_logged(
                        [
                            "vagrant",
                            "upload",
                            str(candidate),
                            "/tmp/ansible-cycloid-onprem-upgrade.tar.gz",
                            m,
                        ],
                        run_dir / "raw" / f"{m}-upload-upgrade-candidate.log",
                        env=env,
                    ),
                )
            if upgrade_ok:
                upgrade_ok = stage(
                    results,
                    machine,
                    "upgrade-install",
                    lambda m=machine: run_logged(
                        remote(
                            m,
                            ssh_path,
                            "upgrade.sh",
                            f"{args.upgrade_source} {run_id}",
                        ),
                        run_dir / "raw" / f"{m}-upgrade-install.log",
                        env=env,
                    ),
                )
                if not upgrade_ok:
                    collect_private_log(
                        machine, ssh_path, "upgrade-install", run_dir, env
                    )
            if upgrade_ok:
                upgrade_ok = stage(
                    results,
                    machine,
                    "verify-post-upgrade",
                    lambda m=machine: run_logged(
                        remote(m, ssh_path, "verify.sh", "post-upgrade"),
                        run_dir / "raw" / f"{m}-verify-post-upgrade.log",
                        env=env,
                    ),
                )
                if not upgrade_ok:
                    collect_private_log(
                        machine, ssh_path, "verify-post-upgrade", run_dir, env
                    )
            if upgrade_ok:
                stage(
                    results,
                    machine,
                    "collect-post-upgrade",
                    lambda m=machine: collect_machine(
                        m, "post-upgrade", run_dir, env, ssh_path
                    ),
                )
            if upgrade_ok:
                upgrade_ok = stage(
                    results,
                    machine,
                    "reboot-2",
                    lambda m=machine: run_logged(
                        ["vagrant", "reload", m],
                        run_dir / "raw" / f"{m}-reboot-2.log",
                        env=env,
                    ),
                )
            if upgrade_ok:
                upgrade_ok = stage(
                    results,
                    machine,
                    "verify-post-upgrade-reboot",
                    lambda m=machine: run_logged(
                        remote(m, ssh_path, "verify.sh", "post-upgrade-reboot"),
                        run_dir / "raw" / f"{m}-verify-post-upgrade-reboot.log",
                        env=env,
                    ),
                )
                if not upgrade_ok:
                    collect_private_log(
                        machine, ssh_path, "verify-post-upgrade-reboot", run_dir, env
                    )
            machine_ok = machine_ok and upgrade_ok

        if ssh_path:
            stage(
                results,
                machine,
                "collect",
                lambda m=machine, phase="final" if continue_phase else "failure": (
                    collect_machine(m, phase, run_dir, env, ssh_path)
                ),
            )
        else:
            results.append(
                Result(machine, "collect", 0, "SSH configuration unavailable")
            )
        if not args.keep:
            stage(
                results,
                machine,
                "destroy",
                lambda m=machine: run_logged(
                    ["vagrant", "destroy", "-f", m],
                    run_dir / "raw" / f"{m}-destroy.log",
                    env=env,
                ),
            )

    write_junit(run_dir / "junit.xml", results)
    failures = [result for result in results if result.error]
    print(f"Run: {run_id}")
    print(f"Report: {run_dir / 'junit.xml'}")
    if failures:
        for failure in failures:
            print(
                f"FAIL {failure.machine}/{failure.phase}: {redact(failure.error).splitlines()[0]}",
                file=sys.stderr,
            )
        return 1
    print("All selected acceptance phases passed.")
    return 0


def load_run(run_id: str) -> tuple[Path, Path, dict[str, str], dict]:
    run_dir = (WORK_ROOT / run_id).resolve()
    if run_dir.parent != WORK_ROOT.resolve() or not run_dir.is_dir():
        raise HarnessError(f"unknown run: {run_id}")
    config_path = run_dir / "config.json"
    config = json.loads(config_path.read_text())
    return run_dir, config_path, vagrant_env(config_path, run_dir), config


def collect_command(args: argparse.Namespace) -> int:
    run_dir, _, env, config = load_run(args.run)
    for machine in config["machines"]:
        path = ssh_config(machine, run_dir, env)
        collect_machine(machine, args.phase, run_dir, env, path)
    print(run_dir / "artifacts")
    return 0


def destroy(args: argparse.Namespace) -> int:
    run_dir, _, env, config = load_run(args.run)
    for machine in config["machines"]:
        run_logged(
            ["vagrant", "destroy", "-f", machine],
            run_dir / "raw" / f"{machine}-destroy-manual.log",
            env=env,
        )
    return 0


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    check = commands.add_parser(
        "preflight", help="validate local Vagrant/libvirt prerequisites"
    )
    check.set_defaults(func=preflight)
    run = commands.add_parser("test", help="run the VM acceptance matrix")
    run.add_argument(
        "--archive",
        type=Path,
        required=True,
        help="generated cycloid-onprem.tar fixture",
    )
    run.add_argument(
        "--os",
        default="all",
        help="'all', a single matrix key, or a comma-separated list of matrix keys",
    )
    run.add_argument("--source", choices=["checkout", "archive"], default="checkout")
    run.add_argument("--run-id")
    run.add_argument("--keep", action="store_true", help="keep VMs after the run")
    run.add_argument(
        "--skip-rerun", action="store_true", help="skip the rerun/idempotence phase"
    )
    run.add_argument(
        "--upgrade-archive",
        type=Path,
        default=None,
        help="second cycloid-onprem.tar fixture to upgrade to after the primary lane",
    )
    run.add_argument(
        "--upgrade-source",
        choices=["archive", "checkout"],
        default="archive",
        help="overlay the current checkout onto the upgrade archive's role",
    )
    run.add_argument(
        "--tolerate-initial-failure",
        action="store_true",
        help=(
            "record verify-initial/rerun/verify-post-rerun/reboot/verify-post-reboot "
            "failures as junit failures without aborting the lane (the upgrade lane "
            "still runs if the guest is reachable)"
        ),
    )
    run.set_defaults(func=test)
    collect_parser = commands.add_parser(
        "collect", help="collect diagnostics from a retained run"
    )
    collect_parser.add_argument("--run", required=True)
    collect_parser.add_argument("--phase", default="manual")
    collect_parser.set_defaults(func=collect_command)
    destroy_parser = commands.add_parser(
        "destroy", help="destroy VMs belonging to one exact run"
    )
    destroy_parser.add_argument("--run", required=True)
    destroy_parser.set_defaults(func=destroy)
    return root


def main(argv: Sequence[str] | None = None) -> int:
    try:
        args = parser().parse_args(argv)
        return args.func(args)
    except (
        HarnessError,
        subprocess.CalledProcessError,
        OSError,
        json.JSONDecodeError,
    ) as exc:
        print(f"error: {redact(str(exc))}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
