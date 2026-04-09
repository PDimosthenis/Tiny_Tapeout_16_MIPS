TOPLEVEL_LANG ?= verilog
VERILOG_SOURCES ?= ../src/project.v
TOPLEVEL ?= tt_um_top_module_16_mips
MODULE ?= test

VENV_BIN := $(abspath ../.venv/bin)
VENV_PYTHON := $(VENV_BIN)/python
COCOTB_SITE := $(shell $(VENV_PYTHON) -c "import cocotb, os; print(os.path.dirname(cocotb.__file__))")
PYTHON_SITE_PACKAGES := $(shell $(VENV_PYTHON) -c "import site; print(':'.join(site.getsitepackages()))")
LIBPYTHON_LOC := /usr/lib/x86_64-linux-gnu/libpython3.12.so.1.0
COCOTB_LIBS := $(COCOTB_SITE)/libs

SIM_BUILD ?= sim_build
IVERILOG ?= /usr/bin/iverilog
VVP ?= /usr/bin/vvp
COCOTB_RESULTS_FILE ?= results.xml

export PATH := $(VENV_BIN):$(PATH)
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
