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
// DUT top-level - modified module
//-------------------------------------

module dut_toplevel__imp #(
  // configurable parameters:
  parameter DATA_WIDTH                      = 8,                               // number of bits in a data word
  parameter FIFO_HEIGHT                     = 4,                               // number of entries in the FIFO
  // local parameters used in port definitions:
  localparam ARB_MODES_NUM                  = 2,                               // number of supported arbitration modes
  localparam ARB_MODE_ID_WIDTH              = (ARB_MODES_NUM == 1) ? 1 : $clog2(ARB_MODES_NUM),        // width of an ID of an arbitration mode
  localparam IN_INTERFACES_NUM              = 3,                               // number of supported input interfaces
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
  output logic                              proc_ack,                          // processing acknowledgement
  // input interface 0:
  input logic                               in0_valid,                         // valid flag
  output logic                              in0_ready,                         // ready flag
  input logic              [DATA_WIDTH-1:0] in0_data,                          // data
  input logic                               in0_data_last,                     // indicator of last data in a frame
  // input interface 1:
  input logic                               in1_valid,                         // valid flag
  output logic                              in1_ready,                         // ready flag
  input logic              [DATA_WIDTH-1:0] in1_data,                          // data
  input logic                               in1_data_last,                     // indicator of last data in a frame
  // input interface 2:
  input logic                               in2_valid,                         // valid flag
  output logic                              in2_ready,                         // ready flag
  input logic              [DATA_WIDTH-1:0] in2_data,                          // data
  input logic                               in2_data_last,                     // indicator of last data in a frame
  // output interface:
  output logic                              out_valid,                         // valid flag
  input logic                               out_ready,                         // ready flag
  output logic             [DATA_WIDTH-1:0] out_data,                          // data
  output logic  [IN_INTERFACE_ID_WIDTH-1:0] out_data_source_id,                // source ID (indicator of an input interface from which the data is taken)
  output logic                              out_data_last                      // indicator of last data in a frame
);

  //===========================================================================
  // other local parameters
  //===========================================================================
  localparam FIFO_DEPTH                     = (FIFO_HEIGHT == 1) ? 1 : $clog2(FIFO_HEIGHT); // width of the FIFO address bus
  localparam FIFO_HEIGHT_MIN_1              = FIFO_HEIGHT-1;                  // number of entries in the FIFO, decreased by one

  //===========================================================================
  // internal signals
  //===========================================================================

  //---------------------------------------------------------------------------
  // overall control logic
  //---------------------------------------------------------------------------
  logic                                     proc_req_in_prev_cycle_nxt_c;      // next state of the proc_req_in_prev_cycle_r register
  logic                                     proc_req_in_prev_cycle_r;          // state of the processing request in a previous cycle - register
  //-----
  logic                                     first_cycle_of_proc_req_c;         // indicator of a first cycle of the processing request
  //-----
  logic                                     proc_req_params_en_c;              // enable flag for registers storing parameters of a processing request
  logic                                     in0_en_nxt_c;                      // next state of the in0_en_r register
  logic             [ARB_MODE_ID_WIDTH-1:0] in0_arb_mode_id_en_nxt_c;          // next state of the in0_arb_mode_id_en_r register
  logic                                     in1_en_nxt_c;                      // next state of the in1_en_r register
  logic             [ARB_MODE_ID_WIDTH-1:0] in1_arb_mode_id_en_nxt_c;          // next state of the in1_arb_mode_id_en_r register
  logic                                     in2_en_nxt_c;                      // next state of the in2_en_r register
  logic             [ARB_MODE_ID_WIDTH-1:0] in2_arb_mode_id_en_nxt_c;          // next state of the in2_arb_mode_id_en_r register
  logic                                     in0_en_r;                          // input interface 0 - enable flag - register
  logic             [ARB_MODE_ID_WIDTH-1:0] in0_arb_mode_id_en_r;              // input interface 0 - arbitration mode ID - register
  logic                                     in1_en_r;                          // input interface 1 - enable flag - register
  logic             [ARB_MODE_ID_WIDTH-1:0] in1_arb_mode_id_en_r;              // input interface 1 - arbitration mode ID - register
  logic                                     in2_en_r;                          // input interface 2 - enable flag - register
  logic             [ARB_MODE_ID_WIDTH-1:0] in2_arb_mode_id_en_r;              // input interface 2 - arbitration mode ID - register
  //-----
  logic                                     proc_ack_en_c;                     // enable flag for the proc_ack_r register
  logic                                     proc_ack_nxt_c;                    // next state of the proc_ack_r register
  logic                                     proc_ack_r;                        // processing acknowledgement - register

  //---------------------------------------------------------------------------
  // input interface 0 control logic
  //---------------------------------------------------------------------------
  logic                                     in0_ready_c;                       // ready flag of input interface 0
  logic                                     in0_transferring_c;                // flag indicating that data is being transferred through the input interface 0
  //-----
  logic                                     in0_valid_en_c;                    // enable flag for the in0_valid_r register
  logic                                     in0_valid_nxt_c;                   // next state of the in0_valid_r register
  logic                                     in0_valid_r;                       // indicator of valid data from input interface 0 in an internal register - register
  //-----
  logic                                     in0_data_en_c;                     // enable flag for registers storing internally registered data from input interface 0
  logic                    [DATA_WIDTH-1:0] in0_data_nxt_c;                    // next state of the in0_data_r register
  logic                                     in0_data_last_nxt_c;               // next state of the in0_data_last_r register
  logic                    [DATA_WIDTH-1:0] in0_data_r;                        // internally registered data from input interface 0 - register
  logic                                     in0_data_last_r;                   // internally registered indicator of last data in a frame from input interface 0

  //---------------------------------------------------------------------------
  // input interface 1 control logic
  //---------------------------------------------------------------------------
  logic                                     in1_ready_c;                       // ready flag of input interface 1
  logic                                     in1_transferring_c;                // flag indicating that data is being transferred through the input interface 1
  //-----
  logic                                     in1_valid_en_c;                    // enable flag for the in1_valid_r register
  logic                                     in1_valid_nxt_c;                   // next state of the in1_valid_r register
  logic                                     in1_valid_r;                       // indicator of valid data from input interface 1 in an internal register - register
  //-----
  logic                                     in1_data_en_c;                     // enable flag for registers storing internally registered data from input interface 1
  logic                    [DATA_WIDTH-1:0] in1_data_nxt_c;                    // next state of the in1_data_r register
  logic                                     in1_data_last_nxt_c;               // next state of the in1_data_last_r register
  logic                    [DATA_WIDTH-1:0] in1_data_r;                        // internally registered data from input interface 1 - register
  logic                                     in1_data_last_r;                   // internally registered indicator of last data in a frame from input interface 1

  //---------------------------------------------------------------------------
  // input interface 2 control logic
  //---------------------------------------------------------------------------
  logic                                     in2_ready_c;                       // ready flag of input interface 2
  logic                                     in2_transferring_c;                // flag indicating that data is being transferred through the input interface 2
  //-----
  logic                                     in2_valid_en_c;                    // enable flag for the in2_valid_r register
  logic                                     in2_valid_nxt_c;                   // next state of the in2_valid_r register
  logic                                     in2_valid_r;                       // indicator of valid data from input interface 2 in an internal register - register
  //-----
  logic                                     in2_data_en_c;                     // enable flag for registers storing internally registered data from input interface 2
  logic                    [DATA_WIDTH-1:0] in2_data_nxt_c;                    // next state of the in2_data_r register
  logic                                     in2_data_last_nxt_c;               // next state of the in2_data_last_r register
  logic                    [DATA_WIDTH-1:0] in2_data_r;                        // internally registered data from input interface 2 - register
  logic                                     in2_data_last_r;                   // internally registered indicator of last data in a frame from input interface 2

  //---------------------------------------------------------------------------
  // arbitration control logic
  //---------------------------------------------------------------------------
  logic                                     arb_in0_transferring_c;            // indicator of arbitrating of a transfer from the input interface 0
  logic                                     arb_in1_transferring_c;            // indicator of arbitrating of a transfer from the input interface 1
  logic                                     arb_in2_transferring_c;            // indicator of arbitrating of a transfer from the input interface 2
  //-----
  logic                                     arb_transferring_c;                // indicator of any data being transferred through the arbiter
  //-----
  logic                    [DATA_WIDTH-1:0] arb_data_c;                        // arbitrated data
  logic                                     arb_data_last_c;                   // indicator that arbitrated data is last data in a frame
  logic         [IN_INTERFACE_ID_WIDTH-1:0] arb_data_source_id_c;              // arbitrated source (input interface) ID
  //-----
  logic                                     arb_last_data_source_id_en_c;      // enable flag for arb_last_data_source_id_r register
  logic         [IN_INTERFACE_ID_WIDTH-1:0] arb_last_data_source_id_nxt_c;     // next state of the arb_last_data_source_id_r register
  logic         [IN_INTERFACE_ID_WIDTH-1:0] arb_last_data_source_id_r;         // lastly arbitrated source (input interface) ID - register

  //---------------------------------------------------------------------------
  // FIFO control logic
  //---------------------------------------------------------------------------
  logic                                     fifo_we_c;                         // FIFO write enable flag
  logic                                     fifo_re_c;                         // FIFO read enable flag
  //-----
  logic                                     fifo_wptr_en_c;                    // enable flag for the fifo_wptr_r register
  logic                [(FIFO_DEPTH+1)-1:0] fifo_wptr_nxt_c;                   // next state of the fifo_wptr_r register
  logic                [(FIFO_DEPTH+1)-1:0] fifo_wptr_r;                       // FIFO write pointer - register
  //-----
  logic                                     fifo_rptr_en_c;                    // enable flag for the fifo_rptr_r register
  logic                [(FIFO_DEPTH+1)-1:0] fifo_rptr_nxt_c;                   // next state of the fifo_rptr_r register
  logic                [(FIFO_DEPTH+1)-1:0] fifo_rptr_r;                       // FIFO read pointer - register
  //-----
  logic                [(FIFO_DEPTH+1)-1:0] fifo_level_c;                      // FIFO level - number of occupied entries in the FIFO
  logic                                     fifo_full_c;                       // FIFO fullness indicator
  logic                                     fifo_empty_c;                      // FIFO emptiness indicator
  //-----
  logic                   [FIFO_HEIGHT-1:0] fifo_data_en_c;                    // enable flags for FIFO data registers
  logic                    [DATA_WIDTH-1:0] fifo_data_nxt_c;                   // next states of the fifo_data_r registers
  logic                                     fifo_data_last_nxt_c;              // next states of the fifo_data_last_r registers
  logic         [IN_INTERFACE_ID_WIDTH-1:0] fifo_data_source_id_nxt_c;         // next states of the fifo_data_source_id_r registers
  logic                    [DATA_WIDTH-1:0] fifo_data_r           [FIFO_HEIGHT-1:0]; // FIFO - data - registers
  logic                                     fifo_data_last_r      [FIFO_HEIGHT-1:0]; // FIFO - indicators of last data - registers
  logic         [IN_INTERFACE_ID_WIDTH-1:0] fifo_data_source_id_r [FIFO_HEIGHT-1:0]; // FIFO - source (input interface) IDs - registers

  //---------------------------------------------------------------------------
  // output interface control logic
  //---------------------------------------------------------------------------
  logic                                     out_valid_c;                       // output valid flag
  logic                    [DATA_WIDTH-1:0] out_data_c;                        // output data
  logic                                     out_data_last_c;                   // indicator of last output data in a frame
  logic         [IN_INTERFACE_ID_WIDTH-1:0] out_data_source_id_c;              // source (input interface) IDs of output data
  //-----
  logic                                     out_last_data_sent_en_c;           // enable flag for the out_last_data_sent_r register
  logic                                     out_last_data_sent_nxt_c;          // next state of the out_last_data_sent_r register
  logic                                     out_last_data_sent_r;              // indicator that last output data has been sent out in a given frame - register

  //===========================================================================
  // overall control logic
  //===========================================================================

  //---------------------------------------------------------------------------
  // state of the processing request in a previous cycle - register
  //---------------------------------------------------------------------------
  // next state of the register:
  assign proc_req_in_prev_cycle_nxt_c = proc_req;
  // register:
  always_ff @(posedge clk or negedge nreset)
    begin
    if (!nreset)
      proc_req_in_prev_cycle_r <= 1'b0;
    else
      proc_req_in_prev_cycle_r <= proc_req_in_prev_cycle_nxt_c;
    end

  //---------------------------------------------------------------------------
  // indicator of a first cycle of the processing request
  //---------------------------------------------------------------------------
  assign first_cycle_of_proc_req_c = proc_req &&
                                     !proc_req_in_prev_cycle_r;

  //---------------------------------------------------------------------------
  // processing request parameters - registers
  //---------------------------------------------------------------------------
  // these parameters are registered here to avoid inout paths through this
  //   module
  //-----------------------------------
  // registers enable flag:
  assign proc_req_params_en_c     = first_cycle_of_proc_req_c;
  // next states of the registers:
  assign in0_en_nxt_c             = proc_req_in0_en;
  assign in0_arb_mode_id_en_nxt_c = proc_req_in0_arb_mode_id;
  assign in1_en_nxt_c             = proc_req_in1_en;
  assign in1_arb_mode_id_en_nxt_c = proc_req_in1_arb_mode_id;
  assign in2_en_nxt_c             = proc_req_in2_en;
  assign in2_arb_mode_id_en_nxt_c = proc_req_in2_arb_mode_id;
  // registers:
  always_ff @(posedge clk or negedge nreset)
    begin
    if (!nreset)
      begin
      in0_en_r             <= 1'b0;
      in0_arb_mode_id_en_r <= {ARB_MODE_ID_WIDTH{1'b0}};
      in1_en_r             <= 1'b0;
      in1_arb_mode_id_en_r <= {ARB_MODE_ID_WIDTH{1'b0}};
      in2_en_r             <= 1'b0;
      in2_arb_mode_id_en_r <= {ARB_MODE_ID_WIDTH{1'b0}};
      end
    else if (proc_req_params_en_c)
      begin
      in0_en_r             <= in0_en_nxt_c;
      in0_arb_mode_id_en_r <= in0_arb_mode_id_en_nxt_c;
      in1_en_r             <= in1_en_nxt_c;
      in1_arb_mode_id_en_r <= in1_arb_mode_id_en_nxt_c;
      in2_en_r             <= in2_en_nxt_c;
      in2_arb_mode_id_en_r <= in2_arb_mode_id_en_nxt_c;
      end
    end

  //---------------------------------------------------------------------------
  // processing acknowledgement - register
  //---------------------------------------------------------------------------
  // register enable flag:
  assign proc_ack_en_c  = proc_ack_r ||
                          (!first_cycle_of_proc_req_c &&
                           (out_last_data_sent_r ||
                            (!in0_en_r &&
                             !in1_en_r &&
                             !in2_en_r)));
  // next state of the register:
  assign proc_ack_nxt_c = proc_req;
  // register:
  always_ff @(posedge clk or negedge nreset)
    begin
    if (!nreset)
      proc_ack_r <= 1'b0;
    else if (proc_ack_en_c)
      proc_ack_r <= proc_ack_nxt_c;
    end

  //===========================================================================
  // input interface 0 control logic
  //===========================================================================

  //---------------------------------------------------------------------------
  // ready flag of input interface 0
  //---------------------------------------------------------------------------
  assign in0_ready_c = !first_cycle_of_proc_req_c &&
                       in0_en_r &&
                       !in0_data_last_r &&
                       (!in0_valid_r ||
                        arb_in0_transferring_c);

  //---------------------------------------------------------------------------
  // flag indicating that data is being transferred through the input
  //   interface 0
  //---------------------------------------------------------------------------
  assign in0_transferring_c = in0_ready_c &&
                              in0_valid;

  //---------------------------------------------------------------------------
  // indicator of valid data from input interface 0 in an internal register -
  //   register
  //---------------------------------------------------------------------------
  // register enable flag:
  assign in0_valid_en_c  = !in0_valid_r ||
                           arb_in0_transferring_c;
  // next state of the register:
  assign in0_valid_nxt_c = in0_transferring_c;
  // register:
  always_ff @(posedge clk or negedge nreset)
    begin
    if (!nreset)
      in0_valid_r <= 1'b0;
    else if (in0_valid_en_c)
      in0_valid_r <= in0_valid_nxt_c;
    end

  //---------------------------------------------------------------------------
  // internally registered data from input interface 0 - registers
  //---------------------------------------------------------------------------
  // this internally registered indicator of last data in a frame is kept high
  //   from the time of a last data transfer to the beginning of a next frame;
  //   that is why, it can be used to block next transfers (after last data)
  //-----------------------------------
  // registers enable flag:
  assign in0_data_en_c       = first_cycle_of_proc_req_c ||
                               in0_transferring_c;
  // next states of the registers:
  assign in0_data_nxt_c      = in0_data;
  assign in0_data_last_nxt_c = (first_cycle_of_proc_req_c) ? 1'b0 : in0_data_last;
  // registers:
  always_ff @(posedge clk or negedge nreset)
    begin
    if (!nreset)
      begin
      in0_data_r      <= {DATA_WIDTH{1'b0}};
      in0_data_last_r <= 1'b0;
      end
    else if (in0_data_en_c)
      begin
      in0_data_r      <= in0_data_nxt_c;
      in0_data_last_r <= in0_data_last_nxt_c;
      end
    end

  //===========================================================================
  // input interface 1 control logic
  //===========================================================================

  //---------------------------------------------------------------------------
  // ready flag of input interface 1
  //---------------------------------------------------------------------------
  assign in1_ready_c = !first_cycle_of_proc_req_c &&
                       in1_en_r &&
                       !in1_data_last_r &&
                       (!in1_valid_r ||
                        arb_in1_transferring_c);

  //---------------------------------------------------------------------------
  // flag indicating that data is being transferred through the input
  //   interface 1
  //---------------------------------------------------------------------------
  assign in1_transferring_c = in1_ready_c &&
                              in1_valid;

  //---------------------------------------------------------------------------
  // indicator of valid data from input interface 1 in an internal register -
  //   register
  //---------------------------------------------------------------------------
  // register enable flag:
  assign in1_valid_en_c  = !in1_valid_r ||
                           arb_in1_transferring_c;
  // next state of the register:
  assign in1_valid_nxt_c = in1_transferring_c;
  // register:
  always_ff @(posedge clk or negedge nreset)
    begin
    if (!nreset)
      in1_valid_r <= 1'b0;
    else if (in1_valid_en_c)
      in1_valid_r <= in1_valid_nxt_c;
    end

  //---------------------------------------------------------------------------
  // internally registered data from input interface 1 - registers
  //---------------------------------------------------------------------------
  // this internally registered indicator of last data in a frame is kept high
  //   from the time of a last data transfer to the beginning of a next frame;
  //   that is why, it can be used to block next transfers (after last data)
  //-----------------------------------
  // registers enable flag:
  assign in1_data_en_c       = first_cycle_of_proc_req_c ||
                               in1_transferring_c;
  // next states of the register:
  assign in1_data_nxt_c      = in1_data;
  assign in1_data_last_nxt_c = (first_cycle_of_proc_req_c) ? 1'b0 : in1_data_last;
  // registers:
  always_ff @(posedge clk or negedge nreset)
    begin
    if (!nreset)
      begin
      in1_data_r      <= {DATA_WIDTH{1'b0}};
      in1_data_last_r <= 1'b0;
      end
    else if (in1_data_en_c)
      begin
      in1_data_r      <= in1_data_nxt_c;
      in1_data_last_r <= in1_data_last_nxt_c;
      end
    end

  //===========================================================================
  // input interface 2 control logic
  //===========================================================================

  //---------------------------------------------------------------------------
  // ready flag of input interface 2
  //---------------------------------------------------------------------------
  assign in2_ready_c = !first_cycle_of_proc_req_c &&
                       in2_en_r &&
                       !in2_data_last_r &&
                       (!in2_valid_r ||
                        arb_in2_transferring_c);

  //---------------------------------------------------------------------------
  // flag indicating that data is being transferred through the input
  //   interface 0
  //---------------------------------------------------------------------------
  assign in2_transferring_c = in2_ready_c &&
                              in2_valid;

  //---------------------------------------------------------------------------
  // indicator of valid data from input interface 2 in an internal register -
  //   register
  //---------------------------------------------------------------------------
  // register enable flag:
  assign in2_valid_en_c  = !in2_valid_r ||
                           arb_in2_transferring_c;
  // next state of the register:
  assign in2_valid_nxt_c = in2_transferring_c;
  // register:
  always_ff @(posedge clk or negedge nreset)
    begin
    if (!nreset)
      in2_valid_r <= 1'b0;
    else if (in2_valid_en_c)
      in2_valid_r <= in2_valid_nxt_c;
    end

  //---------------------------------------------------------------------------
  // internally registered data from input interface 2 - registers
  //---------------------------------------------------------------------------
  // this internally registered indicator of last data in a frame is kept high
  //   from the time of a last data transfer to the beginning of a next frame;
  //   that is why, it can be used to block next transfers (after last data)
  //-----------------------------------
  // registers enable flag:
  assign in2_data_en_c       = first_cycle_of_proc_req_c ||
                               in2_transferring_c;
  // next states of the registers:
  assign in2_data_nxt_c      = in2_data;
  assign in2_data_last_nxt_c = (first_cycle_of_proc_req_c) ? 1'b0 : in2_data_last;
  // registers:
  always_ff @(posedge clk or negedge nreset)
    begin
    if (!nreset)
      begin
      in2_data_r      <= {DATA_WIDTH{1'b0}};
      in2_data_last_r <= 1'b0;
      end
    else if (in2_data_en_c)
      begin
      in2_data_r      <= in2_data_nxt_c;
      in2_data_last_r <= in2_data_last_nxt_c;
      end
    end

  //===========================================================================
  // arbitration control logic
  //===========================================================================

  //---------------------------------------------------------------------------
  // indicator of arbitrating of a transfer from the input interface 0
  //---------------------------------------------------------------------------
  assign arb_in0_transferring_c = (in0_arb_mode_id_en_r == 1'b0) &&
                                  !fifo_full_c &&
                                  in0_valid_r &&
                                  ((arb_last_data_source_id_r == 2'b10) ||
                                   ((arb_last_data_source_id_r == 2'b01) && !in2_valid_r) ||
                                   ((arb_last_data_source_id_r == 2'b00) && !in1_valid_r && !in2_valid_r));

  //---------------------------------------------------------------------------
  // indicator of arbitrating of a transfer from the input interface 1
  //---------------------------------------------------------------------------
  assign arb_in1_transferring_c = (in0_arb_mode_id_en_r == 1'b0) &&
                                  !fifo_full_c &&
                                  in1_valid_r &&
                                  ((arb_last_data_source_id_r == 2'b00) ||
                                   ((arb_last_data_source_id_r == 2'b10) && !in0_valid_r) ||
                                   ((arb_last_data_source_id_r == 2'b01) && !in2_valid_r && !in0_valid_r));

  //---------------------------------------------------------------------------
  // indicator of arbitrating of a transfer from the input interface 2
  //---------------------------------------------------------------------------
  assign arb_in2_transferring_c = !fifo_full_c &&
                                  in2_valid_r &&
                                  ((arb_last_data_source_id_r == 2'b01) ||
                                   ((arb_last_data_source_id_r == 2'b00) && !in1_valid_r) ||
                                   ((arb_last_data_source_id_r == 2'b10) && !in0_valid_r && !in1_valid_r));

  //---------------------------------------------------------------------------
  // indicator of any data being transferred through the arbiter
  //---------------------------------------------------------------------------
  assign arb_transferring_c = arb_in0_transferring_c ||
                              arb_in1_transferring_c ||
                              arb_in2_transferring_c;

  //---------------------------------------------------------------------------
  // arbitrated data
  //---------------------------------------------------------------------------
  assign arb_data_c = (arb_in0_transferring_c) ? in0_data_r :
                      (arb_in1_transferring_c) ? in1_data_r :
                                                 in2_data_r;

  //---------------------------------------------------------------------------
  // indicator that arbitrated data is last data in a frame
  //---------------------------------------------------------------------------
  assign arb_data_last_c = (!in0_en_r ||
                            (in0_data_last_r &&
                             (!in0_valid_r ||
                              arb_in0_transferring_c))) &&
                           (!in1_en_r ||
                            (in1_data_last_r &&
                             (!in1_valid_r ||
                              arb_in1_transferring_c))) &&
                           (!in2_en_r ||
                            (in2_data_last_r &&
                             (!in2_valid_r ||
                              arb_in2_transferring_c)));

  //---------------------------------------------------------------------------
  // arbitrated source (input interface) ID
  //---------------------------------------------------------------------------
  assign arb_data_source_id_c = (arb_in0_transferring_c) ? 2'b00 :
                                (arb_in1_transferring_c) ? 2'b01 :
                                                           2'b10;

  //---------------------------------------------------------------------------
  // lastly arbitrated source (input interface) ID - register
  //---------------------------------------------------------------------------
  // register enable flag:
  assign arb_last_data_source_id_en_c  = first_cycle_of_proc_req_c ||
                                         arb_transferring_c;
  // next state of the register:
  assign arb_last_data_source_id_nxt_c = (first_cycle_of_proc_req_c) ?
                                         // reset at the beginning of processing:
                                              2'b10 :
                                         // normal processing:
                                              arb_data_source_id_c;
  // register:
  always_ff @(posedge clk or negedge nreset)
    begin
    if (!nreset)
      arb_last_data_source_id_r <= {IN_INTERFACE_ID_WIDTH{1'b0}};
    else if (arb_last_data_source_id_en_c)
      arb_last_data_source_id_r <= arb_last_data_source_id_nxt_c;
    end

  //===========================================================================
  // FIFO control logic
  //===========================================================================

  //---------------------------------------------------------------------------
  // FIFO write enable
  //---------------------------------------------------------------------------
  assign fifo_we_c = arb_transferring_c;

  //---------------------------------------------------------------------------
  // FIFO read enable
  //---------------------------------------------------------------------------
  assign fifo_re_c = !fifo_empty_c &&
                     out_ready;

  //---------------------------------------------------------------------------
  // FIFO write pointer - register
  //---------------------------------------------------------------------------
  // register enable flag:
  assign fifo_wptr_en_c  = first_cycle_of_proc_req_c ||
                           fifo_we_c;
  // next state of the register:
  assign fifo_wptr_nxt_c = (first_cycle_of_proc_req_c) ?
                           // reset at the beginning of a frame:
                                 {(FIFO_DEPTH+1){1'b0}} :
                           (fifo_wptr_r[FIFO_DEPTH-1:0] == FIFO_HEIGHT_MIN_1[FIFO_DEPTH-1:0]) ?
                           // reset and MSB change after writing to a last address:
                                 {~fifo_wptr_r[FIFO_DEPTH],{FIFO_DEPTH{1'b0}}} :
                           // regular address incrementing:
                                 fifo_wptr_r + {{((FIFO_DEPTH+1)-1){1'b0}},1'b1};
  // register:
  always_ff @(posedge clk or negedge nreset)
    begin
    if (!nreset)
      fifo_wptr_r <= {(FIFO_DEPTH+1){1'b0}};
    else if (fifo_wptr_en_c)
      fifo_wptr_r <= fifo_wptr_nxt_c;
    end

  //---------------------------------------------------------------------------
  // FIFO read pointer - register
  //---------------------------------------------------------------------------
  // register enable flag:
  assign fifo_rptr_en_c  = first_cycle_of_proc_req_c ||
                           fifo_re_c;
  // next state of the register:
  assign fifo_rptr_nxt_c = (first_cycle_of_proc_req_c) ?
                           // reset at the beginning of a frame:
                                 {(FIFO_DEPTH+1){1'b0}} :
                           (fifo_rptr_r[FIFO_DEPTH-1:0] == FIFO_HEIGHT_MIN_1[FIFO_DEPTH-1:0]) ?
                           // reset and MSB change after reading from a last address:
                                 {~fifo_rptr_r[FIFO_DEPTH],{FIFO_DEPTH{1'b0}}} :
                           // regular address incrementing:
                                 fifo_rptr_r + {{((FIFO_DEPTH+1)-1){1'b0}},1'b1};
  // register:
  always_ff @(posedge clk or negedge nreset)
    begin
    if (!nreset)
      fifo_rptr_r <= {(FIFO_DEPTH+1){1'b0}};
    else if (fifo_rptr_en_c)
      fifo_rptr_r <= fifo_rptr_nxt_c;
    end

  //---------------------------------------------------------------------------
  // FIFO level - number of occupied entries in the FIFO
  //---------------------------------------------------------------------------
  always_comb
    begin
    fifo_level_c                 = {(FIFO_DEPTH+1){1'b0}};
    fifo_level_c[FIFO_DEPTH-1:0] = fifo_wptr_r[FIFO_DEPTH-1:0] - fifo_rptr_r[FIFO_DEPTH-1:0];
    fifo_level_c[FIFO_DEPTH]     = !(|fifo_level_c[FIFO_DEPTH-1:0]) &&
                                   (fifo_wptr_r[FIFO_DEPTH] ^ fifo_rptr_r[FIFO_DEPTH]);
    end

  //---------------------------------------------------------------------------
  // FIFO fullness indicator
  //---------------------------------------------------------------------------
  assign fifo_full_c = (fifo_level_c == FIFO_HEIGHT[(FIFO_DEPTH+1)-1:0]);

  //---------------------------------------------------------------------------
  // FIFO emptiness indicator
  //---------------------------------------------------------------------------
  assign fifo_empty_c = !(|fifo_level_c);

  //---------------------------------------------------------------------------
  // FIFO data - registers
  //---------------------------------------------------------------------------
  // registers enable flags:
  always_comb
    begin : fifo_data_en_c_proc
    integer entry_id_c;
    for (entry_id_c = 0; entry_id_c < FIFO_HEIGHT; entry_id_c = entry_id_c + 1)
      fifo_data_en_c[entry_id_c] = fifo_we_c &&
                                   (fifo_wptr_r[FIFO_DEPTH-1:0] == entry_id_c[FIFO_DEPTH-1:0]);
    end
  // next states of the registers:
  assign fifo_data_nxt_c           = arb_data_c;
  assign fifo_data_last_nxt_c      = arb_data_last_c;
  assign fifo_data_source_id_nxt_c = arb_data_source_id_c;
  // registers:
  always_ff @(posedge clk or negedge nreset)
    begin : fifo_data_r_proc
    integer entry_id_c;
    if (!nreset)
      for (entry_id_c = 0; entry_id_c < FIFO_HEIGHT; entry_id_c = entry_id_c + 1)
        begin
        fifo_data_r[entry_id_c]           <= {DATA_WIDTH{1'b0}};
        fifo_data_last_r[entry_id_c]      <= 1'b0;
        fifo_data_source_id_r[entry_id_c] <= {IN_INTERFACE_ID_WIDTH{1'b0}};
        end
    else
      for (entry_id_c = 0; entry_id_c < FIFO_HEIGHT; entry_id_c = entry_id_c + 1)
        if (fifo_data_en_c[entry_id_c])
          begin
          fifo_data_r[entry_id_c]           <= fifo_data_nxt_c;
          fifo_data_last_r[entry_id_c]      <= fifo_data_last_nxt_c;
          fifo_data_source_id_r[entry_id_c] <= fifo_data_source_id_nxt_c;
          end
    end

  //===========================================================================
  // output interface control logic
  //===========================================================================

  //---------------------------------------------------------------------------
  // output valid flag
  //---------------------------------------------------------------------------
  assign out_valid_c = !fifo_empty_c;

  //---------------------------------------------------------------------------
  // output data
  //---------------------------------------------------------------------------
  assign out_data_c = fifo_data_r[fifo_rptr_r[FIFO_DEPTH-1:0]];

  //---------------------------------------------------------------------------
  // source (input interface) IDs of output data
  //---------------------------------------------------------------------------
  assign out_data_source_id_c = fifo_data_source_id_r[fifo_rptr_r[FIFO_DEPTH-1:0]];

  //---------------------------------------------------------------------------
  // indicator of last output data in a frame
  //---------------------------------------------------------------------------
  assign out_data_last_c = fifo_data_last_r[fifo_rptr_r[FIFO_DEPTH-1:0]];

  //---------------------------------------------------------------------------
  // indicator that last output data has been sent out in a given frame -
  //   register
  //---------------------------------------------------------------------------
  // register enable flag:
  assign out_last_data_sent_en_c  = first_cycle_of_proc_req_c ||
                                    (out_valid_c &&
                                     out_ready &&
                                     out_data_last_c);
  // next state of the register:
  assign out_last_data_sent_nxt_c = !first_cycle_of_proc_req_c;
  // register:
  always_ff @(posedge clk or negedge nreset)
    begin
    if (!nreset)
      out_last_data_sent_r <= 1'b0;
    else if (out_last_data_sent_en_c)
      out_last_data_sent_r <= out_last_data_sent_nxt_c;
    end

  //===========================================================================
  // output assignments
  //===========================================================================

  //---------------------------------------------------------------------------
  // outputs of the processing control interface
  //---------------------------------------------------------------------------
  assign proc_ack           = proc_ack_r;

  //---------------------------------------------------------------------------
  // outputs of the input interface 0
  //---------------------------------------------------------------------------
  assign in0_ready          = in0_ready_c;

  //---------------------------------------------------------------------------
  // outputs of the input interface 1
  //---------------------------------------------------------------------------
  assign in1_ready          = in1_ready_c;

  //---------------------------------------------------------------------------
  // outputs of the input interface 2
  //---------------------------------------------------------------------------
  assign in2_ready          = in2_ready_c;

  //---------------------------------------------------------------------------
  // outputs of the output interface
  //---------------------------------------------------------------------------
  assign out_valid          = out_valid_c;
  assign out_data           = out_data_c;
  assign out_data_source_id = out_data_source_id_c;
  assign out_data_last      = out_data_last_c;

endmodule
