module bus_slave(
  input clk,rst,
  input sdl,scl,
  output reg ack,error,
  output reg data_out);

  reg [7:0]shift_reg,addr_reg,cmd_reg,data_reg;
  reg [3:0]bit_count;
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


 always@(posedge clk,negedge rst) begin
   if(!rst) begin
      state <= IDLE;
      shift_reg <= 8'h00;
      data_out <= 1'b0;
      bit_count <= 3'b000;
      error <= 1'b0;
   end else begin
     case(state)

       IDLE : begin
         data_out <= 1'b0;
         bit_count <= 3'b000;

         if(start) begin
           shift_reg <= mem_data;
           state <= ADDR;
         end else begin
           state <= IDLE;
         end 
       end // IDLE

       ADDR : begin
        if(scl_rising_edge) begin
          if(bit_count == 4'd8) begin
            state <= ADDR_ACK;
            bit_count <= 4'h0;
          end else begin
             addr_reg <= {sdl,addr_reg[7:1]};
             state <= ADDR;
             bit_count <= bit_count + 1;
           end   
          end 
        end // ADDR
      
      ADDR_ACK : begin
        if(scl_falling_edge) state <= CMD;
      end //ADDR_ACK

      CMD : begin
       if(scl_rising_edge) begin
          if(bit_count == 4'd8) begin
            state <= CMD_ACK;
            bit_count <= 4'd0;
          end else begin
             cmd_reg <= {sdl,cmd_reg[7:1]};
             bit_count <= bit_count + 1;
             state <= CMD;
           end  
          end 
        end // CMD

      CMD_ACK : begin
       if(scl_falling_edge) state <= DATA;
      end // CMD_ACK

      DATA : begin
       if(scl_rising_edge) begin
         if(bit_count == 4'd8) begin
           state <= DATA_ACK;
           bit_count <= 4'd0;
         end else begin
            data_out <= data_reg[7];
            data_reg <= data_reg << 1;
            bit_count <= bit_count + 1;
            state <= DATA;
          end 
         end 
         if(stop && bit_count < 4'd8) begin
           state <= IDLE;
           error <= 1'b1;
         end
      end // DATA
      
// works if the stop or start condition happens immediately (by master) after the last bit
      DATA_ACK : begin
        if(scl_falling_edge) begin
          if(start) state <= ADDR;
           else state <= DATA; 
         end 
         if(stop) state <= IDLE;
        end // DATA_ACK
     endcase
   end 
 end 

// delay modules to detect the falling and rising edges of the sdl and scl

delay f0(.clk(clk), .rst(rst), .d(sdl), .q(sdl_delay));
delay f1(.clk(clk), .rst(rst), .d(scl), .q(scl_delay));

assign start = (scl && (~sdl & sdl_delay));  // scl high and sdl falling edge detects START
assign stop =  (scl && (sdl & ~sdl_delay)); //  scl high and sdl rising edge setects STOP
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
