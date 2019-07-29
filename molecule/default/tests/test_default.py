import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('instance')



def test_generated_approle_files(host):
    # Concourse
    assert host.file("/opt/cycloid/concourse/approle-concourse-ro").contains('CONCOURSE_VAULT_AUTH_PARAM=role_id=...*,secret_id=...')
    # Cycloid
    assert host.file("/opt/cycloid/approle-cycloid").contains('VAULT_ROLE_ID=...')
    assert host.file("/opt/cycloid/approle-cycloid").contains('VAULT_SECRET_ID=...')

def test_services_running(host):
    docker = host.process.filter(user='root', comm='dockerd')

    assert len(docker) >= 1

def test_containers_running(host):
    for container in ['cycloid-db', 'cycloid-api', 'cycloid-frontend', 'vault', 'concourse-db', 'concourse-web', 'cycloid-smtp']:
        command = 'docker ps -f name="%s$" --format "{{.ID}},{{.Image}},{{.Names}},{{.Status}},{{.RunningFor}}"' % container
        #command = 'docker ps -f name="%s$" --format {%% raw %%}"{{.ID}},{{.Image}},{{.Names}},{{.Status}},{{.RunningFor}}"{%% endraw %%}' % container
        c = host.run(command)
        assert ",%s,Up " % container in c.stdout


def test_listening_ports(host):
    for port in [8080, 8888, 2222, 8200, 5432, 3306, 3001, 80, 443, 1025]:
        assert host.socket("tcp://%s" % port).is_listening

def test_force_ssl(host):

    r = host.ansible("uri", "url=http://localhost/foo?bar=true follow_redirects=none status_code=301", check=False)
    assert r['location'] == "https://localhost/foo?bar=true"

# Example of URI curl

# With curl
# def test_curl_homepage(host):
#     f = host.run("curl -s  localhost:9090/graph | grep '<title>Prometheus'")
#
#     assert f.rc == 0



#def test_prometheus_rules(host):
#    assert host.file("/opt/prometheus/prometheus-data/telegraf.rules").contains('- alert: MemoryUsage')


# With ansible
#def test_homepage(host):
#
#    r = host.ansible("uri", "url=http://localhost:9090/graph return_content=yes", check=False)
#
#    assert '<title>Prometheus' in r['content']

#def test_hosts_file(host):
#    f = host.file('/etc/hosts')
#
#    assert f.exists
#    assert f.user == 'root'
#    assert f.group == 'root'
