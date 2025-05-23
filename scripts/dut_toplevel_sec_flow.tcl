# -----------------------------------------------------------------------------
#
# Copyright 2024 Intel Corporation All Rights Reserved.
#
# The source code contained or described herein and all documents related
# to the source code ("Material") are owned by Intel Corporation or its
# suppliers or licensors. Title to the Material remains with Intel
# Corporation or its suppliers and licensors. The Material contains trade
# secrets and proprietary and confidential information of Intel or its
# suppliers and licensors. The Material is protected by worldwide copyright
# and trade secret laws and treaty provisions. No part of the Material may
# be used, copied, reproduced, modified, published, uploaded, posted,
# transmitted, distributed, or disclosed in any way without Intel's prior
# express written permission.
#
# No license under any patent, copyright, trade secret or other intellectual
# property right is granted to or conferred upon you by disclosure or
# delivery of the Materials, either expressly, by implication, inducement,
# estoppel or otherwise. Any license under such intellectual property rights
# must be express and approved by Intel in writing.
#
# -----------------------------------------------------------------------------

clear -all

# -----------------------------------------------------------------------------
# design analysis
# -----------------------------------------------------------------------------
analyze -clear
analyze -sv -f dut_toplevel_sec_flow_files.f

elaborate -top dut_toplevel__sec_wrapper \
  -create_related_covers {precondition witness} \
  -parameter DATA_WIDTH 8 \
  -parameter FIFO_HEIGHT 4
analyze -clear

# -----------------------------------------------------------------------------
# clock and reset definitions
# -----------------------------------------------------------------------------
clock clk
reset -expression !(nreset)

# -----------------------------------------------------------------------------
# run
# -----------------------------------------------------------------------------
prove -all -bg

# -----------------------------------------------------------------------------
# reports generating
# -----------------------------------------------------------------------------
report -force -summary -results -file dut_toplevel_sec_flow_summary.rpt
