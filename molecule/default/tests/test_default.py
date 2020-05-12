import os
import testinfra.utils.ansible_runner
import functools

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')
# Filter out concourse worker
testinfra_hosts.remove("concourse_worker")

def print_host_on_fail(func):
    @functools.wraps(func)
    def wrapper(host):
        print("inventory_hostname: %s" % host.ansible.get_variables().get("inventory_hostname"))
        return func(host)
    return wrapper

@print_host_on_fail
def test_services_running(host):
    docker = host.process.filter(user='root', comm='dockerd')
    assert len(docker) >= 1
