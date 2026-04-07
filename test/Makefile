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
	@status=0; \
	vvp $< || status=$$?; \
	if [ $$status -eq 0 ]; then \
		printf '%s\n' \
			'<?xml version="1.0" encoding="UTF-8"?>' \
			'<testsuites>' \
			'  <testsuite name="iverilog" tests="1" failures="0" errors="0" skipped="0" time="0">' \
			'    <testcase classname="tb" name="tb_pass" time="0"/>' \
			'  </testsuite>' \
			'</testsuites>' > results.xml; \
	else \
		printf '%s\n' \
			'<?xml version="1.0" encoding="UTF-8"?>' \
			'<testsuites>' \
			'  <testsuite name="iverilog" tests="1" failures="1" errors="0" skipped="0" time="0">' \
			'    <testcase classname="tb" name="tb_fail" time="0">' \
			'      <failure message="vvp returned non-zero exit code">See job logs for details.</failure>' \
			'    </testcase>' \
			'  </testsuite>' \
			'</testsuites>' > results.xml; \
		exit $$status; \
	fi

clean:
	rm -rf $(SIM_BUILD) tb.vcd
