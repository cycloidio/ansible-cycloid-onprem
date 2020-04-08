import os
import functools
import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('cycloid-core')

def print_host_on_fail(func):
    @functools.wraps(func)
    def wrapper(host):
        print("inventory_hostname: %s" % host.ansible.get_variables().get("inventory_hostname"))
        return func(host)
    return wrapper

@print_host_on_fail
def test_force_ssl(host):
    r = host.ansible("uri", "url=http://localhost/foo?bar=true follow_redirects=none status_code=301", check=False)
    assert r['location'] == "https://localhost/foo?bar=true"

@print_host_on_fail
def test_listening_ports(host):
    for port in [3001, 80, 443, 8888]:
        assert host.socket("tcp://%s" % port).is_listening

@print_host_on_fail
def test_containers_running(host):
    for container in ['cycloid-api', 'cycloid-frontend']:
        command = "docker ps --filter=status=running --filter=name=%s" \
            % container
        c = host.run(command)
        assert container in c.stdout
