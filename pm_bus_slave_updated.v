module pm_bus_slave_updated(
  input clk,rst,
  input sda,scl,
  output reg ack,error,
  output reg data_out);

  reg [3:0]clk_count;
  wire sdl_delay,scl_delay;
  wire start,scl_rising_edge,scl_falling_edge,stop;
  wire addr_ack,cmd_ack,data_ack;

   // current_state registers 
  reg [7:0]shift_reg, addr_reg, cmd_reg, data_reg;

  // next_state registers 
  reg [7:0]next_shift_reg, next_cmd_reg, next_data_reg, next_addr_reg, next_error;


 typedef enum logic [2:0]{IDLE     = 3'd0,
                          ADDR     = 3'd1,
                          ADDR_ACK = 3'd2,
                          CMD      = 3'd3,
                          CMD_ACK  = 3'd4,
                          DATA     = 3'd5,
                          DATA_ACK = 3'd6}bus_states;
 bus_states current_state, next_state;                        

always@(posedge clk, negedge rst) begin
  if(!rst) begin
    clk_count <= 4'd0;
  end else begin
   if(current_state == IDLE) clk_count <= 4'd0;
   if(scl_rising_edge) begin
     clk_count <= clk_count + 1;
     if(clk_count == 4'd8) clk_count <= 4'd0;
     end 
  end   
end 


// fsm states and signal registering
always@(posedge clk,negedge rst) begin
  if(!rst) begin
    current_state <= IDLE;
    shift_reg <= 8'd0;
    cmd_reg  <= 8'd0;
    data_reg <= 8'd0;
    addr_reg <= 8'd0;
    error <= 1'b0;
  end else begin
    current_state <= next_state;
    shift_reg <= next_shift_reg;
    cmd_reg   <= next_cmd_reg;
    addr_reg  <= next_addr_reg;
    data_reg  <= next_data_reg;
    error  <= next_error;
  end 
end 



// next_state logic
always@(*) begin

// so that we dont have to mention the else statements inside the case
// conditions cause only one else is there for every condition 
   next_state = current_state;
   next_shift_reg = shift_reg;
   next_data_reg  = data_reg;
   next_cmd_reg  = cmd_reg;
   next_addr_reg = addr_reg;
   next_error = error;

  case(current_state)
     IDLE : begin
       data_out = 1'b0;
       next_shift_reg = 8'd0;
       next_cmd_reg = 8'd0;
       next_addr_reg = 8'd0;
       next_data_reg = 8'd0;
       if(start) next_state = ADDR;
     end // IDLE

     ADDR : begin
       if(scl_rising_edge) next_shift_reg = {shift_reg[6:0],sda};
       if(clk_count == 4'd8 && scl_falling_edge) next_state = ADDR_ACK;
     end // ADDR

     ADDR_ACK : begin
       next_addr_reg = shift_reg;
       if(scl_falling_edge) next_state = CMD;
     end // ADDR_ACK

     CMD : begin
       if(scl_rising_edge) next_shift_reg = {shift_reg[6:0],sda};
       if(clk_count == 4'd8 && scl_falling_edge) next_state = CMD_ACK;
     end // CMD

     CMD_ACK : begin
      next_cmd_reg = shift_reg;
      if(scl_falling_edge) next_state = DATA;
     end // CMD_ACK

     DATA : begin
       if(scl_rising_edge) next_shift_reg = {shift_reg[6:0],sda};
       if(clk_count == 4'd8 && scl_falling_edge) next_state = DATA_ACK;

       if(stop) begin
         next_state = IDLE;
         if(clk_count < 4'd8) next_error = 1'b1;
       end   
       if(start) next_state = ADDR;
     end // IDLE

     DATA_ACK : begin
       next_data_reg = shift_reg;
       if(scl_falling_edge) next_state = DATA;
       if(stop) next_state = IDLE;
     end // IDLE_ACK

     default : next_state = IDLE;
  endcase
end


// delay modules to detect the falling and rising edges of the sda and scl

delay f0(.clk(clk), .rst(rst), .d(sda), .q(sdl_delay));
delay f1(.clk(clk), .rst(rst), .d(scl), .q(scl_delay));

assign start = (scl && (~sda & sdl_delay));  // scl high and sda falling edge detects START
assign stop =  (scl && (sda & ~sdl_delay)); //  scl high and sda rising edge setects STOP
assign scl_rising_edge = (scl & ~scl_delay);  // genretates caputure when scl rising edge to sample the data bit
assign scl_falling_edge = (~scl & scl_delay); // for sending the ack signal at the falling edge of scl

// ack signals for the appropriate states
assign addr_ack = (current_state == ADDR_ACK);
assign cmd_ack = (current_state == CMD_ACK);
assign data_ack = (current_state == DATA_ACK);
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
