`default_nettype none
module RangeFinder
  #(parameter WIDTH=16)
  (input logic [WIDTH-1:0] data_in,
   input logic clock, reset,
   input logic go, finish,
   output logic [WIDTH-1:0] range,
   output logic debug_error);

   logic valid_go, saw_go, saw_error;
   logic [WIDTH-1:0] curr_max, curr_min; 
   logic new_max, new_min;
   logic max_en, min_en;
  
   assign valid_go = go && !finish;
   assign max_en = (valid_go || (saw_go && new_max));
   assign min_en = (valid_go || (saw_go && new_min));

   assign range = (max_en ? data_in : curr_max) - (min_en ? data_in : curr_min);
   assign debug_error = ((saw_error && !saw_go) || (go && finish) ||
                         !saw_go && finish);

   MagComparator #(WIDTH) max_finder(.A(data_in), .B(curr_max), 
                                    .AltB(), .AeqB(), .AgtB(new_max));
   MagComparator #(WIDTH) min_finder(.A(data_in), .B(curr_min), 
                                    .AltB(new_min), .AeqB(), .AgtB());

   Register #(WIDTH) max_tracker(.en(max_en), .reset, .clock, 
                                 .D(data_in), .Q(curr_max));
   Register #(WIDTH) min_tracker(.en(min_en), .reset, .clock, 
                                 .D(data_in), .Q(curr_min));

   always_ff @(posedge clock, posedge reset) begin
     if (reset) begin
       saw_go <= 1'b0;
     end else if (valid_go) begin
       saw_go <= 1'b1;
     end else if (finish && saw_go) begin
       saw_go <= 1'b0;
     end
   end
  	
   always_ff @(posedge clock, posedge reset) begin
     if (reset) begin
       saw_error <= 1'b0;
     end else begin
       saw_error <= debug_error;
     end
   end

endmodule: RangeFinder
   
module RangeFinder_test();

  logic [15:0] data_in, range;
  logic        clock, reset, go, finish, debug_error;

  RangeFinder #(16) rf(.*);
  
  initial begin
    reset = 1'b1;
    reset <= 1'b0;
    clock = 1'b0;
    forever #5 clock = ~clock;
  end
  
  initial
    $monitor($stime," data_in(%h) go(%b) finish(%b) range(%h): hi(%h) lo(%h) error(%b)",
            data_in, go, finish, range, rf.curr_max, rf.curr_min, debug_error);
    
  initial begin
    // found on page 687 of SV Standard
    $dumpfile("dump.vcd"); $dumpvars;
    data_in <= 16'h7FFF; {go, finish} <= '0;
    
    // Simple sequence of 7FFF, 8000, 8001, 7FFE --> expect range of 3
    @(posedge clock);
    @(posedge clock);
    go <= 1'b1;
    @(posedge clock);

    data_in <= 16'h8000;
    go <= 1'b0;
    @(posedge clock);

    data_in <= 16'h8001;
    @(posedge clock);
    
    data_in <= 16'h7FFE;
    @(posedge clock);
    
    data_in <= 16'h7FFF;  // doesn't change outer bounds
    @(posedge clock);
    
    finish <= 1'b1;
    @(posedge clock);
    {go, finish} <= '0;
    #1 assert (range == 16'h0003) else $display($stime, "range=%h, expected = 16'h0003", range);
    
    @(posedge clock);
    
    // Error sequence, go and finish at the same time
    {go, finish} <= '1;
    @(posedge clock);
    #1 assert (debug_error == 1'b1) else $display($stime, "Error was not caught");
    {go, finish} <= '0;
    
    @(posedge clock);

    // Error sequence, finish before go
    @(posedge clock);
    @(posedge clock);
    finish <= 1'b1;
    @(posedge clock);
    #1 assert (debug_error == 1'b1) else $display($stime, "Error was not caught");
      
    // And, should stay in the error state until a go happens
    @(posedge clock);
    #1 assert (debug_error == 1'b1) else $display($stime, "Should still be in error state");
    finish <= 1'b0;
    @(posedge clock);
    #1 assert (debug_error == 1'b1) else $display($stime, "Should still be in error state");

    data_in <= 16'h0100;
    go <= 1'b1;
    @(posedge clock);
    go <= 1'b0;
    #1 assert (debug_error == 1'b0) else $display($stime, "Should NOT still be in error state");

    // Check widest possible range (note, already started a sequence with go on last clock)
    data_in <= 16'h0000;
    @(posedge clock);
    data_in <= 16'hFFFF;
    @(posedge clock);
    data_in <= 16'h0200;
    finish <= 1'b1;
    @(posedge clock);
    finish <= 1'b0;
    #1 assert (range == 16'hFFFF) else $display($stime, "Expected range to be 16'hFFFF");
    
    @(posedge clock);
    @(posedge clock);
    
    $dumpoff;
    
    $finish();
  end           

endmodule : RangeFinder_test