PYTHON_VERSION ?= 3.10
PYTHON ?= python$(PYTHON_VERSION)
PIP ?= $(PYTHON) -m pip
PIPENV ?= $(PYTHON) -m pipenv
PIPENV_PYTHON = $(PIPENV) run python
PIPENV_PIP = $(PIPENV_PYTHON) -m pip
PWD = $(shell pwd)

PHONY: pipenv
pipenv:
	$(PIP) install pip --upgrade
	$(PIP) install pipenv==2022.10.4

.PHONY: setup
setup: pipenv
	$(PIPENV) install --verbose --python $(PYTHON_VERSION)
	$(PIPENV_PIP) install https://github.com/h2oai/wave/releases/download/nightly/h2o_wave-nightly-py3-none-manylinux1_x86_64.whl --force-reinstall

.PHONY: setup-dev
setup-dev: pipenv
	$(PIPENV) install --verbose --dev --python $(PYTHON_VERSION)
	$(PIPENV_PIP) install https://github.com/h2oai/wave/releases/download/nightly/h2o_wave-nightly-py3-none-manylinux1_x86_64.whl --force-reinstall

.PHONY: export-requirements
export-requirements: pipenv
	$(PIPENV) requirements > requirements.txt
	 echo "https://github.com/h2oai/wave/releases/download/nightly/h2o_wave-nightly-py3-none-manylinux1_x86_64.whl" >> requirements.txt

clean-env:
	$(PIPENV) --rm

clean-data:
	rm -rf data

clean-output:
	rm -rf output

reports:
	mkdir -p reports

.PHONY: style
style: reports pipenv
	@echo -n > reports/flake8_errors.log
	@echo -n > reports/mypy_errors.log
	@echo -n > reports/mypy.log
	@echo

	-$(PIPENV) run flake8 | tee -a reports/flake8_errors.log
	@if [ -s reports/flake8_errors.log ]; then exit 1; fi

	-$(PIPENV) run mypy . --check-untyped-defs | tee -a reports/mypy.log || echo "mypy failed" >> reports/mypy_errors.log
	@if [ -s reports/mypy_errors.log ]; then exit 1; fi

.PHONY: format
format: pipenv
	$(PIPENV) run isort .
	$(PIPENV) run black .

.PHONY: isort
isort: pipenv
	$(PIPENV) run isort .

.PHONY: black
black: pipenv
	$(PIPENV) run black .

.PHONY: test
test: reports
	export PYTHONPATH=$(PWD) && $(PIPENV) run pytest -v -s -x \
		--junitxml=./reports/junit.xml \
		tests/* | tee reports/pytest.log

.PHONY: wave
wave:
	H2O_WAVE_MAX_REQUEST_SIZE=25MB \
	H2O_WAVE_NO_LOG=True \
	H2O_WAVE_PRIVATE_DIR="/download/@$(PWD)/output/download" \
	$(PIPENV) run wave run app

.PHONY: wave-no-reload
wave-no-reload:
	H2O_WAVE_MAX_REQUEST_SIZE=25MB \
	H2O_WAVE_NO_LOG=True \
	H2O_WAVE_PRIVATE_DIR="/download/@$(PWD)/output/download" \
	$(PIPENV) run wave run --no-reload app

.PHONY: docker-build-nightly
docker-build-nightly:
	docker build -t gcr.io/vorvan/h2oai/h2o-llmstudio:nightly .

.PHONY: docker-run-nightly
docker-run-nightly:
ifeq (,$(wildcard ./data))
	mkdir data
endif
ifeq (,$(wildcard ./output))
	mkdir output
endif
	docker run \
		--runtime=nvidia \
		--shm-size=64g \
		--init \
		--rm \
		-u `id -u`:`id -g` \
		-p 10101:10101 \
		-v `pwd`/data:/workspace/data \
		-v `pwd`/output:/workspace/output \
		gcr.io/vorvan/h2oai/h2o-llmstudio:nightly

.PHONY: shell
shell:
	$(PIPENV) shell
