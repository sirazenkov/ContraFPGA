all:
	gw_sh build.tcl

program:
	programmer_cli --device GW1NSR-4C \
	               --run 2 \
		       --fsFile "$(shell pwd)/impl/pnr/stretch.fs"

clean:
	rm -rf impl stretch.gprj.user
