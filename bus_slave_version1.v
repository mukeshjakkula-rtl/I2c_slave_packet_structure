module pm_bus_slave(
  input clk,rst,
  input sda,scl,
  output reg ack,error,
  output reg data_out);

  reg [7:0]shift_reg,addr_reg,cmd_reg,data_reg;
  reg [3:0]clk_count;
  reg [7:0]mem_data;
  wire sdl_delay,scl_delay;
  wire start,scl_rising_edge,scl_falling_edge,stop;
  wire addr_ack,cmd_ack,data_ack;


 typedef enum logic [2:0]{IDLE     = 3'd0,
                          ADDR     = 3'd1,
                          ADDR_ACK = 3'd2,
                          CMD      = 3'd3,
                          CMD_ACK  = 3'd4,
                          DATA     = 3'd5,
                          DATA_ACK = 3'd6}bus_states;
 bus_states state;                        

always@(posedge clk, negedge rst) begin
  if(!rst) begin
    clk_count <= 4'd0;
  end else begin
   if(state == IDLE) clk_count <= 4'd0;
   if(scl_rising_edge) begin
     clk_count <= clk_count + 1;
     if(clk_count == 4'd8) clk_count <= 4'd0;
     end 
  end   
end 

always@(posedge clk, negedge rst) begin
  if(!rst) begin
    state <= IDLE;
    shift_reg <= 8'd0;
    addr_reg <= 8'd0;
    cmd_reg <= 8'd0;
    data_reg <= 8'd0;
  end else begin
    case(state) 

      IDLE : begin
        data_out <= 1'b0;
        if(start) state <= ADDR;
        else state <= IDLE;
      end // IDLE
     
      ADDR : begin
       if(scl_rising_edge) begin  
         shift_reg <= {shift_reg[6:0],sda};
       end else state <= ADDR;
       if(clk_count == 4'd8 && scl_falling_edge) state <= ADDR_ACK;
      end // ADDR

      ADDR_ACK : begin
        addr_reg <= shift_reg;
        if(scl_falling_edge) state <= CMD;
      end // ADDR_ACK
     
     CMD : begin
       if(scl_rising_edge) begin  
         shift_reg <= {sda, shift_reg[6:0]};
       end else state <= CMD;
       if(clk_count == 4'd8 && scl_falling_edge) state <= CMD_ACK;
     end // CMD

     CMD_ACK : begin
       cmd_reg <= shift_reg;
       if(scl_falling_edge) state <= DATA;
     end // CMD_ACK

    DATA : begin
       if(scl_rising_edge) begin  
         shift_reg <= {sda, shift_reg[6:0]};
       end else state <= DATA;
       if(clk_count == 4'd8 && scl_falling_edge) state <= DATA_ACK;
       if(stop) state <= IDLE;
    end // DATA

    DATA_ACK : begin
      data_reg <= shift_reg;
      if(scl_falling_edge) state <= DATA;
      if(stop) state <= IDLE;
    end // DATA_ACK

     default : state <= IDLE;
    endcase
  end 
end 


// delay modules to detect the falling and rising edges of the sda and scl

delay f0(.clk(clk), .rst(rst), .d(sda), .q(sdl_delay));
delay f1(.clk(clk), .rst(rst), .d(scl), .q(scl_delay));

assign start = (scl && (~sda & sdl_delay));  // scl high and sda falling edge detects START
assign stop =  (scl && (sda & ~sdl_delay)); //  scl high and sda rising edge setects STOP
assign scl_rising_edge = (scl & ~scl_delay);  // genretates caputure when scl rising edge to sample the data bit
assign scl_falling_edge = (~scl & scl_delay); // for sending the ack signal at the falling edge of scl

// ack signals for the appropriate states
assign addr_ack = (state == ADDR_ACK);
assign cmd_ack = (state == CMD_ACK);
assign data_ack = (state == DATA_ACK);
assign ack = addr_ack | cmd_ack | data_ack;

endmodule 

module delay(
 input clk,rst,d,
 output reg q);
 always@(posedge clk,negedge rst) begin
   if(!rst) q <= 1'b0;
   else q <= d;
  end
endmodule 
