`timescale 1ns / 1ps

//--- Top-level VGA timing block. Generates h_sync, v_sync, and pixel
//--- coordinates by composing horizontal/vertical counters and sync generators.


module VGA_Block #(

    parameter VD   = 480,            //--- vertical  display area 
    parameter V_BP =  33,            //--- vertical    back porch 
    parameter V_FP =  10,            //--- vertical   front porch
    parameter VR   =   2,            //--- vertical       retrace

    parameter HD   = 640,            //--- horizontal     display
    parameter H_BP =  48,            //--- horizontal  back porch 
    parameter H_FP =  16,            //--- horizontal front porch 
    parameter HR   =  96,            //--- horizontal     retrace

    parameter LINE_LIMIT  = 800,
    parameter FRAME_LIMIT = 525

)(
    input wire vga_clk,
    input wire  areset,

    output wire [$clog2(LINE_LIMIT) -1:0] xpixel,
    output wire [$clog2(FRAME_LIMIT)-2:0] ypixel,

    output wire draw_pixel,

    output wire h_sync,
    output wire v_sync

);

    wire  eol_horiz;      //--- end of horizontal line

    wire [$clog2(LINE_LIMIT) -1:0] h_cnt;
    wire [$clog2(FRAME_LIMIT)-1:0] v_cnt;


///--- counts left to right along frame lines, 0 to 799
    horizontal_counter #(

        .HORIZ_RES (LINE_LIMIT-1)

    ) hcounter_inst (

        .vga_clk       (vga_clk),
        .areset         (areset), 
        .h_cnt           (h_cnt),
        .eol_h       (eol_horiz)
        );
        
///--- signals hsync to return pointer to start of line
    hsync_generator #(
        
        .HD         (HD), 
        .H_FP     (H_FP), 
        .H_BP     (H_BP),
        .HR         (HR)
        
    ) hsync_inst (
        .h_cnt   (h_cnt),
        .h_sync (h_sync)
    );
            
///--- increments before starting a new line, top to the bottom of frame. 0 to 524
    vertical_counter #(

        .VERT_RES (FRAME_LIMIT-1)

    ) vcounter_inst (

        .vga_clk        (vga_clk),
        .areset          (areset), 
        .eol_horiz    (eol_horiz),
        .v_cnt            (v_cnt)
    );


///--- signals vsync to return pointer to top of the screen 

    vsync_generator #(

        .VD         (VD),
        .V_FP     (V_FP),
        .VR         (VR),
        .V_BP     (V_BP)

    ) vsync_inst (
        .v_cnt   (v_cnt),
        .v_sync (v_sync)
    );

///--- signaling draw_pixel while in vga display area
    xypixel_generator #(

        .HPIXEL              (HD),
        .VPIXEL              (VD),
        .LINE_LIMIT  (LINE_LIMIT),
        .FRAME_LIMIT(FRAME_LIMIT)

    ) pixelgen_inst (
        .h_cnt            (h_cnt),
        .v_cnt            (v_cnt),
        .draw_pixel  (draw_pixel),
        .xpixel          (xpixel),
        .ypixel          (ypixel)
    );

endmodule