# Terraform makefile by Rinat Abdullin 2018-05-22
BOLD=$(shell tput bold)
ERROR=$(shell tput setaf 1)
RESET=$(shell tput sgr0)

VARS=".secret.aws.tfvars"
CURRENT_FOLDER=$(shell basename "$$(pwd)")
TESTER_ADDR=$(shell terraform output tester_address)
FDB_ADDR=$(shell terraform output fdb_address | sed 's/,$///')

help: ## Display help by printing target comments
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

set-env:
	@if [ ! -f "$(VARS)" ]; then \
		echo "$(BOLD)$(ERROR)Could not find variables file: $(VARS)$(RESET)"; \
		exit 1; \
	 fi

prep: set-env
	terraform init

plan: prep ## Show what terraform thinks it will do
	@terraform plan -var-file="$(VARS)" -lock=false -out my.plan

apply: plan ## Apply the changes
	@terraform apply "my.plan"

test: prep ## Run test from test.conf definition
	@scp -q test.conf ubuntu@$(TESTER_ADDR):/tmp # update test definition from local file
	@ssh ubuntu@$(TESTER_ADDR) sudo fdbserver -r test -f /tmp/test.conf

multitest: prep ## Run test from multiple processes
	@scp -q test.conf ubuntu@$(TESTER_ADDR):/tmp # update test definition from local file
	@ssh ubuntu@$(TESTER_ADDR) sudo fdbserver -r multitest -f /tmp/test.conf --num_testers 16 # todo variable core count

configure: prep ## apply fdb node configurations
	@export COUNTER=0
	@for addr in $(FDB_ADDR); do \
		echo Configuring $$addr; \
		((COUNTER++)); \
		scp -q conf/$$COUNTER.ini ubuntu@$$addr:/tmp/foundationdb.conf; \
		ssh ubuntu@$$addr 'bash -s' < configure.sh; \
	done

	@export COUNTER=0
	@for addr in $(FDB_ADDR); do \
		echo Starting $$addr; \
		((COUNTER++)); \
		ssh ubuntu@$$addr 'sudo service foundationdb start'; \
	done
	ssh ubuntu@$(TESTER_ADDR) 'fdbcli --exec "configure new memory single" --timeout 60' > /dev/null; \

clean: prep ## remove all data from db
	ssh ubuntu@$(TESTER_ADDR) 'fdbcli --exec "writemode on; clearrange \"\" \"0xff\"" --timeout 60'

destroy: prep ## Destroy current setup
	@terraform destroy -var-file="$(VARS)" -lock=false
