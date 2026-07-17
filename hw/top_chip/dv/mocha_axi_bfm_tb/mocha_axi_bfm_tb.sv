// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Chip-level UVM testbench. The DUT is the full top_chip_system; the CVA6 core 
// is swapped for axi_driver_wrapper via a SystemVerilog config (mocha_cfg), 
// so the AXI UVM agent drives the interconnect exactly where the CPU would. 
module mocha_axi_bfm_tb;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import top_pkg::*;
  import axi_agent_pkg::*;

  // top level tests
  import axi_sram_test_pkg::*;

  wire clk;
  wire rst_n;
  clk_rst_if u_clk_rst (.clk(clk), .rst_n(rst_n));

  top_chip_system #(
    .SramInitFile(""),
    .RomInitFile ("")
  ) dut (
    .clk_i                    (clk   ),
    .rst_ni                   (rst_n ),
    .gpio_i                   ('0    ),
    .gpio_o                   (      ),
    .gpio_en_o                (      ),
    .uart_rx_i                ('1    ),
    .uart_tx_o                (      ),
    .i2c_scl_i                ('1    ),
    .i2c_scl_o                (      ),
    .i2c_scl_en_o             (      ),
    .i2c_sda_i                ('1    ),
    .i2c_sda_o                (      ),
    .i2c_sda_en_o             (      ),
    .axi_mailbox_req_i        ('0    ),
    .axi_mailbox_resp_o       (      ),
    .mailbox_ext_irq_o        (      ),
    .spi_device_sck_i         ('0    ),
    .spi_device_csb_i         ('1    ),
    .spi_device_sd_o          (      ),
    .spi_device_sd_en_o       (      ),
    .spi_device_sd_i          ('1    ),
    .spi_device_tpm_csb_i     ('0    ),
    .spi_host_sck_en_o        (      ),
    .spi_host_csb_o           (      ),
    .spi_host_csb_en_o        (      ),
    .spi_host_sd_o            (      ),
    .spi_host_sd_en_o         (      ),
    .spi_host_sd_i            ('0    ),
    .entropy_src_rng_enable_o (      ),
    .entropy_src_rng_valid_i  ('0    ),
    .entropy_src_rng_bits_i   ('0    ),
    .dram_req_o               (      ),
    .dram_resp_i              ('0    ),
    .rest_of_chip_req_o       (      ),
    .rest_of_chip_resp_i      ('0    ),
    .ethernet_irq_i           ('0    ),
    .dm_jtag_tck              ('0    ),
    .dm_jtag_tms              ('0    ),
    .dm_jtag_tdi              ('0    ),
    .dm_jtag_tdo              (      ),
    .dm_jtag_trst_n           ('0    )
  );

  initial begin
    foreach (dut.u_axi_sram.u_ram.mem[i])     dut.u_axi_sram.u_ram.mem[i]     = '0;
    foreach (dut.u_axi_sram.u_tag_ram.mem[i]) dut.u_axi_sram.u_tag_ram.mem[i] = '0;
  end

  // turn off some failing assertions (due to X on init)
  // once stubs are in place, remove these
  initial begin
    $assertoff(0, dut.u_rom_ctrl.KmacDataODataKnown_A);
    $assertoff(0, dut.u_kmac.u_msgfifo.u_msgfifo.DataKnown_A);
    $assertoff(0, dut.u_kmac.u_msgfifo.u_packer.ExcessiveDataStored_A);
  end

  // UVM entry point
  initial begin
    u_clk_rst.set_freq_mhz(100);
    u_clk_rst.set_active();
    uvm_config_db#(virtual clk_rst_if)::set(null, "*", "clk_rst_vif", u_clk_rst);
    run_test();
  end

endmodule
