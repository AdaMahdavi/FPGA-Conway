`timescale 1ns/1ps

module hsync_generator #(

    parameter HD   = 640,     //--- horizontal display area
    parameter H_BP =  48,     //--- horizontal   back porch
    parameter H_FP =  16,     //--- horizontal  front porch
    parameter HR   =  96      //--- horizontal      retrace 
)(
    input wire [$clog2 (HD + H_BP + H_FP + HR)-1: 0] h_cnt,

    output wire h_sync

);

  /*--- h_sync pulses high for HR lines after the vertical front porch (HD + H_FP),
    signalling the display to reset its beam back to the left of the screen. */

    assign h_sync = ((h_cnt >= HD + H_FP) && (h_cnt <= HD + HR + H_FP - 1));


endmodule