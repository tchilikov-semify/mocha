# axi_sram_tb.py
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_clock(dut):
    """Sanity check: drive clock and deassert reset."""

    # Start a 10ns clock (100 MHz) on clk_i
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())

    # Hold reset low for 5 cycles, then deassert
    dut.rst_ni.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk_i)

    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)

    cocotb.log.info("Clock is running, reset deasserted — DUT is alive.")