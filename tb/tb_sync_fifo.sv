`timescale 1ns/1ps
module tb_sync_fifo;
localparam DATA_WIDTH=8, DEPTH=8, PTR_WIDTH=3, COUNT_WIDTH=4;
reg clk=0,rst_n=0,wr_en=0,rd_en=0;
reg [DATA_WIDTH-1:0] wr_data=0;
wire [DATA_WIDTH-1:0] rd_data;
wire full,empty;
wire [COUNT_WIDTH-1:0] count;
reg [DATA_WIDTH-1:0] reference_mem[0:DEPTH-1];
integer ref_wr_ptr=0,ref_rd_ptr=0,ref_count=0;
reg [DATA_WIDTH-1:0] expected_data=0;
integer tests=0,errors=0,writes=0,reads=0;
integer cov_empty=0,cov_middle=0,cov_full=0,cov_write=0,cov_read=0;
integer cov_simultaneous=0,cov_overflow=0,cov_underflow=0,cov_wraparound=0;
integer i,random_op;
reg [7:0] random_data;
reg expected_write,expected_read;
always #5 clk=~clk;
sync_fifo #(.DATA_WIDTH(DATA_WIDTH),.DEPTH(DEPTH),.PTR_WIDTH(PTR_WIDTH),.COUNT_WIDTH(COUNT_WIDTH)) dut (
 .clk(clk),.rst_n(rst_n),.wr_en(wr_en),.rd_en(rd_en),.wr_data(wr_data),
 .rd_data(rd_data),.full(full),.empty(empty),.count(count)
);
task reset_fifo;
begin
 @(negedge clk); rst_n=0; wr_en=0; rd_en=0; wr_data=0;
 ref_wr_ptr=0; ref_rd_ptr=0; ref_count=0; expected_data=0;
 repeat(3) @(posedge clk);
 #1;
 if(count!==0 || empty!==1 || full!==0 || rd_data!==0) $fatal(1,"RESET FAILURE");
 @(negedge clk); rst_n=1;
end
endtask
task automatic transact;
 input reg w,r;
 input reg [7:0] data;
begin
 @(negedge clk); wr_en=w; rd_en=r; wr_data=data;
 expected_read=r && (ref_count>0);
 expected_write=w && ((ref_count<DEPTH) || expected_read);
 if(ref_count==0) cov_empty=cov_empty+1;
 else if(ref_count==DEPTH) cov_full=cov_full+1;
 else cov_middle=cov_middle+1;
 if(w) cov_write=cov_write+1;
 if(r) cov_read=cov_read+1;
 if(w && r) cov_simultaneous=cov_simultaneous+1;
 if(w && !expected_write) cov_overflow=cov_overflow+1;
 if(r && !expected_read) cov_underflow=cov_underflow+1;
 if(expected_read) begin
  expected_data=reference_mem[ref_rd_ptr];
  if(ref_rd_ptr==DEPTH-1) begin ref_rd_ptr=0; cov_wraparound=cov_wraparound+1; end
  else ref_rd_ptr=ref_rd_ptr+1;
  reads=reads+1;
 end
 if(expected_write) begin
  reference_mem[ref_wr_ptr]=data;
  if(ref_wr_ptr==DEPTH-1) begin ref_wr_ptr=0; cov_wraparound=cov_wraparound+1; end
  else ref_wr_ptr=ref_wr_ptr+1;
  writes=writes+1;
 end
 case({expected_write,expected_read})
  2'b10: ref_count=ref_count+1;
  2'b01: ref_count=ref_count-1;
  default: ref_count=ref_count;
 endcase
 @(posedge clk); #1; tests=tests+1;
 if(count!==ref_count) begin $display("FAIL COUNT test=%0d expected=%0d actual=%0d",tests,ref_count,count); errors=errors+1; end
 if(full!==(ref_count==DEPTH)) begin $display("FAIL FULL test=%0d",tests); errors=errors+1; end
 if(empty!==(ref_count==0)) begin $display("FAIL EMPTY test=%0d",tests); errors=errors+1; end
 if(rd_data!==expected_data) begin $display("FAIL DATA test=%0d expected=%h actual=%h",tests,expected_data,rd_data); errors=errors+1; end
 if(count>DEPTH) begin $display("ASSERTION FAIL: count > DEPTH"); errors=errors+1; end
 if(ref_count<0 || ref_count>DEPTH) begin $display("ASSERTION FAIL: reference count"); errors=errors+1; end
 if(errors!=0) $fatal(1,"Verification failed");
end
endtask
initial begin
 $dumpfile("dump.vcd"); $dumpvars(0,tb_sync_fifo);
 $display("==================================");
 $display("SYNCHRONOUS FIFO VERIFICATION");
 $display("Verilog RTL + SystemVerilog TB");
 $display("==================================");
 reset_fifo();
 $display("TEST 1: Read from empty FIFO"); transact(0,1,8'h00);
 $display("TEST 2: Fill FIFO"); for(i=0;i<DEPTH;i=i+1) transact(1,0,8'h10+i);
 $display("TEST 3: Overflow protection"); transact(1,0,8'hFF);
 $display("TEST 4: Simultaneous at full"); transact(1,1,8'hA5);
 $display("TEST 5: Drain FIFO"); for(i=0;i<DEPTH;i=i+1) transact(0,1,8'h00);
 $display("TEST 6: Simultaneous at empty"); transact(1,1,8'h55);
 $display("TEST 7: Pointer wraparound"); for(i=0;i<24;i=i+1) begin transact(1,0,i); transact(0,1,0); end
 $display("TEST 8: Randomized verification");
 for(i=0;i<1000;i=i+1) begin
  random_op=$urandom_range(0,3); random_data=$urandom;
  case(random_op)
   0: transact(0,0,random_data);
   1: transact(1,0,random_data);
   2: transact(0,1,random_data);
   3: transact(1,1,random_data);
  endcase
 end
 $display("TEST 9: Final drain"); while(ref_count>0) transact(0,1,0);
 $display("TEST 10: Reset after activity"); transact(1,0,8'hAB); transact(1,0,8'hCD); reset_fifo();
 $display("\n==================================");
 $display("FINAL VERIFICATION REPORT");
 $display("==================================");
 $display("Total transactions : %0d",tests);
 $display("Accepted writes    : %0d",writes);
 $display("Accepted reads     : %0d",reads);
 $display("Errors             : %0d",errors);
 $display("\nCOVERAGE EVENT COUNTS");
 $display("Empty state        : %0d",cov_empty);
 $display("Middle state       : %0d",cov_middle);
 $display("Full state         : %0d",cov_full);
 $display("Write requests     : %0d",cov_write);
 $display("Read requests      : %0d",cov_read);
 $display("Simultaneous reqs  : %0d",cov_simultaneous);
 $display("Blocked writes     : %0d",cov_overflow);
 $display("Blocked reads      : %0d",cov_underflow);
 $display("Pointer wraparounds: %0d",cov_wraparound);
 $display("==================================");
 if(errors==0) $display("ALL FIFO TESTS PASSED");
 else $fatal(1,"FIFO TESTS FAILED");
 $finish;
end
initial begin #100000; $fatal(1,"WATCHDOG TIMEOUT"); end
endmodule
