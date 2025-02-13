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

// Compares 2 WIDTH bit numbers A and B 
// and sets AeqB when equal,
// sets AltB if A < B and
// sets AgtB if A > B
module MagComparator
  #(parameter WIDTH = 8)
  (input logic [WIDTH-1:0] A, B, 
   output logic AltB, AeqB, AgtB);

   assign AeqB = A === B;
   assign AltB = A < B;
   assign AgtB = A > B;

endmodule: MagComparator

// Stores and loads when enabled WIDTH bit numbers
module Register
  #(parameter WIDTH = 8)
   (input logic en, clock, reset,
    input logic [WIDTH-1:0] D,
    output logic [WIDTH-1:0] Q);

    always_ff @(posedge clock, posedge reset)
      if (reset)
        Q <= '0;
      else if (en)
        Q <= D;

endmodule: Register
