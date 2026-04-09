TOPLEVEL_LANG ?= verilog
VERILOG_SOURCES ?= ../src/project.v
TOPLEVEL ?= tt_um_top_module_16_mips
MODULE ?= test

# Prefer a local virtualenv when available, but work with system Python in CI.
VENV_BIN := $(abspath ../.venv/bin)
PYTHON ?= $(shell if [ -x "$(VENV_BIN)/python" ]; then echo "$(VENV_BIN)/python"; elif command -v python3 >/dev/null 2>&1; then command -v python3; else command -v python; fi)
COCOTB_SITE := $(shell $(PYTHON) -c "import cocotb, os; print(os.path.dirname(cocotb.__file__))")
PYTHON_SITE_PACKAGES := $(shell $(PYTHON) -c "import site; print(':'.join(site.getsitepackages()))")
LIBPYTHON_LOC := $(shell $(PYTHON) -c "import sysconfig, pathlib; print(pathlib.Path(sysconfig.get_config_var('LIBDIR'), sysconfig.get_config_var('LDLIBRARY')))" )
COCOTB_LIBS := $(COCOTB_SITE)/libs

SIM_BUILD ?= sim_build
IVERILOG ?= $(shell command -v iverilog)
VVP ?= $(shell command -v vvp)
COCOTB_RESULTS_FILE ?= results.xml

ifneq ($(wildcard $(VENV_BIN)),)
export PATH := $(VENV_BIN):$(PATH)
export VIRTUAL_ENV := $(abspath ../.venv)
endif
export PYTHONPATH := $(PYTHON_SITE_PACKAGES):$(PYTHONPATH)
export LIBPYTHON_LOC := $(LIBPYTHON_LOC)

.PHONY: all sim clean

all: sim

$(SIM_BUILD):
	mkdir -p $(SIM_BUILD)

$(SIM_BUILD)/cmds.f: | $(SIM_BUILD)
	@printf '%s\n' '+timescale+1ns/1ps' > $(SIM_BUILD)/cmds.f

$(SIM_BUILD)/sim.vvp: $(VERILOG_SOURCES) $(SIM_BUILD)/cmds.f
	$(IVERILOG) -o $(SIM_BUILD)/sim.vvp -D COCOTB_SIM=1 -s $(TOPLEVEL) -g2012 -f $(SIM_BUILD)/cmds.f $(VERILOG_SOURCES)

sim: $(SIM_BUILD)/sim.vvp
	MODULE=$(MODULE) TOPLEVEL=$(TOPLEVEL) TOPLEVEL_LANG=$(TOPLEVEL_LANG) COCOTB_RESULTS_FILE=$(COCOTB_RESULTS_FILE) \
	$(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_BUILD)/sim.vvp

clean:
	rm -rf $(SIM_BUILD) $(COCOTB_RESULTS_FILE) tb.vcd
