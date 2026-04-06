module copy_bram(   //copies the entire content within X_MAX x Y_MAX window of bram1 to bram2;

	
	input wire      clk,
    input wire   areset,
	input wire    start,

	// read one cell to write each posedge
	input wire  data_in,

	// registers to track the read and write addresses (what's read from bram1 now will be written to bram2 next cycle)
	output reg [9:0]  rd_addr_x = 10'b0000000000, wr_addr_x = 10'b0000000000,
	output reg [8:0]  rd_addr_y =   9'b000000000, wr_addr_y =   9'b000000000,
    //whole address concatnated from: {addr_y, addr_x};

	// write enable, 
	output wire   wr_en,
	output reg  data_out

    );
    // Parameters for the size of the screen
    localparam X_MAX 	=        10'd639;   //purposefully redundant
    localparam Y_MAX 	=         9'd479;
    localparam X_ZERO 	= 10'b0000000000;
    localparam Y_ZERO 	=   9'b000000000;

    // ragister to track whether the module is enabled or not
    reg enable = 1'b0, enable_next;

    // next_state logic for the read and write addresses

    reg [9:0] rd_addr_x_next = X_ZERO, wr_addr_x_next = X_ZERO;
    reg [8:0] rd_addr_y_next = Y_ZERO, wr_addr_y_next = Y_ZERO;
    // next state of the write enable
    reg wr_en_next  =  1'b0;


    always @ (posedge clk, posedge areset) begin 
        if (areset) begin

            rd_addr_x 		<=          X_ZERO;
    	    rd_addr_y 		<=          Y_ZERO;
    	    wr_addr_x 		<=          X_ZERO;
    	    wr_addr_y 		<=          Y_ZERO;
    	    data_out		<=            1'b0;
            enable          <=            1'b0;

        end else begin

    	enable <= enable_next;

    	if(enable) begin
    		rd_addr_x 		<=  rd_addr_x_next;
    	    rd_addr_y 		<=  rd_addr_y_next;
    	    wr_addr_x_next 	<=       rd_addr_x;
    	    wr_addr_y_next 	<=       rd_addr_y;
    	    wr_addr_x 		<=  wr_addr_x_next;
    	    wr_addr_y 		<=  wr_addr_y_next;
    	    data_out		<=         data_in;
    	end

        end
    end
    // combinatiorial logic to determine the next state of the variables
    always_comb begin
    	// Increment X and Y when appropriate
    	rd_addr_y_next  = (enable_next == 1'b0) ? Y_ZERO : (rd_addr_x == X_MAX + 10'b1111111111) ? 
                                ( (rd_addr_y < Y_MAX + 9'b111111111) ? rd_addr_y + 1'b1 : Y_ZERO) : rd_addr_y;

        rd_addr_x_next  = (enable_next == 1'b0) ? X_ZERO : (rd_addr_x == X_MAX + 10'b1111111111) ? X_ZERO : rd_addr_x + 1'b1;
    	// keep the module enabled if its not done yet, and start the module is the start pulse is seen
    	case({start, enable}) 		
            2'b01:		
                begin
            		if(wr_addr_x == X_ZERO & wr_addr_y == Y_ZERO)
                        enable_next = 1'b0; //upon rolling back to first cell, transition has completed
            		else                                         
                        enable_next = 1'b1;
            	end
            2'b00:		enable_next = 1'b0;
            default:	enable_next = 1'b1;
        endcase
    end   
    assign wr_en = enable;   //write until rd_addr rolls back to first cell
endmodule