import os

import testinfra.utils.ansible_runner


testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ["MOLECULE_INVENTORY_FILE"]
).get_hosts("seaweedfs")


def test_seaweedfs_service(host):
    service = host.service("seaweedfs_container")

    assert service.is_enabled
    assert service.is_running
    assert host.socket("tcp://0.0.0.0:9000").is_listening


def test_seaweedfs_rejects_anonymous_requests(host):
    response = host.run(
        "curl -s -o /dev/null -w '%{http_code}' http://localhost:9000/"
    )

    assert response.rc == 0
    assert response.stdout == "403"


def test_seaweedfs_accepts_signed_object_operations(host):
    aws = (
        "AWS_ACCESS_KEY_ID=molecule-seaweedfs "
        "AWS_SECRET_ACCESS_KEY=molecule-seaweedfs-secret "
        "AWS_DEFAULT_REGION=us-east-1 "
        "aws --endpoint-url http://localhost:9000"
    )

    assert host.run(f"{aws} s3api create-bucket --bucket molecule-state-one").rc == 0
    assert host.run(f"{aws} s3api create-bucket --bucket molecule-state-two").rc == 0
    assert host.run(
        f"{aws} s3api put-object --bucket molecule-state-one "
        "--key terraform.tfstate --body /etc/hostname"
    ).rc == 0

    downloaded = host.run(
        f"{aws} s3api get-object --bucket molecule-state-one "
        "--key terraform.tfstate /tmp/terraform.tfstate"
    )
    assert downloaded.rc == 0
    assert host.run("cmp /etc/hostname /tmp/terraform.tfstate").rc == 0


def test_seaweedfs_config_is_private(host):
    config_dir = host.file("/opt/cycloid/seaweedfs")
    config = host.file("/opt/cycloid/seaweedfs/s3.json")

    assert config_dir.mode == 0o700
    assert config_dir.user == "root"
    assert config_dir.group == "root"
    assert config.exists
    assert config.mode == 0o600
    assert host.run("stat -c '%u:%g' /opt/cycloid/seaweedfs/s3.json").stdout == "1000:1000"
