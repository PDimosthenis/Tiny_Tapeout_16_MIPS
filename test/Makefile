SIM_BUILD ?= sim_build
TOP ?= tb
SRC := tb.v ../src/project.v
SIM := $(SIM_BUILD)/sim.vvp

.PHONY: all run clean

all: run

$(SIM_BUILD):
	mkdir -p $(SIM_BUILD)

$(SIM): $(SRC) | $(SIM_BUILD)
	iverilog -g2012 -s $(TOP) -o $@ $(SRC)

run: $(SIM)
	vvp $<

clean:
	rm -rf $(SIM_BUILD) tb.vcd
