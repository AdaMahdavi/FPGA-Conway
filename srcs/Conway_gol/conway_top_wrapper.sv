`timescale 1ns / 1ps


module conway_top(

    input wire           clk,   //need to convert initial 100mhz clk to 150mhz
    input wire        areset,

    output wire        hsync,
    output wire        vsync,

    output wire [3:0]    red,
    output wire [3:0]  green,
    output wire [3:0]   blue

);


    wire clk_150, clk_25;
    
    wire [9:0] copy_rd_x, copy_wr_x;
    wire [8:0] copy_rd_y, copy_wr_y;
    wire copy_rd_data, copy_wr_data, copy_wr_en;
   
    wire [9:0] game_rd_x, game_wr_x;
    wire [8:0] game_rd_y, game_wr_y;
    wire game_rd_data, game_wr_data, game_wr_en;


    wire [9:0] vga_rd_x;
    wire [8:0] vga_rd_y;
    wire    vga_rd_data; 
    
    wire     copy_start;
    wire     game_start;
    


    
       clk_wiz_0 clk_100_2_150_25(

            .clk_in1          (clk), 
            .reset         (areset), 
            .clk_out1     (clk_150),
            .clk_out2      (clk_25)
    
            );
       // ram for the present state data
    
        // The video driver module for the VGA Output


    	control_conway vga_output(		

            .clk            (clk_25),
        	.areset         (areset),
            .data_in   (vga_rd_data),
        	.rd_addr_x    (vga_rd_x),
        	.rd_addr_y    (vga_rd_y), 
        	.transfer_en(copy_start),
        	.game_en    (game_start),
        	.h_sync          (hsync),
    		.v_sync          (vsync),
    		.red               (red),
    		.green           (green),
            .blue             (blue)

        	);

        //
    	dp_bram vga_bram (
            .clk           (clk_150), 
        	.we         (copy_wr_en), 
        	.wr_x        (copy_wr_x),
            .wr_y        (copy_wr_y),
        	.wr_data  (copy_wr_data),
            .rd_x         (vga_rd_x),
            .rd_y         (vga_rd_y),
        	.rd_data   (vga_rd_data)

    		);

    	// Ram for the next state data						
     	dp_bram current_st_bram (	

            .clk           (clk_150), 
        	.we         (copy_wr_en), 
            .wr_x        (copy_wr_x),
        	.wr_y        (copy_wr_y),
        	.wr_data  (copy_wr_data),
        	.rd_x        (game_rd_x),
        	.rd_y        (game_rd_y),
        	.rd_data  (game_rd_data)

        	);

    	// Ram for the video frame buffer
        dp_bram next_st_bram ( 		
             	 
            .clk           (clk_150), 		
            .we         (game_wr_en),                					
            .wr_x        (game_wr_x),			
            .wr_y        (game_wr_y),
            .wr_data  (game_wr_data),
           	.rd_x        (copy_rd_x),
            .rd_y        (copy_rd_y),
          	.rd_data  (copy_rd_data)

        	);

        // Module for calculating the next state of each pixel
        conway_logic conway_logic (

            .start      (game_start),        				 		
            .clk           (clk_150),
            .areset         (areset),
        	.rd_data  (game_rd_data),
        	.rd_addr_x   (game_rd_x),
        	.rd_addr_y   (game_rd_y),
        	.wr_data  (game_wr_data),
        	.wr_en      (game_wr_en),
        	.wr_addr_x   (game_wr_x),
        	.wr_addr_y   (game_wr_y)

        	);

        // memory transfer module
        copy_bram mid_game_transfer (

            .clk           (clk_150),
            .areset         (areset),
        	.start      (copy_start),
        	.data_in  (copy_rd_data),
        	.rd_addr_x   (copy_rd_x),
            .rd_addr_y   (copy_rd_y),
        	.wr_addr_x   (copy_wr_x),
        	.wr_addr_y   (copy_wr_y),
        	.wr_en      (copy_wr_en),
        	.data_out  (copy_wr_data)

        	);
endmodule