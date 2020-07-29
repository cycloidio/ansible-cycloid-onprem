import os
import functools
import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('cycloid_creds')

def print_host_on_fail(func):
    @functools.wraps(func)
    def wrapper(host):
        print("inventory_hostname: %s" % host.ansible.get_variables().get("inventory_hostname"))
        return func(host)
    return wrapper

@print_host_on_fail
def test_generated_approle_files(host):
    # Concourse
    assert host.file("/opt/cycloid/vault/approle-concourse-ro").contains('CONCOURSE_VAULT_AUTH_PARAM=role_id:...*,secret_id:...')
    # Cycloid
    assert host.file("/opt/cycloid/vault/approle-cycloid").contains('VAULT_ROLE_ID=...')
    assert host.file("/opt/cycloid/vault/approle-cycloid").contains('VAULT_SECRET_ID=...')

@print_host_on_fail
def test_listening_ports(host):
    for port in [8200]:
        assert host.socket("tcp://%s" % port).is_listening

@print_host_on_fail
def test_containers_running(host):
    for container in ['vault']:
        command = "docker ps --filter=status=running --filter=name=%s" \
            % container
        c = host.run(command)
        assert container in c.stdout
