//-----------------------------------------------------------------------------
//
// Copyright 2024 Intel Corporation All Rights Reserved.
//
// The source code contained or described herein and all documents related
// to the source code ("Material") are owned by Intel Corporation or its
// suppliers or licensors. Title to the Material remains with Intel
// Corporation or its suppliers and licensors. The Material contains trade
// secrets and proprietary and confidential information of Intel or its
// suppliers and licensors. The Material is protected by worldwide copyright
// and trade secret laws and treaty provisions. No part of the Material may
// be used, copied, reproduced, modified, published, uploaded, posted,
// transmitted, distributed, or disclosed in any way without Intel's prior
// express written permission.
//
// No license under any patent, copyright, trade secret or other intellectual
// property right is granted to or conferred upon you by disclosure or
// delivery of the Materials, either expressly, by implication, inducement,
// estoppel or otherwise. Any license under such intellectual property rights
// must be express and approved by Intel in writing.
//
//-----------------------------------------------------------------------------
// Sequence equivalence check wrapper for the DUT top-level
//-------------------------------------

module dut_toplevel__sec_wrapper #(
  // configurable parameters:
  parameter DATA_WIDTH                      = 8,                               // number of bits in a data word
  parameter FIFO_HEIGHT                     = 4,                               // number of entries in the FIFO
  // local parameters used in port definitions:
  localparam ARB_MODES_NUM                  = 2,                               // number of supported arbitration modes
  localparam ARB_MODE_ID_WIDTH              = (ARB_MODES_NUM == 1) ? 1 : $clog2(ARB_MODES_NUM),        // width of an ID of an arbitration mode
  localparam IN_INTERFACES_NUM              = 4,                               // number of supported input interfaces
  localparam IN_INTERFACE_ID_WIDTH          = (IN_INTERFACES_NUM == 1) ? 1 : $clog2(IN_INTERFACES_NUM) // width of an ID of an input interface
)(
  // clocks and resets:
  input logic                               clk,                               // clock
  input logic                               nreset,                            // asynchronous reset (active low)
  // processing control interface:
  input logic                               proc_req,                          // processing request
  input logic                               proc_req_in0_en,                   // input interface 0 - enable flag
  input logic       [ARB_MODE_ID_WIDTH-1:0] proc_req_in0_arb_mode_id,          // input interface 0 - arbitration mode ID
  input logic                               proc_req_in1_en,                   // input interface 1 - enable flag
  input logic       [ARB_MODE_ID_WIDTH-1:0] proc_req_in1_arb_mode_id,          // input interface 1 - arbitration mode ID
  input logic                               proc_req_in2_en,                   // input interface 2 - enable flag
  input logic       [ARB_MODE_ID_WIDTH-1:0] proc_req_in2_arb_mode_id,          // input interface 2 - arbitration mode ID
  output logic                              proc_ack__spec,                    // processing acknowledgement of the reference block
  output logic                              proc_ack__imp,                     // processing acknowledgement of the modified block
  // input interface 0:
  input logic                               in0_valid,                         // valid flag
  output logic                              in0_ready__spec,                   // ready flag of the reference block
  output logic                              in0_ready__imp,                    // ready flag of the modified block
  input logic              [DATA_WIDTH-1:0] in0_data,                          // data
  input logic                               in0_data_last,                     // indicator of last data in a frame
  // input interface 1:
  input logic                               in1_valid,                         // valid flag
  output logic                              in1_ready__spec,                   // ready flag of the reference block
  output logic                              in1_ready__imp,                    // ready flag of the modified block
  input logic              [DATA_WIDTH-1:0] in1_data,                          // data
  input logic                               in1_data_last,                     // indicator of last data in a frame
  // input interface 2:
  input logic                               in2_valid,                         // valid flag
  output logic                              in2_ready__spec,                   // ready flag of the reference block
  output logic                              in2_ready__imp,                    // ready flag of the modified block
  input logic              [DATA_WIDTH-1:0] in2_data,                          // data
  input logic                               in2_data_last,                     // indicator of last data in a frame
  // output interface:
  output logic                              out_valid__spec,                   // valid flag of the reference block
  output logic                              out_valid__imp,                    // valid flag of the modified block
  input logic                               out_ready,                         // ready flag
  output logic             [DATA_WIDTH-1:0] out_data__spec,                    // data
  output logic             [DATA_WIDTH-1:0] out_data__imp,                     // data
  output logic  [IN_INTERFACE_ID_WIDTH-1:0] out_data_source_id__spec,          // source ID of the reference block (indicator of an input interface from which the data is taken)
  output logic  [IN_INTERFACE_ID_WIDTH-1:0] out_data_source_id__imp,           // source ID (indicator of an input interface from which the data is taken)
  output logic                              out_data_last__spec,               // indicator of last data in a frame (of the reference block)
  output logic                              out_data_last__imp                 // indicator of last data in a frame (of the modified block)
);

  //===========================================================================
  // instance of the reference block
  //===========================================================================
  dut_toplevel__spec
    #(
      // configurable parameters:
      .DATA_WIDTH                           (DATA_WIDTH),
      .FIFO_HEIGHT                          (FIFO_HEIGHT)
    )
    u_dut_toplevel__spec
      (
        // clocks and resets:
        .clk                                (clk),
        .nreset                             (nreset),
        // processing control interface:
        .proc_req                           (proc_req),
        .proc_req_in0_en                    (proc_req_in0_en),
        .proc_req_in0_arb_mode_id           (proc_req_in0_arb_mode_id),
        .proc_req_in1_en                    (proc_req_in1_en),
        .proc_req_in1_arb_mode_id           (proc_req_in1_arb_mode_id),
        .proc_req_in2_en                    (proc_req_in2_en),
        .proc_req_in2_arb_mode_id           (proc_req_in2_arb_mode_id),
        .proc_ack                           (proc_ack__spec),
        // input interface 0:
        .in0_valid                          (in0_valid),
        .in0_ready                          (in0_ready__spec),
        .in0_data                           (in0_data),
        .in0_data_last                      (in0_data_last),
        // input interface 1:
        .in1_valid                          (in1_valid),
        .in1_ready                          (in1_ready__spec),
        .in1_data                           (in1_data),
        .in1_data_last                      (in1_data_last),
        // input interface 2:
        .in2_valid                          (in2_valid),
        .in2_ready                          (in2_ready__spec),
        .in2_data                           (in2_data),
        .in2_data_last                      (in2_data_last),
        // output interface:
        .out_valid                          (out_valid__spec),
        .out_ready                          (out_ready),
        .out_data                           (out_data__spec),
        .out_data_source_id                 (out_data_source_id__spec),
        .out_data_last                      (out_data_last__spec)
      );

  //===========================================================================
  // instance of the modified block
  //===========================================================================
  dut_toplevel__imp
    #(
      // configurable parameters:
      .DATA_WIDTH                           (DATA_WIDTH),
      .FIFO_HEIGHT                          (FIFO_HEIGHT)
    )
    u_dut_toplevel__imp
      (
        // clocks and resets:
        .clk                                (clk),
        .nreset                             (nreset),
        // processing control interface:
        .proc_req                           (proc_req),
        .proc_req_in0_en                    (proc_req_in0_en),
        .proc_req_in0_arb_mode_id           (proc_req_in0_arb_mode_id),
        .proc_req_in1_en                    (proc_req_in1_en),
        .proc_req_in1_arb_mode_id           (proc_req_in1_arb_mode_id),
        .proc_req_in2_en                    (proc_req_in2_en),
        .proc_req_in2_arb_mode_id           (proc_req_in2_arb_mode_id),
        .proc_ack                           (proc_ack__imp),
        // input interface 0:
        .in0_valid                          (in0_valid),
        .in0_ready                          (in0_ready__imp),
        .in0_data                           (in0_data),
        .in0_data_last                      (in0_data_last),
        // input interface 1:
        .in1_valid                          (in1_valid),
        .in1_ready                          (in1_ready__imp),
        .in1_data                           (in1_data),
        .in1_data_last                      (in1_data_last),
        // input interface 2:
        .in2_valid                          (in2_valid),
        .in2_ready                          (in2_ready__imp),
        .in2_data                           (in2_data),
        .in2_data_last                      (in2_data_last),
        // output interface:
        .out_valid                          (out_valid__imp),
        .out_ready                          (out_ready),
        .out_data                           (out_data__imp),
        .out_data_source_id                 (out_data_source_id__imp),
        .out_data_last                      (out_data_last__imp)
      );

  //===========================================================================
  // properties
  //===========================================================================

  //---------------------------------------------------------------------------
  // checking of outputs equivalence
  //---------------------------------------------------------------------------
  property pr__output_the_same_in_both_instances(output_ref,output_mod);
    @(posedge clk) disable iff (!nreset)
      (output_ref == output_mod);
  endproperty
  as__proc_ack_the_same_in_both_instances           : assert property(pr__output_the_same_in_both_instances(proc_ack__spec,proc_ack__imp)) else $error("%t: ERROR - ASSERTION: %m", $time);
  as__in0_ready_the_same_in_both_instances          : assert property(pr__output_the_same_in_both_instances(in0_ready__spec,in0_ready__imp)) else $error("%t: ERROR - ASSERTION: %m", $time);
  as__in1_ready_the_same_in_both_instances          : assert property(pr__output_the_same_in_both_instances(in1_ready__spec,in1_ready__imp)) else $error("%t: ERROR - ASSERTION: %m", $time);
  as__in2_ready_the_same_in_both_instances          : assert property(pr__output_the_same_in_both_instances(in2_ready__spec,in2_ready__imp)) else $error("%t: ERROR - ASSERTION: %m", $time);
  as__out_valid_the_same_in_both_instances          : assert property(pr__output_the_same_in_both_instances(out_valid__spec,out_valid__imp)) else $error("%t: ERROR - ASSERTION: %m", $time);
  as__out_data_the_same_in_both_instances           : assert property(pr__output_the_same_in_both_instances(out_data__spec,out_data__imp)) else $error("%t: ERROR - ASSERTION: %m", $time);
  as__out_data_source_id_the_same_in_both_instances : assert property(pr__output_the_same_in_both_instances(out_data_source_id__spec,out_data_source_id__imp)) else $error("%t: ERROR - ASSERTION: %m", $time);
  as__out_data_last_the_same_in_both_instances      : assert property(pr__output_the_same_in_both_instances(out_data_last__spec,out_data_last__imp)) else $error("%t: ERROR - ASSERTION: %m", $time);

endmodule
