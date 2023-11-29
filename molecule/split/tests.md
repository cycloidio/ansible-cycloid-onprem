This directory use to contain a symlink for molecule to work
  tests -> ../default/tests

Starting from ansible version 8.3 / 2.15, when running ansible galaxy command produce this error

```
ansible-galaxy install -r requirements.yml --roles-path=roles --force -vvv

File "/usr/lib/python3.11/site-packages/ansible/galaxy/role.py", line 428, in install
TypeError: join() missing 1 required positional argument: 'a'
```

This error is linked to a ansible bug https://github.com/ansible/ansible/issues/81965

So we removed this symlink and potentially broke molecule test during the resolution of this ansible bug
