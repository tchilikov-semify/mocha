// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Enumerations for the passive AXI transaction monitor (axi_monitor / axi_mon_item).

// Direction of a monitored transaction.
typedef enum {
  AXI_READ,
  AXI_WRITE
} axi_dir_e;

// What an axi_mon_item represents: a single channel observation, or a fully
// merged (request + data + response) transaction.
typedef enum {
  AXI_AW_CH,
  AXI_W_CH,
  AXI_FULL_WRITE_TR,
  AXI_AR_CH,
  AXI_R_CH,
  AXI_FULL_READ_TR
} axi_obs_e;
