`timescale 1ns/1ps

module vsync_generator #(

    parameter VD   = 480,      //--- vertical display area
    parameter V_BP =  33,      //--- vertical   back porch 
    parameter V_FP =  10,      //--- vertical  front porch
    parameter VR   =   2       //--- vertical      retrace 
)(

    input wire [$clog2(VD + V_BP + V_FP + VR)-1: 0] v_cnt,

    output wire v_sync

);

  /*--- v_sync pulses high for VR lines after the vertical front porch (VD + V_FP),
    signalling the display to reset its scan back to the top of the frame */

    assign v_sync = ((v_cnt >= VD + V_FP) && (v_cnt <= VD + VR + V_FP - 1));


endmodule