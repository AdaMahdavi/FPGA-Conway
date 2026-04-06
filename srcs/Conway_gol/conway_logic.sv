module conway_logic (
    input wire      clk,
    input wire   areset,
	input wire    start,

	//--- Status of the cell at coordinates requested two cycles ago (dead or alive), read from BRAM
	input wire  rd_data,

	//--- registers to track the read and write addresses (what's read from bram1 now will be written to bram2 next cycle)
	output reg [9:0]  rd_addr_x = 10'b0000000000, wr_addr_x = 10'b0000000000,
	output reg [8:0]  rd_addr_y =   9'b000000000, wr_addr_y =   9'b000000000,
    //whole address concatnated from: {addr_y, addr_x} : 19 bits total;

	/*--- write enable: only set high when we have all 8 neighbors registered per central cell,
	  and can calculate its next state accordingly*/
	output reg   wr_en,
	output reg wr_data

    );
    //--- Parameters for VGA addressing boundaries
    localparam X_MAX 	=        10'd639;   
    localparam Y_MAX 	=         9'd479;
    localparam X_ZERO 	= 10'b0000000000;
    localparam Y_ZERO 	=   9'b000000000;

    /*--- ragister to track whether the module is enabled or not: 
       stops once the all required neighbors to calculate next state of last cell
       have been requested to be read (9'd479, 10'd639)*/
    reg enable = 1'b0, enable_next = 1'b0;


    /*--- registers to keep track of our central cell:
    which we're collecting neighors for, to calculate its next state */
    reg [9:0] c_cell_x  = X_ZERO, c_cell_x_next = X_ZERO;
    reg [8:0] c_cell_y  = Y_ZERO, c_cell_y_next = Y_ZERO;

    //--- we determine which neighbor address to request to be read from bram next
    reg [9:0] rd_addr_x_next = X_ZERO, wr_addr_x_next = X_ZERO;
    reg [8:0] rd_addr_y_next = Y_ZERO, wr_addr_y_next = Y_ZERO;
    
    
    //--- c_cell's calculated next state is only valid to be written once all neighbors are registered
    reg wr_en_next  =  1'b0;

    /*--- register to store central cell value and neighbor values in order
    
    state of registers in a complete neighbor state for central cell (y, x):
    -neighbors[0] ->    top-right (y+1, x+1);
    -neighbors[1] ->        right ( y , x+1);    
    -neighbors[2] -> bottom-right (y-1, x+1);
    -neighbors[3] ->          top (y+1,  x );
    -neighbors[4] ->       center ( y ,  x );
    -neighbors[5] ->       bottom (y-1,  x );
    -neighbors[6] ->     top-left (y+1, x-1);   
    -neighbors[7] ->         left ( y,  x-1); 
    -neighbors[8] ->  bottom-left (y-1, x-1);                    
    */
    reg [8:0] neighbors    = 9'b0;
    
    /*--- we keep track of neighbors we've requested gto be read;
      for left edge cells, we need to read all 8 neighbors, 
      for other cells, we can use 5 previous neighbors read while calculating next_state for (y, x-1)
      therefore, we do as following:
      
      neighbors <<< 3;
      -just read the three new neighbors: (3 right-most neighbors)
      (y+1, x+1);
      ( y , x+1);
      (y-1, x+1);
      
      */
    reg [3:0] neighbor_cnt = 4'b0 , neighbor_cnt_next = 4'b0 ;

    //---once all neighobrs and central cell states are registered, we count alive neighbors to apply in conway logic
    reg [3:0] alive_cells; 

    //if it's r
    wire left_edge = (c_cell_x == X_ZERO);


    reg c_cell_status;

    
    // Always block to clock through the next state of all the main variables
    always @ (posedge clk, posedge areset) begin
        if (areset) begin
              
        c_cell_x       <= X_ZERO; 
        //c_cell_x_next  <= X_ZERO;
        c_cell_y       <= Y_ZERO; 
        //c_cell_y_next  <= Y_ZERO;

        rd_addr_x      <= X_ZERO;
        //rd_addr_x_next <= X_ZERO;
        wr_addr_x      <= X_ZERO;
        //wr_addr_x_next <= X_ZERO;
        rd_addr_y      <= Y_ZERO;
        //rd_addr_y_next <= Y_ZERO; 
        wr_addr_y      <= Y_ZERO;
        //wr_addr_y_next <= Y_ZERO;
        
        end else begin
        
    
    	enable <= enable_next;
        	
        if(enable) begin
        	c_cell_x		<=     c_cell_x_next;
        	c_cell_y		<=     c_cell_y_next;
        	wr_addr_x 	    <=          c_cell_x;
        	wr_addr_y 	    <=          c_cell_y;
        	rd_addr_x 	    <=    rd_addr_x_next;
        	rd_addr_y 	    <=    rd_addr_y_next;
        	wr_data 	    <=     c_cell_status;
        	wr_en		    <=        wr_en_next;
        	neighbor_cnt    <= neighbor_cnt_next;
        	
        	// Read the read data into the conway grid
        	case(neighbor_cnt)
        		2 : neighbors[0] <= rd_data;
        		3 : neighbors[1] <= rd_data;
        		4 : neighbors[2] <= rd_data;
        		5 : begin if (left_edge)  neighbors[3] <= rd_data;  end
        		6 : begin 
                        if (left_edge) 
                        neighbors[4] <= rd_data;
        			    	
        			    else 
                        neighbors    <= {neighbors[5:0],3'b000};
        		    end
        		 //6 : neighbors[4] <= rd_data;
        		7 : neighbors[5] <= rd_data;
                8 : neighbors[6] <= rd_data;
                9 : neighbors[7] <= rd_data;
                10: neighbors[8] <= rd_data;   

        		11: neighbors    <= {neighbors[5:0],3'b000};

            endcase
        end              		
        end
    end
    
        // always block to determine the next state of all the variables based on which pixel is being read
        // and to calculate the total number of living cells as well as the next state of the given cell
        always_comb begin

            enable_next       =       enable;
            c_cell_x_next     =     c_cell_x;
            c_cell_y_next     =     c_cell_y;
            rd_addr_x_next    =    rd_addr_x;
            rd_addr_y_next    =    rd_addr_y;
            neighbor_cnt_next = neighbor_cnt;
            wr_en_next        =         1'b0;
            alive_cells       =         4'b0;

            for (integer i = 0; i < 9 ; i = i + 1) begin
                if (i != 4)  alive_cells = alive_cells + neighbors[i];
            end
            
        	
        	if (neighbors[4]) c_cell_status = ((alive_cells == 4'b0010) || (alive_cells == 4'b0011)) ? 1'b1 : 1'b0;
        	else c_cell_status = (alive_cells == 4'b0011) ? 1'b1 : 1'b0;
        	
        	
        	// The cells being read wrap around on the sides as well as the top and bottom of the screen
        	case(neighbor_cnt)
        		0: 	begin  //+1 +1
        				rd_addr_x_next    = ( c_cell_x == X_MAX ) ? X_ZERO : c_cell_x + 1'b1;
        				rd_addr_y_next    = ( c_cell_y == Y_MAX ) ? Y_ZERO : c_cell_y + 1'b1;
        				neighbor_cnt_next = neighbor_cnt + 1'b1;
        				wr_en_next        =                1'b0;
        				c_cell_x_next     =            c_cell_x;
        				c_cell_y_next     =            c_cell_y;
        				enable_next       = ((c_cell_x == X_ZERO) & (c_cell_y == Y_ZERO) & (start == 1'b1)) ? 1'b1 : enable;
        			end
        		1:	begin //+1 0
        				rd_addr_x_next    = ( c_cell_x == X_MAX ) ? X_ZERO : c_cell_x + 1'b1;
        				rd_addr_y_next    =            c_cell_y;
        				neighbor_cnt_next = neighbor_cnt + 1'b1;
        				wr_en_next        =                1'b0;
        				c_cell_x_next     =            c_cell_x;
        				c_cell_y_next     =            c_cell_y;
        				enable_next       =              enable;
        		    end
        		2:	begin //+1 -1
		                rd_addr_x_next    = ( c_cell_x ==  X_MAX ) ? X_ZERO : c_cell_x +         1'b1;
        				rd_addr_y_next    = ( c_cell_y == Y_ZERO ) ? Y_MAX  : c_cell_y + 9'b111111111;
        				neighbor_cnt_next = neighbor_cnt + 1'b1;
        				wr_en_next        =                1'b0;
        				c_cell_x_next     =            c_cell_x;
        				c_cell_y_next     =            c_cell_y;
        				enable_next       =              enable;
        			end
    			3:	begin  //0 +1
		                rd_addr_x_next    =            c_cell_x;
        				rd_addr_y_next    = ( c_cell_y == Y_MAX ) ? Y_ZERO : c_cell_y + 1'b1;
        				neighbor_cnt_next = neighbor_cnt + 1'b1;
        				wr_en_next        =                1'b0;
        				c_cell_x_next     =            c_cell_x;
        				c_cell_y_next     =            c_cell_y;
        				enable_next       =              enable;
    
        		    end
    			4:	begin  //0 0
		                rd_addr_x_next    =            c_cell_x;
        				rd_addr_y_next    =            c_cell_y;
        				neighbor_cnt_next = neighbor_cnt + 1'b1;
        				wr_en_next        =                1'b0;
        				c_cell_x_next     =            c_cell_x;
        				c_cell_y_next     =            c_cell_y;
        				enable_next       =              enable;
    
        		    end        		    
        		5:	begin //0 -1 
        				if (left_edge) begin
		                    rd_addr_x_next    =            c_cell_x;
        				    rd_addr_y_next    =            c_cell_y;
        				    neighbor_cnt_next = neighbor_cnt + 1'b1;
        				    wr_en_next        =                1'b0;
        				    c_cell_x_next     =            c_cell_x;
        				    c_cell_y_next     =            c_cell_y;
        				    enable_next       =              enable;

        				end else begin
		                    rd_addr_x_next    =               2'bxx;
        				    rd_addr_y_next    = ( c_cell_y == Y_MAX ) ? Y_ZERO : c_cell_y + 1'b1;
        				    neighbor_cnt_next = neighbor_cnt + 1'b1;
        				    wr_en_next        =                1'b0;
        				    c_cell_x_next     =            c_cell_x;
        				    c_cell_y_next     =            c_cell_y;
        				    enable_next       =              enable;
        				end	
        				
        			end
        		6:	begin // 0 -1

        				
        			if(left_edge) begin
                            rd_addr_x_next    =             (c_cell_x == X_ZERO) ? X_MAX : c_cell_x + 10'b1111111111;
        				    rd_addr_y_next    = ( c_cell_y == Y_MAX ) ? Y_ZERO : c_cell_y + 1'b1;
        				    neighbor_cnt_next = neighbor_cnt + 1'b1;
        				    wr_en_next        =                1'b0;
        				    c_cell_x_next     =            c_cell_x;
        				    c_cell_y_next     =            c_cell_y;
        				    enable_next       =              enable;

        			end else begin
                            rd_addr_x_next    =            (c_cell_x == X_ZERO) ? X_MAX : c_cell_x + 10'b1111111111;
        				    rd_addr_y_next    =            ( c_cell_y == Y_MAX ) ? Y_ZERO : c_cell_y + 1'b1;
        				    neighbor_cnt_next =                4'b0;
        				    wr_en_next        =                1'b1;
        				    c_cell_x_next     = (c_cell_x == X_MAX) ? X_ZERO : c_cell_x + 1'b1;
        				    c_cell_y_next     = (c_cell_x == X_MAX) ? ( (c_cell_y < Y_MAX)    ? (c_cell_y + 1'b1) : Y_ZERO) : c_cell_y;
        				    enable_next       = ((c_cell_x == X_MAX) && (c_cell_y == Y_MAX) ) ? 1'b0 : enable;
                     end
 
        			end
        		7:	begin //-1 +1
                        rd_addr_x_next    = (c_cell_x == X_ZERO) ? X_MAX : c_cell_x + 10'b1111111111;
        				rd_addr_y_next    =            c_cell_y;
        				neighbor_cnt_next = neighbor_cnt + 1'b1;
        				wr_en_next        =                1'b0;
        				c_cell_x_next     =            c_cell_x;
        				c_cell_y_next     =            c_cell_y;
        				enable_next       =              enable;
        		    end
        		8:	begin //-1 0
                        rd_addr_x_next    = (c_cell_x == X_ZERO) ? X_MAX : c_cell_x + 10'b1111111111;
        				rd_addr_y_next    =  ( c_cell_y == Y_ZERO ) ? Y_MAX : c_cell_y + 9'b111111111;
        				neighbor_cnt_next = neighbor_cnt + 1'b1;
        				wr_en_next        =                1'b0;
        				c_cell_x_next     =            c_cell_x;
        				c_cell_y_next     =            c_cell_y;
        				enable_next       =              enable;
        			end
        		9:	begin //-1 -1
                        rd_addr_x_next    = (c_cell_x == X_ZERO) ? X_MAX : c_cell_x + 10'b1111111111;
        				rd_addr_y_next    = ( c_cell_y == Y_ZERO ) ? Y_MAX : c_cell_y + 9'b111111111;
        				neighbor_cnt_next = neighbor_cnt + 1'b1;
        				wr_en_next        =                1'b0;
        				c_cell_x_next     =            c_cell_x;
        				c_cell_y_next     =            c_cell_y;
        				enable_next       =              enable;
        		    end
        		10:	begin //idle
                        rd_addr_x_next    =      (c_cell_x == X_ZERO) ? X_MAX : c_cell_x + 10'b1111111111;
        				rd_addr_y_next    =        ( c_cell_y == Y_ZERO ) ? Y_MAX : c_cell_y + 9'b111111111;
        				neighbor_cnt_next = neighbor_cnt + 1'b1;
        				wr_en_next        =                1'b0;
        				c_cell_x_next     =            c_cell_x;
        				c_cell_y_next     =            c_cell_y;
        				enable_next       =              enable;

        		    end                
        		11:	begin //write 
                        rd_addr_x_next    =        (c_cell_x == X_ZERO) ? X_MAX : c_cell_x + 10'b1111111111;
        				rd_addr_y_next    =        ( c_cell_y == Y_ZERO ) ? Y_MAX : c_cell_y + 9'b111111111;
        				neighbor_cnt_next =                4'b0;
        				wr_en_next        =                1'b1;
        				c_cell_x_next     = (c_cell_x == X_MAX) ? X_ZERO : c_cell_x + 1'b1;
        				c_cell_y_next     = (c_cell_x == X_MAX) ? ( (c_cell_y < Y_MAX) ? (c_cell_y + 1'b1) : Y_ZERO) : c_cell_y;
        				enable_next       =  ((c_cell_x == X_MAX) && (c_cell_y == Y_MAX) ) ? 1'b0 : enable;
                     
        		    end
        		default:
                    begin
                        rd_addr_x_next    =      10'bxxxxxxxxxx;
        				rd_addr_y_next    =        9'bxxxxxxxxx;
        				neighbor_cnt_next =             4'bxxxx;
        				wr_en_next        =                1'b0;
        				c_cell_x_next     =      10'bxxxxxxxxxx;
        				c_cell_y_next     =        9'bxxxxxxxxx;
        				enable_next       =  ((c_cell_x == X_MAX) && (c_cell_y == Y_MAX) ) ? 1'b0 : enable;
                     
        			
        			end
        	endcase
        end   
    endmodule