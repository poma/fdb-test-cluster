# Terraform makefile by Rinat Abdullin 2018-05-22
BOLD=$(shell tput bold)
ERROR=$(shell tput setaf 1)
RESET=$(shell tput sgr0)

VARS=".secret.aws.tfvars"
CURRENT_FOLDER=$(shell basename "$$(pwd)")
MASTER_ADDR=$(shell terraform output fdb_address | tr -d ',' | head -n 1)
TESTER_ADDR=$(shell terraform output tester_address | tr -d ',')
FDB_ADDR=$(shell terraform output fdb_address | tr -d ',')
FDB_CLUSTER=$(shell terraform output fdb_cluster)
FDB_INIT_STRING=$(shell terraform output fdb_init_string)

help: ## Display help by printing target comments
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

set-env:
	@if [ ! -f "$(VARS)" ]; then \
		echo "$(BOLD)$(ERROR)Could not find variables file: $(VARS)$(RESET)"; \
		exit 1; \
	fi

init: set-env
	terraform init

plan: init ## Show what terraform thinks it will do
	@terraform plan -var-file="$(VARS)" -lock=false -out my.plan

apply: plan ## Apply the terraform plan
	@terraform apply "my.plan"

reapply: init ## Recreate all fdb nodes
	@terraform taint random_string.cluster_description
	@terraform taint random_string.cluster_id
	@terraform show -no-color | grep "^aws_instance.fdb."    | sed 's/ (tainted)//' | sed 's/://' | xargs -I '{}' terraform taint {}
	@terraform show -no-color | grep "^aws_instance.tester." | sed 's/ (tainted)//' | sed 's/://' | xargs -I '{}' terraform taint {}
	@$(MAKE) apply

test: init ## Run the benchmark from test.conf definition on a single test node
	@scp -i ~/.ssh/terraform -q test.conf ubuntu@$(MASTER_ADDR):/tmp
	@ssh -i ~/.ssh/terraform ubuntu@$(MASTER_ADDR) sudo fdbserver -f /tmp/test.conf -r test

multitest: init ## Run the benchmark from test.conf definition on all test nodes
	@scp -i ~/.ssh/terraform -q test.conf ubuntu@$(MASTER_ADDR):/tmp
	@ssh -i ~/.ssh/terraform ubuntu@$(MASTER_ADDR) sudo fdbserver -f /tmp/test.conf -r multitest

reconfigure: init ## Copy node configurations to hosts (fdb should automatically detect and apply them)
	@echo "$(FDB_ADDR)"    | tr ' ' '\n' | awk '{print "-i ~/.ssh/terraform conf/" NR ".ini ubuntu@" $$1 ":/etc/foundationdb/foundationdb.conf"}' | xargs -L 1 -P 10 scp
	@echo "$(TESTER_ADDR)" | tr ' ' '\n' | awk '{print "-i ~/.ssh/terraform conf/tester.ini ubuntu@" $$1 ":/etc/foundationdb/foundationdb.conf"}' | xargs -L 1 -P 10 scp

add-keys: init ## Add ssh keys of all machines to known_hosts
	@for addr in $(FDB_ADDR);    do ssh-keyscan $$addr >> ~/.ssh/known_hosts; done
	@for addr in $(TESTER_ADDR); do ssh-keyscan $$addr >> ~/.ssh/known_hosts; done

clean: init ## Remove all data from db
	@ssh -i ~/.ssh/terraform ubuntu@$(MASTER_ADDR) 'fdbcli --exec "writemode on; clearrange \"\" \"xff\"" --timeout 60'

destroy: init ## Destroy current setup
	@terraform destroy -var-file="$(VARS)" -lock=false
