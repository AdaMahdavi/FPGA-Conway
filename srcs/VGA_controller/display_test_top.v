`timescale 1ns / 1ps


///--- a temporary top-level wrapper to verify vga controller

module display_test_top(

    input  wire         clk,
    input  wire      areset,
    input  wire [1:0]  mode,
    output wire       hsync,
    output wire       vsync,
    output wire [3:0]   red,
    output wire [3:0] green,
    output wire [3:0]  blue
    
);
    
wire vga_clk, draw_pixel;
wire [9:0] xpixel;
wire [8:0] ypixel;


clk_wiz_0 clock_(

    .clk_in1           (clk), 
    .reset          (areset), 
    .clk_out1      (vga_clk)
 
);

//--- VGA controller DUT
VGA_Block VGA_DUT(
    
    .vga_clk       (vga_clk),
    .areset         (areset),
    .xpixel         (xpixel), 
    .ypixel         (ypixel), 
    .draw_pixel (draw_pixel), 
    .h_sync          (hsync), 
    .v_sync          (vsync)
    
);
    
//--- generates different test patterns 
display_gen display_mode (

    .clk          (vga_clk), 
    .mode            (mode), 
    .red              (red), 
    .green          (green), 
    .blue            (blue), 
    .frame_en  (draw_pixel), 
    .xpixel        (xpixel), 
    .ypixel        (ypixel)
    
);
    
endmodule
