`timescale 1ns/1ps

module tb_bus_slave();

parameter SCL_HALF = 5000;
parameter CLK_PER  = 10;

reg clk, rst;
reg sda, scl;
wire data_out, ack, error;

bus_slave DUT(
  .clk      (clk),
  .rst      (rst),
  .sdl      (sda),
  .scl      (scl),
  .data_out (data_out),
  .ack      (ack),
  .error    (error)
);

always #CLK_PER clk = ~clk;

initial begin

  // ==============================
  // INITIALIZATION
  // ==============================
  clk = 0;
  rst = 0;
  sda = 1;
  scl = 1;

  #20;
  rst = 1;
  #40;
  rst = 0;
  #40;
  rst = 1;
  #100;

  // ==============================
  // BUS IDLE
  // both lines high
  // ==============================
  sda = 1;
  scl = 1;
  #SCL_HALF;

  // ==============================
  // START CONDITION
  // sda falls while scl high
  // ==============================
  sda = 0;              // sda falls = START
  #SCL_HALF;            // hold for delay FF to capture
  scl = 0;              // scl falls ready for address bits
  #SCL_HALF;

  // ==============================
  // ADDRESS BYTE
  // 7bit address + write bit
  // 1010101 + 0 = 10101010
  // ==============================
  send_byte(8'b1010_1010);
  ack_slot();

  // ==============================
  // CMD BYTE
  // 00100001
  // ==============================
  send_byte(8'b0010_0001);
  ack_slot();

  // ==============================
  // DATA BYTE
  // 11001010
  // after this we generate STOP
  // no normal ack_slot here
  // instead use ack_then_stop task
  // which keeps scl high after ACK
  // then raises sda for STOP
  // ==============================
  send_byte(8'b1100_1010);

  // ==============================
  // ACK + STOP COMBINED
  //
  // after send_byte ends:
  //   scl = LOW
  //   sda = last bit value
  //   state = DATA_ACK (bit_count reached 8
  //           on 8th scl_rising_edge)
  //
  // step1: sda = 0 while scl low  SAFE
  //        no condition fires
  //        scl is low so no sampling
  //
  // step2: scl = 1 rises
  //        state is DATA_ACK not DATA
  //        so no data capture happens
  //        ack signal is high here
  //        sda = 0 here
  //
  // step3: sda = 1 rises while scl HIGH
  //        sdl_delay = 0 (was 0 before)
  //        sdl = 1 (now high)
  //        scl = 1 (high)
  //        stop = scl & sda & ~sdl_delay
  //             = 1   & 1   & ~0
  //             = 1   STOP FIRES
  //        DATA_ACK sees stop ¿ IDLE
  // ==============================

  // step 1
  sda = 0;              // sda low while scl low SAFE
  #SCL_HALF;            // hold

  // step 2
  scl = 1;              // scl rises
                        // state is DATA_ACK
                        // ack is high here
                        // no data capture
  #SCL_HALF;            // hold scl high

  if(ack == 1)
    $display("ACK  at time %0t", $time);
  else
    $display("NACK at time %0t", $time);

  // step 3
  sda = 1;              // sda rises while scl HIGH = STOP
                        // stop fires on next clk posedge
                        // DATA_ACK ¿ IDLE
  #SCL_HALF;            // hold for FF to capture stop
  #SCL_HALF;            // extra hold for state to transition

  // ==============================
  // BUS IDLE AFTER STOP
  // ==============================
  scl = 1;
  sda = 1;
  #(SCL_HALF * 4);

  $display("=========================");
  $display("transaction complete");
  $display("=========================");
  $finish;
end

// ==============================
// TASK send_byte
// sends 8 bits MSB first
// sda driven when scl is low
// scl rises for slave to capture
// scl falls after each bit
// leaves scl LOW after last bit
// ==============================
task send_byte;
  input [7:0] byte_data;
  integer i;
  begin
    for(i = 7; i >= 0; i = i-1) begin

      sda = byte_data[i];       // drive bit when scl low
      #SCL_HALF;                // sda settles

      scl = 1;                  // scl rises
                                // scl_rising_edge fires
                                // slave samples sda
      #SCL_HALF;                // hold scl high

      scl = 0;                  // scl falls
                                // scl_falling_edge fires
      #SCL_HALF;                // hold scl low
    end
    // after loop:
    // scl = LOW
    // sda = last bit value
    // if 8th scl_rising_edge moved state to DATA_ACK
    // we are now in DATA_ACK with bit_count = 0
  end
endtask

// ==============================
// TASK ack_slot
// used for ADDR and CMD ack
// master releases sda
// scl rises ACK slot active
// scl drops at end
// leaves scl LOW sda HIGH
// ==============================
task ack_slot;
  begin
    sda = 1;                    // master releases sda
    #SCL_HALF;                  // hold

    scl = 1;                    // scl rises ACK slot
    #SCL_HALF;                  // hold

    if(ack == 1)
      $display("ACK  at time %0t", $time);
    else
      $display("NACK at time %0t", $time);

    scl = 0;                    // scl falls
                                // ADDR_ACK ¿ CMD
                                // CMD_ACK  ¿ DATA
    #SCL_HALF;
    // leaves scl LOW sda HIGH
  end
endtask

// waveform dump
initial begin
  $dumpfile("tb_bus_slave.vcd");
  $dumpvars(0, tb_bus_slave);
end

endmodule


