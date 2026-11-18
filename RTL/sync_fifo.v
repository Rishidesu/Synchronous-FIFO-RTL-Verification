`timescale 1ns/1ps
module sync_fifo #(
 parameter DATA_WIDTH=8, DEPTH=8, PTR_WIDTH=3, COUNT_WIDTH=4
)(
 input wire clk,rst_n,wr_en,rd_en,
 input wire [DATA_WIDTH-1:0] wr_data,
 output reg [DATA_WIDTH-1:0] rd_data,
 output wire full,empty,
 output reg [COUNT_WIDTH-1:0] count
);
reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
reg [PTR_WIDTH-1:0] wr_ptr,rd_ptr;
wire do_write,do_read;
assign full=(count==DEPTH);
assign empty=(count==0);
assign do_read=rd_en && !empty;
assign do_write=wr_en && (!full || do_read);
function [PTR_WIDTH-1:0] next_ptr;
 input [PTR_WIDTH-1:0] ptr;
 begin
  if(ptr==DEPTH-1) next_ptr=0;
  else next_ptr=ptr+1'b1;
 end
endfunction
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  wr_ptr<=0; rd_ptr<=0; rd_data<=0; count<=0;
 end else begin
  if(do_write) begin mem[wr_ptr]<=wr_data; wr_ptr<=next_ptr(wr_ptr); end
  if(do_read) begin rd_data<=mem[rd_ptr]; rd_ptr<=next_ptr(rd_ptr); end
  case({do_write,do_read})
   2'b10: count<=count+1'b1;
   2'b01: count<=count-1'b1;
   default: count<=count;
  endcase
 end
end
endmodule
