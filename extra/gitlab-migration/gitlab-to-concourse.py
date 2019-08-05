#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import logging
import yaml
import copy


def load(file):
    return yaml.safe_load(file)

# Used to have a better human read format of the generated yaml
# From https://stackoverflow.com/questions/6432605/any-yaml-libraries-in-python-that-support-dumping-of-long-strings-as-block-liter
class literal_unicode(str): pass
class folded_unicode(str): pass
def folded_unicode_representer(dumper, data):
    return dumper.represent_scalar(u'tag:yaml.org,2002:str', data, style='>')
def literal_unicode_representer(dumper, data):
    return dumper.represent_scalar(u'tag:yaml.org,2002:str', data, style='|')
yaml.add_representer(folded_unicode, folded_unicode_representer)
yaml.add_representer(literal_unicode, literal_unicode_representer)

# Remove automatic YAML anchors generated
# From https://github.com/yaml/pyyaml/issues/103
class NoAliasDumper(yaml.Dumper):
    def ignore_aliases(self, data):
        return True

def show(datas):
    print(yaml.dump(datas, default_flow_style = False, explicit_start=True))


def color_show(datas):
    import random
    from pygments import highlight
    from pygments.style import Style
    from pygments.styles import get_style_by_name
    from pygments.token import Token
    from pygments.lexers import YamlLexer
    from pygments.formatters import Terminal256Formatter
    from pygments.styles import get_all_styles

    MyStyle = get_style_by_name('monokai')
    #MyStyle = get_style_by_name('paraiso-light')
    code = yaml.dump(datas, default_flow_style = False, explicit_start=True, Dumper=NoAliasDumper)
    result = highlight(code, YamlLexer(), Terminal256Formatter(style=MyStyle))
    print(result)


def init_logger():
    # Init logger
    log = logging.getLogger()
    log.setLevel(logging.INFO)

    # Stream handler
    hdl = logging.StreamHandler()
    hdl.setFormatter(logging.Formatter('%(asctime)s %(levelname)s -: %(message)s'))
    log.addHandler(hdl)
    return log


def init_argparse():
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--input",
                        required=True,
                        help="Input gitlab pipeline file",
                        type=argparse.FileType('r'))
    return parser.parse_args()


def get_jobs(pipeline):
    # script is the only required keyword that a job needs.
    jobs = {}
    for key, value in pipeline.items():
        if type(value) is type(dict()) and value.get('script', False):
            jobs[key] = value
    return jobs

def render_variables_sample(base_variables, variables):
    var_sample = copy.deepcopy(base_variables)
    var_sample.update({ k.lower(): v for k,v in variables.items()})
    return var_sample

def gen_params_from_variables(variables):
    return { k: '((%s))' % k.lower() for k in variables.keys()}


def write_yaml(path, datas):
    with open(path, 'w+') as f:
        f.write(yaml.dump(datas, default_flow_style=False))

def docker_image_repo(image):
    return image.split(':')[0]

def docker_image_tag(image):
    try:
        return image.split(':')[1]
    except:
        return 'latest'

def get_all_jobs_per_stages(jobs, stages):
    jobs_per_stages = { x: [] for x in stages}
    for job_name, job in jobs.items():
        if job.get('stage'):
            jobs_per_stages[job.get('stage')].append(job_name)
    return jobs_per_stages

def get_previous_stage_jobs(ordered_stages, current_stage, jobs_per_stages):
    try:
        stage_index = ordered_stages.index(current_stage)
    except ValueError:
        return []

    if stage_index > 0:
        return jobs_per_stages.get(ordered_stages[stage_index - 1], [])

    return []

def generate_dind_task_script(user_script, services, variables, docker_image):
    """The generated task will load and run docker images as services,
    then run the user script into another dedicated docker image
    """

    text_script = '\n'.join(user_script)

    load_all_svc_commands = ["# Load and run services"]
    for service in services:
        load_all_svc_commands.append("docker load -q -i %s/image.tar" % docker_image_repo(service))
        load_all_svc_commands.append("docker run --name %s -d %s" % ( docker_image_repo(service) ,service))

    # Start docker Dind
    dind_init_task = """# Docker Dind init
finish()
{
  pkill -TERM dockerd
  exit $rc
}
trap 'rc=$?; set +e; finish' EXIT
/usr/local/bin/dockerd-entrypoint.sh --log-level error 2> docker.log &
timeout -t 60 sh -c "until docker info >/dev/null 2>&1; do echo waiting for docker to come up...; sleep 1; done"
mount | grep "none on /tmp type tmpfs" && umount /tmp
"""

    # Generate a script from user commands
    dind_user_script_task = """# Write user script
cat <<EOF > script.sh
%s
EOF
""" % text_script

    # Load and start eventual others docker containers
    dind_run_svc_task = "%s\n" % '\n'.join(load_all_svc_commands)
    
    # Run user's script into docker
    dind_run_task = """# Run user script
docker run --name script -it %(vars)s %(links)s -v $PWD:$PWD --entrypoint=/bin/sh %(image)s -c "cd $PWD && ./script.sh"
""" % {'vars': ' '.join(['-e %s' % x for x in variables.keys()]),
       'image': docker_image,
       'links': ' '.join(['--link %s' % docker_image_repo(x) for x in services])
      }

    return literal_unicode('\n'.join([dind_init_task, dind_user_script_task, dind_run_svc_task, dind_run_task]))


# Define pipeline samples
base_variables = {
    'branch': 'master',
    'ssh_key': '((git_access.ssh_key))',
    'git_repo_uri': 'git@gitlab.com:gitlab_user/repository_name.git',
}

base_resource_git_branch = yaml.safe_load("""
  name: git_((branch)) # replace of branches
  type: git
  source:
    uri: ((git_repo_uri))
    branch: ((branch))
    private_key: ((ssh_key))
    paths:
     - "*"
""")

base_resource_s3 = yaml.safe_load("""
  name: artifact-name
  type: s3
  source:
    bucket: ((artifacts_bucket_name))
    regexp: job_name/artifact.tar.gz
    access_key_id: ((artifacts_bucket_access_key))
    secret_access_key: ((artifacts_bucket_secret_key))
""")

base_get_resource_git_branch = yaml.safe_load("""
  get: git_((branch))
  trigger: True
  passed: []
""")

base_get_resource_s3 = yaml.safe_load("""
  get: git_resource_name
  trigger: False
  passed: []
""")

base_put_resource_s3 = yaml.safe_load("""
  put: resource-name
  params:
    file: output_artifacts/artifacts.tar.gz
""")

base_get_resource_dind_branch = yaml.safe_load("""
  get: git_((branch))
  trigger: False
  params:
    format: oci
""")

base_job = yaml.safe_load("""
  name: default_name
  build_logs_to_retain: 3
  plan: []
""")

base_dind_task = yaml.safe_load("""
  task: default_name
  config:
    platform: linux
    image_resource:
      type: docker-image
      source:
        repository: docker
        tag: 17.12.0-dind
    run:
      path: /bin/sh
      args:
      - '-ec'
    inputs: []
    outputs: []
    caches: []
    params: []
""")

base_task = yaml.safe_load("""
  task: default_name
  config:
    platform: linux
    image_resource:
      type: docker-image
      source:
        repository: cycloidio/cycloid-toolkit
        tag: latest
    run:
      path: /bin/sh
      args:
      - '-ec'
    inputs: []
    caches: []
    outputs: []
    params: []
""")

base_pipeline = {
    'resources': [],
    'resource_types': [],
    'jobs': [],
}

# Because we run under CC 4.2.3, we want the latest version cause the one
# we have is too old
resource_type_registry_image = yaml.safe_load("""
  name: registry-image
  type: docker-image
  #type: registry-image
  privileged: true
  source:
    repository: concourse/registry-image-resource
    tag: latest
""")
base_pipeline['resource_types'].append(resource_type_registry_image)

def get_job_services(jobs):
    services = []
    for job_name, job in jobs.items():
        for service in job.get('services', []):
            if service not in services:
                services.append(service)
    return services
    

def main(gitlab_pipeline):
    # Gather gitlab datas
    default_before_script = gitlab_pipeline.get('before_script', [])
    default_after_script = gitlab_pipeline.get('after_script', [])
    default_services = gitlab_pipeline.get('services', [])
    default_image = gitlab_pipeline.get('image', 'cycloidio/cycloid-toolkit')
    services = gitlab_pipeline.get('services', [])
    default_variables = gitlab_pipeline.get('variables', {})
    stages = gitlab_pipeline.get('stages', [])
    jobs = get_jobs(pipeline=gitlab_pipeline)
    uniq_jobs_services = get_job_services(jobs)
    jobs_per_stages = get_all_jobs_per_stages(jobs=jobs, stages=stages)

    #
    # Generate pipeline template
    #

    ### Resources
    generated_pipeline = base_pipeline
    generated_pipeline['resources'].append(base_resource_git_branch)

    # s3 resource for each artefact
    for job_name, job in jobs.items():
        artifacts = job.get('artifacts', {})
        if artifacts.get('paths'):
            artifacts_name = 'artifact_%s' % artifacts.get('name', job_name)
            resource_s3 = copy.deepcopy(base_resource_s3)
            resource_s3['name'] = artifacts_name
            resource_s3['source']['regexp'] = "%s/artifact.tar.gz" % job_name
            generated_pipeline['resources'].append(resource_s3)
            # Configure only one bucket for resources
            if '' not in base_variables:
                base_variables.update({
                    'artifacts_bucket_name': 'my-artifact-bucket',
                    'artifacts_bucket_access_key': 'XXXXX',
                    'artifacts_bucket_secret_key': 'XXXXX',
                })
            print(base_variables)

    # Define docker image resource for each services
    for service in set(default_services + uniq_jobs_services):
        log.info("# Configure service : %s" % service)
        resource_registry_image = yaml.safe_load("""
          name: %(image)s
          type: registry-image
          source:
            repository: %(image)s
            tag: %(tag)s
        """ % { "image": docker_image_repo(service), "tag": docker_image_tag(service)})
        generated_pipeline['resources'].append(resource_registry_image)

    ### Jobs
    for job_name, job in jobs.items():
        log.info("# Generate job %s" % job_name)

        generated_job = copy.deepcopy(base_job)
        jobs_previous_stage = get_previous_stage_jobs(ordered_stages=stages,
                                                      current_stage=job.get('stage'),
                                                      jobs_per_stages=jobs_per_stages)

        generated_job['name'] = job_name

        services = default_services + job.get('services', [])

        # - get: git
        get_git = copy.deepcopy(base_get_resource_git_branch)
        if job.get('when') == 'manual':
            get_git['trigger'] = False
        get_git['passed'] = jobs_previous_stage
        generated_job['plan'].append(get_git)

        ## - task:
        if services:
            generated_task = copy.deepcopy(base_dind_task)
        else:
            generated_task = copy.deepcopy(base_task)

        # before_script
        before_script = job.get('before_script', default_before_script.copy())
        after_script = job.get('after_script', default_after_script.copy())
        script = job.get('script')
        docker_image = job.get('image', default_image)

        # Artifacts outputs
        artifacts = job.get('artifacts', {})
        artifacts_scripts = []
        if artifacts.get('paths'):
            artifacts_name = 'artifact_%s' % job_name
            generated_task['config']['outputs'].append({'name': artifacts_name, 'path': 'output_artifacts'})
            artifacts_scripts.append('\n# Creating artifacts')
            artifacts_scripts.append('tar -czvf output_artifacts/artifacts.tar.gz %s' % ' '.join(artifacts.get('paths')))

            put_s3 = copy.deepcopy(base_put_resource_s3)
            put_s3['put'] = artifacts_name

        # Dependencies inputs
        dependencies = job.get('dependencies', [])
        dependencies_script = []
        for dependencie in dependencies:
            dependencie_name = 'artifact_%s' % dependencie
            generated_task['config']['inputs'].append({'name': dependencie_name})

            dependencies_script.append('tar -xf %s/artifacts.tar.gz' % dependencie_name)

            get_s3 = copy.deepcopy(base_get_resource_s3)
            get_s3['get'] = dependencie_name
            get_s3['passed'] = [dependencie]
            generated_job['plan'].append(get_s3)
        # Adding some visual formatting
        if dependencies_script:
            dependencies_script.insert(0, '# Extract artifacts')
            dependencies_script.append('')

        # Cache
        cache = job.get('cache', {})
        if cache:
            generated_task['config']['caches'].append({'path': x for x in cache.get('paths', [])})

        # script
        # In case of gitlab services, switch to a Docker in Docker task.
        user_script = dependencies_script + before_script + script + after_script + artifacts_scripts
        if services:
            # services as inputs
            for service in services:
                get_docker_image = copy.deepcopy(base_get_resource_dind_branch)
                get_docker_image['get'] = docker_image_repo(service)
                generated_job['plan'].append(get_docker_image)
                generated_task['config']['inputs'].append({'name': docker_image_repo(service)})

            # script
            generated_task['config']['run']['args'].append(generate_dind_task_script(user_script=user_script,
                                                                                     variables=default_variables,
                                                                                     docker_image=docker_image,
                                                                                     services=services))

        # regular job WITHOUT DIND
        else:
            # image
            generated_task['config']['image_resource']['source']['repository'] = docker_image_repo(docker_image)
            generated_task['config']['image_resource']['source']['tag'] = docker_image_tag(docker_image)
            # script
            generated_task['config']['run']['args'].append(literal_unicode('\n'.join(user_script)))

        # Currently all tasks have git as input
        generated_task['config']['inputs'].append({'name': 'git_((branch))', 'path': 'code'})

        # Common task sections
        generated_task['name'] = job_name

        # variables
        generated_task['config']['params'] = gen_params_from_variables(default_variables)

        generated_job['plan'].append(generated_task)
        if artifacts.get('paths'):
            generated_job['plan'].append(put_s3)

        # Pipeline append
        generated_pipeline['jobs'].append(generated_job)
        write_yaml('pipeline.yml', generated_pipeline)



    # Write pipeline
    color_show(generated_pipeline)

    #
    # Generate variables sample
    #
    log.info("# Generate variables sample file")
    variables_sample = render_variables_sample(base_variables, default_variables)
    write_yaml('variables.sample.yml', variables_sample)

if __name__ == "__main__":

    log = init_logger()
    args = init_argparse()
    main(gitlab_pipeline=load(args.input))


# Construct stage based on job name with build:osx: and dependencies like https://docs.gitlab.com/ee/ci/yaml/README.html#artifacts

# Compatibility checklist :
# [X] script Shell script which is executed by Runner.
# [X] image Use docker images. Also available: image:name and image:entrypoint.
# [partial, only service for now] services Use docker services images. Also available: services:name, services:alias, services:entrypoint, and services:command.
# [X] before_script Override a set of commands that are executed before job.
# [X] after_script Override a set of commands that are executed after job.
# [X] stages Define stages in a pipeline.
# [X] stage Defines a job stage (default: test).
# [ ] only Limit when jobs are created. Also available: only:refs, only:kubernetes, only:variables, and only:changes.
# [ ] except Limit when jobs are not created. Also available: except:refs, except:kubernetes, except:variables, and except:changes.
# [ ] tags List of tags which are used to select Runner.
# [ ] allow_failure Allow job to fail. Failed job doesn’t contribute to commit status.
# [only manual implemented] when When to run job. Also available: when:manual and when:delayed.
# [ ] environment Name of an environment to which the job deploys. Also available: environment:name, environment:url, environment:on_stop, and environment:action.
# [partial only push just push policy] cache List of files that should be cached between subsequent runs. Also available: cache:paths, cache:key, cache:untracked, and cache:policy.
# [X] artifacts List of files and directories to attach to a job on success. Also available: artifacts:paths, artifacts:name, artifacts:untracked, artifacts:when, artifacts:expire_in, artifacts:reports, and artifacts:reports:junit.
# [ ] 
# [ ] In GitLab Enterprise Edition, these are available: artifacts:reports:codequality, artifacts:reports:sast, artifacts:reports:dependency_scanning, artifacts:reports:container_scanning, artifacts:reports:dast, artifacts:reports:license_management, artifacts:reports:performance and artifacts:reports:metrics.
# [X] dependencies Other jobs that a job depends on so that you can pass artifacts between them.
# [ ] coverage Code coverage settings for a given job.
# [ ] retry When and how many times a job can be auto-retried in case of a failure.
# [ ] parallel How many instances of a job should be run in parallel.
# [ ] trigger Defines a downstream pipeline trigger.
# [ ] include Allows this job to include external YAML files. Also available: include:local, include:file, include:template, and include:remote.
# [ ] extends Configuration entries that this job is going to inherit from.
# [ ] pages Upload the result of a job to use with GitLab Pages.
# [X] variables Define job variables on a job level.

