`timescale 1ns / 1ps


// DESIGN NOTE: regarding using vivado's Block memory IP:
//
// Original implementation used a plain behavioral BRAM:
//   reg bram [0:524287];  // 1-bit wide × 524,288 deep
//   initial $readmemb("STATE_0.mem", bram);
//
// This caused a display bug where only the top ~64 rows of the
// screen would show the initialized pattern, everything below
// was black. Root cause: at 1-bit width, a single RAMB36E2
// primitive can only hold 32,768 entries. Vivado was cascading
// 16 of them in series to hit our 524,288 depth, but only
// initializing the first 1-2 primitives via $readmemb —
// the rest powered up as zeros.
//
// Fix: switched to Block Memory Generator IP with a .coe file.
// The IP guarantees all INIT_xx attributes are properly written
// across every primitive in the cascade at synthesis time.
// $readmemb is simulation-only and fragile for hardware init.

/////////////////// OLD IMPLEMENTATION //////////////////////
//module dp_bram(

//    input  wire        clk, we, wr_data,
//    input  wire [9:0]              wr_x,
//    input  wire [8:0]              wr_y,
//    input  wire [9:0]              rd_x, 
//    input  wire [8:0]              rd_y,
//    output reg                  rd_data

//    );
	
//	// 2^19; 
//    reg bram [0:524287];
//integer i;
//reg [18:0] lfsr;

//initial begin
//    lfsr = 19'h1ACE1; // non-zero seed

//    for (i = 0; i < 524288; i = i + 1) begin
//        bram[i] = lfsr[0];

//        // 19-bit LFSR (primitive polynomial)
//        lfsr = {lfsr[17:0], lfsr[18] ^ lfsr[1] ^ lfsr[0]};
//    end
//end

////	// load file for random data (init state)
//    //initial $readmemb("full_frame_mod3.mem", bram);

    
//    wire [18:0] addr_r;
//    wire [18:0] addr_w;
//    assign addr_r = {rd_y, rd_x}; 
//    assign addr_w = {wr_y, wr_x};   
//    always @ (posedge clk) begin
//        rd_data <= bram[addr_r];
    
        

////    	rd_data   <=  chkr[2];
////    	chkr <= chkr + 1'b1;
//    	// Write data to write address if write enable is asserted
//    	if (we)  begin
//            bram[addr_w] <= wr_data;
//            end
            
//      end
      
//      endmodule
////////////////////////////////////////////////////////////

module dp_bram(

    input  wire            clk,
    input  wire             we,
    input  wire        wr_data,
    input  wire [9:0]     wr_x,
    input  wire [8:0]     wr_y,
    input  wire [9:0]     rd_x,
    input  wire [8:0]     rd_y,
    output reg         rd_data

);

    wire [18:0] addr_w = {wr_y, wr_x};
    wire [18:0] addr_r = {rd_y, rd_x};

    wire rd_data_raw;

    blk_mem_gen_0 bram_inst (

        // PORT A (WRITE)
        .clka      (clk),
        .ena      (1'b1),
        .wea        (we),
        .addra  (addr_w),
        .dina  (wr_data),
        .douta        (),

        // PORT B (READ)
        .clkb      (clk),
        .enb      (1'b1),
        .web      (1'b0),
        .addrb  (addr_r),
        .dinb     (1'b0),
        .doutb (rd_data)
    );

endmodule