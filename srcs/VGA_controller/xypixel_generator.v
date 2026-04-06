`timescale 1ns/1ps

module xypixel_generator #(

    parameter HPIXEL      = 640,
    parameter VPIXEL      = 480,
    parameter LINE_LIMIT  = 800,
    parameter FRAME_LIMIT = 525

)(  
    input  wire [$clog2(LINE_LIMIT)-1 :0] h_cnt,
    input  wire [$clog2(FRAME_LIMIT)-1:0] v_cnt,

    output wire draw_pixel,

    output wire [$clog2(LINE_LIMIT)-1 :0] xpixel,
    output wire [$clog2(FRAME_LIMIT)-1:0] ypixel

);

//---we only draw if pixel falls within display range (640x480)

assign draw_pixel = ((h_cnt < HPIXEL) && (v_cnt < VPIXEL));


assign xpixel = (draw_pixel)? h_cnt : 0;
assign ypixel = (draw_pixel)? v_cnt : 0;

endmodule