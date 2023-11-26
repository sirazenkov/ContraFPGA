#=============================================
#company: Tomsk State University
#developer: Simon Razenkov
#e-mail: sirazenkov@stud.tsu.ru
#description: Multiply-by-255 module testbench
#=============================================

import os
import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import Timer, FallingEdge

rtl_dir = os.path.abspath(os.path.join('..', 'rtl'))

@cocotb.test()
async def mult255_tb(dut):
    """Multiply-by-255 module testbench""" 

    cocotb.start_soon(Clock(dut.iclk, 10, units="ns").start())

    x = dut.x
    q = dut.q

    for i in range(256):
        x.value = i
        await FallingEdge(dut.iclk)
        assert int(q.value) == i*255, f"Multiplication by 255 failed on input {i}: output expected - {i*255}, calculated - {int(q.value)}!"

def test_mult255():
    sim = os.getenv("SIM", "icarus")

    verilog_sources = [os.path.join(rtl_dir, 'mult255.v')]
    runner = get_runner(sim)
    runner.build(
            verilog_sources=verilog_sources,
            hdl_toplevel="mult255",
            always=True,
    )

    runner.test(hdl_toplevel="mult255", test_module="test_mult255",)

if __name__ == "__main__":
    test_mult255()

