#================================================
#company: Tomsk State University
#developer: Simon Razenkov
#e-mail: sirazenkov@stud.tsu.ru
#description: Divider (16/8 bit) module testbench
#================================================

import os
import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import Timer, ClockCycles

rtl_dir = os.path.abspath(os.path.join('..', 'rtl'))

@cocotb.test()
async def divider_tb(dut):
    """Divider (16/8 bit) module testbench""" 

    cocotb.start_soon(Clock(dut.iclk, 10, units="ns").start())

    dividend = dut.idividend
    divisor  = dut.idivisor
    quotient = dut.oquotient

    for i in range(1, 256):
        for j in range(i):
            dividend.value = j*255
            divisor.value  = i
            await ClockCycles(dut.iclk, 8, rising=False)
            assert int(quotient.value) == j*255//i, \
            f"Division failed on inputs {j*255}/{i}: output expected - {j*255//i}, calculated - {int(quotient.value)}!"

def test_divider():
    sim = os.getenv("SIM", "icarus")

    verilog_sources = [os.path.join(rtl_dir, 'divider.v')]
    runner = get_runner(sim)
    runner.build(
            verilog_sources=verilog_sources,
            hdl_toplevel="divider",
            always=True,
    )

    runner.test(hdl_toplevel="divider", test_module="test_divider",)

if __name__ == "__main__":
    test_divider()

