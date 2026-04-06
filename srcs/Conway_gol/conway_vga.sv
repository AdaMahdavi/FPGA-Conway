`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/15/2026 11:23:26 AM
// Design Name: 
// Module Name: control_conway

//////////////////////////////////////////////////////////////////////////////////

// so what if THIS is the module that controls vga reads? 
//we have this vram that's loaded with initial state that we're gonna read, 
//to map it with the vga controller, the flow would be something like: if (frame_en) vga_o <= cell [addr_y][addr_x];
//this also adds an extra latency cycle which may solve the previous issue with star frame 
//vga says: hey! I'm in frame and I want to start reading cells *now*, bram copy then starts the read, this time, outputting results not to a bram,
//-but vga display itself! It now has everything it needs, an address, cell_status (alive_dead), and frame_en!


//so ideally the control unit doesn't need to handle much (truthfully, perhaps nothing at all) on memory side, 
//it just requests the cell vga_control has just gave the address of, and, requests it. Vram instance of bram_copy then handles 
//reliable transmission between VRAM and this unit. 

//an important point of ambiguity: should start pulse be just frame_en? 

//another important point of ambiguity: what's the start pulse for other brams? 


module control_conway(
    input  wire            clk, areset, 
    input  wire                data_in,
    output wire [9:0]        rd_addr_x,
    output wire [8:0]        rd_addr_y,
    output reg             transfer_en,
    output reg                 game_en,

    output wire         h_sync, v_sync,

    output reg [3:0] red, green, blue

    );
    
    wire [9:0] addr_x;
    wire [8:0] addr_y;
    wire pixel_en;
    assign rd_addr_x = addr_x;
    assign rd_addr_y = addr_y;
   

//checker is a sv keyword, interesting!

//    assign red   = (game_en) ? ( (data_in) ? {4{1'b1}} : 4'b0 ) : 4'b0;
//    assign blue  = (game_en) ? ( (data_in) ? {4{1'b1}} : 4'b0 ) : 4'b0;
//    assign green = (game_en) ? ( (data_in) ? {4{1'b1}} : 4'b0 ) : 4'b0;
//assign red   = 4'hF;
//assign green = 4'h0;
//assign blue  = 4'h0;s



//always @(posedge clk) begin
//    if (pixel_en) begin
//        game_en     <=     ((addr_x == 10'b0) && (addr_y == 9'b0 ))? 1'b1   : 1'b0;
//        transfer_en <=     ((addr_x == 10'b0) && (addr_y == 9'd430 ))? 1'b1 : 1'b0;
        
//        red   <= (data_in) ? {4{1'b1}} : 4'b0;
//        blue  <= (data_in) ? {4{1'b1}} : 4'b0;
//        green <= (data_in) ? {4{1'b1}} : 4'b0;

 

        
//    end else begin
//        game_en     <=     1'b0;
//        transfer_en <=     1'b0;
        

//        red   <=  4'b0;
//        blue  <=  4'b0;
//        green <=  4'b0;

        
//    end
//end
   
    



always_comb begin
    if (pixel_en) begin
        game_en     =     ((addr_x == 10'b0) && (addr_y == 9'b0 ))? 1'b1   : 1'b0;
        transfer_en =     ((addr_x == 10'b0) && (addr_y == 9'd430 ))? 1'b1 : 1'b0;
        
        red   = (data_in) ? {4{1'b1}} : 4'b0;
        blue  = (data_in) ? {4{1'b1}} : 4'b0;
        green = (data_in) ? {4{1'b1}} : 4'b0;

 

        
    end else begin
        game_en     =     1'b0;
        transfer_en =     1'b0;
        

        red   =  4'b0;
        blue  =  4'b0;
        green =  4'b0;

        
    end
end
   
 
    VGA_Block VGA (

       .vga_clk         (clk),
       .areset       (areset),
       .xpixel       (addr_x),
       .ypixel       (addr_y),
       .draw_pixel (pixel_en),
       .h_sync       (h_sync),
       .v_sync       (v_sync)

    );
    
endmodule






