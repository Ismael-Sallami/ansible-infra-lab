# ansible-infra-lab — checks and local runs.
#
# The playbooks target virtual machines that no longer exist, so there is
# nothing to "build". What can be checked is that everything parses and that
# the Compose files are valid.
#
# @author Ismael Sallami Moreno

ANSIBLE_DIR = src/ansible
MONITOR_DIR = src/monitoring

.PHONY: all check syntax lint compose shell keys monitoring-up monitoring-down clean

all: check

# Everything CI runs.
check: syntax lint compose shell

# Parse both playbooks without touching any host.
syntax:
	cd $(ANSIBLE_DIR)/users && ansible-playbook --syntax-check -i hosts.ini playbook.yml
	cd $(ANSIBLE_DIR)/webservers && ansible-playbook --syntax-check -i inventory/hosts.ini playbooks/configurar_web.yml

# Style and correctness rules for the playbooks.
lint:
	ansible-lint $(ANSIBLE_DIR)

# Validate the monitoring stack definition.
compose:
	docker compose -f $(MONITOR_DIR)/docker-compose.yml config --quiet

# Check the shell scripts.
shell:
	shellcheck scripts/generate-keys.sh $(ANSIBLE_DIR)/webservers/*.sh

# Create the lab SSH keys. They are never committed.
keys:
	./scripts/generate-keys.sh

# Bring Prometheus and Grafana up locally. Grafana lands on port 4000.
monitoring-up:
	docker compose -f $(MONITOR_DIR)/docker-compose.yml up -d

monitoring-down:
	docker compose -f $(MONITOR_DIR)/docker-compose.yml down

clean:
	rm -rf keys $(MONITOR_DIR)/prometheus_data $(MONITOR_DIR)/grafana_data
