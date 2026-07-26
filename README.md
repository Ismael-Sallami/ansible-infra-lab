# ansible-infra-lab

![ansible](https://img.shields.io/badge/ansible-2.16-EE0000)
![docker](https://img.shields.io/badge/docker%20compose-v2-2496ED)
[![build](https://img.shields.io/github/actions/workflow/status/Ismael-Sallami/ansible-infra-lab/ci.yml?branch=main&logo=github&label=build)](https://github.com/Ismael-Sallami/ansible-infra-lab/actions/workflows/ci.yml)
![license](https://img.shields.io/badge/license-MIT-4c1)

Provisioning, monitoring and load testing for a small Rocky Linux lab: Ansible playbooks,
a Prometheus and Grafana stack, and a JMeter test plan.

## Context

Coursework for **ISE — Enterprise Systems Infrastructure**, year 3 of the double degree in
Computer Science and Business Administration, University of Granada (2024–2025). Solo work.

The lab was three VirtualBox machines on a host-only network: one control node and two
managed nodes, all Rocky Linux.

## The problem

Four assignments, each on top of the last:

1. **Accounts.** Provision an `admin` account with passwordless sudo and key-based SSH on
   every managed node, plus two ordinary users, starting from machines that only accept
   root over a password.
2. **Web servers.** Turn one node into an Apache server and the other into Nginx, from a
   single playbook, opening the right firewall port on each.
3. **Monitoring.** Scrape both nodes and an API with Prometheus and put the metrics on a
   Grafana dashboard.
4. **Load testing.** Write a JMeter plan against a REST API that authenticates with
   HTTP Basic and then a JWT, and measure it under concurrent users.

## The solution

**Bootstrapping a host you cannot log into yet.** The first playbook has a chicken-and-egg
problem: it must install SSH keys, but at the start the only way in is a root password.
`playbook.yml` handles it in three moves — open `PermitRootLogin yes`, do the provisioning,
then set `PermitRootLogin prohibit-password` and restart sshd through a handler. The machine
ends up more locked down than it started, and the playbook is still idempotent: run it twice
and the second run changes nothing.

**One playbook, two different web servers.** The obvious approach is two playbooks, or one
playbook full of `when: inventory_hostname == ...`. Neither scales. Instead the inventory
puts each host in a group named after the software it should run, and the playbook loads its
variables from the group name:

```yaml
vars_files:
  - "../vars/{{ group_names[0] }}.yml"
```

`vars/apache.yml` and `vars/nginx.yml` each declare `web_package`, `web_service` and
`web_port`. Adding a third web server means one more group and one more vars file — the
playbook does not change.

**The nodes were reused between assignments**, so a host could still be running the other
web server from a previous run. The playbook explicitly stops and disables the one it is not
supposed to run, with `ignore_errors: true` so it does not fail on a host where that package
was never installed. It is defensive, and it is what makes the playbook safe to rerun on a
dirty machine.

**Keys are generated, never stored.** `scripts/generate-keys.sh` creates the three lab
keypairs and `keys/` is in `.gitignore`. This is a deliberate correction: an earlier version
of this project had twelve private keys committed to a public repository.

## Layout

```
src/ansible/users/        part 1: accounts, sudo and SSH hardening
src/ansible/webservers/   part 2: Apache and Nginx from one playbook
src/monitoring/           part 3: Prometheus and Grafana on Docker Compose
src/load-testing/         part 4: JMeter plan, input data and a saved run
scripts/generate-keys.sh  creates the lab SSH keys
docs/report/              write-up for part 1 and a screenshot of the JMeter run
requirements.yml          Ansible collections the playbooks need
```

## Requirements

- **Ansible 2.16** — tested with `ansible-playbook` 2.16 (core), plus the `ansible.posix`
  collection for `authorized_key` and `firewalld`:

  ```bash
  ansible-galaxy collection install -r requirements.yml
  ```

- **Docker Compose v2** for the monitoring stack.
- **ansible-lint** and **shellcheck** for the checks.
- **JMeter 5.6** to open the test plan.
- Managed nodes: **Rocky Linux 9**, reachable over SSH.

## Build and run

There is nothing to compile. These are the checks CI runs:

```bash
make check            # everything below
make syntax           # parse both playbooks, touching no host
make lint             # ansible-lint
make compose          # validate the monitoring stack definition
make shell            # shellcheck the scripts
```

To use it against real machines:

```bash
make keys                                     # create keys/, then paste the .pub values
                                              # into src/ansible/users/group_vars/all.yml

cd src/ansible/users                          # part 1
ansible-playbook -i hosts.ini playbook.yml --ask-pass --ask-become-pass

cd ../webservers                              # part 2
ansible-playbook -i inventory/hosts.ini playbooks/configurar_web.yml

make monitoring-up                            # part 3: Grafana on :4000, Prometheus on :9090
make monitoring-down
```

Both inventories point at `192.168.56.103` and `.104`. Change them to your own hosts.

## Results

The monitoring stack scrapes three targets every five seconds: Prometheus itself, a
`node_exporter` on the Rocky node, and the API's `/metrics` endpoint.

The saved JMeter run is in `src/load-testing/results.jtl`. It is **not** a finished load
test — it is a debugging run captured while the plan was still being built:

| | |
| --- | --- |
| Samples | 26, over roughly one second |
| Successful | 10 of 26 (38 %) |
| Median / p95 | 5 ms / 66 ms |
| Failures | `Expediente Académico` returned 500 (×10), `Login Administrador` returned 401 (×3) |

Student login worked; the record lookup and the admin login did not. The final run was never
saved to the repository, so this is what there is. `docs/report/jmeter-load-test.png` shows
the plan running in the JMeter GUI.

## What I learned

- **Idempotence is a design constraint, not a feature you add later.** The first playbook I
  wrote worked once and broke on the second run. Getting it to converge on the same state
  every time is what forced the SSH open-then-close sequence to be explicit rather than
  something I did by hand.
- **Group names are data.** Selecting a vars file from `group_names[0]` removed every
  `when: inventory_hostname == ...` from the web playbook. That one line is the difference
  between a playbook that scales and one that grows a branch per host.
- **A load test that is not saved did not happen.** I tuned the JMeter plan until it worked
  and never re-exported the results, so the only run in the repository is a broken one. Ten
  seconds of `-l results.jtl` would have kept the evidence.
- **Committing keys is easy and undoing it is not.** Twelve private keys sat in a public
  repository for months. Removing them from the index was not enough — they had to be purged
  from the history, which rewrites every commit hash. Hence `generate-keys.sh`.

### Known limitations

- **`src/ansible/users/group_vars/all.yml` is reconstructed.** The delivered file was
  overwritten with unrelated study notes before the project was first committed, so the
  original values are gone. The current file is derived from how the playbook uses those
  variables, with placeholder keys. It parses and the playbook syntax-checks, but the values
  are not the ones that ran in the lab.
- **The API under load is not included.** It is a Node and MongoDB service supplied by the
  course, whose own README states its development is outside the scope of the subject. It is
  not mine to republish, and it ships with hardcoded credentials. The JMeter plan targets
  `localhost:3000`.
- **The plan's HTTP Basic credentials were parameterised.** As delivered, `ETSII_API.jmx`
  had the API's username and password written into the auth manager. They are now
  `${__P(api.user,)}` and `${__P(api.password,)}`, so you pass them in:

  ```bash
  jmeter -n -t src/load-testing/ETSII_API.jmx \
         -Japi.user=<user> -Japi.password=<password> \
         -l run.jtl
  ```

  This is the only change made to the delivered files apart from the reconstructed vars.
- **The assignment briefs are not included** either, for the same reason. "The problem"
  above describes what they asked for.
- **`src/ansible/webservers/inventory/hosts.ini` still points at `claves/id_rsa_admin`**, a
  path that no longer ships. Point it at your own key or drop the option and use `--ask-pass`.
- **The IPs are hardcoded** to the `192.168.56.0/24` host-only network of a VirtualBox lab
  that no longer exists.
- **Nothing here is tested against a live host in CI.** The workflow parses, lints and
  validates. Spinning up two Rocky VMs in Actions to prove the playbooks converge would be
  the real check, and it is not there.
- **Three `ansible-lint` rules are skipped**, listed with their reasons in
  [`.ansible-lint`](.ansible-lint). They are real defects, left in place because rewriting a
  delivered submission to please a linter would misrepresent it:
  - `ignore-errors` — the two tasks that stop the other web server use `ignore_errors: true`
    instead of a `failed_when` condition, so they would also swallow an unrelated failure.
  - `risky-file-permissions` — the two `copy` tasks that write `index.html` set no `mode`,
    so the file lands with whatever umask the remote happens to have.
  - `name[template]` — one task name puts `{{ web_service }}` in the middle instead of at
    the end, which makes the log line harder to group.

  Three more are skipped as purely cosmetic: `fqcn`, `yaml[truthy]` and `yaml[empty-lines]`.

## Author and licence

Ismael Sallami Moreno. Released under the MIT licence (see [`LICENSE`](LICENSE)).
