`timescale 1ns / 1ps
`default_nettype none

//--- I was having far too many issues with memory configuration before switching to memory ip, 
//--- This tb was solely used to see what could be read from bram. 

//--- overall a pretty simple testbench... more observation-centered than verification-centered.


module tb_dp_bram;

    reg       clk  =     0;
    reg      [9:0]    rd_x;
    reg      [8:0]    rd_y;

    wire           rd_data;


    //--- clk gen: 100MHz
    always #5 clk  =  ~clk;

    dp_bram dut (
        .clk         (clk), 
        .we            (0),
        .wr_x          (0), 
        .wr_y          (0), 
        .wr_data       (0),
        .rd_x       (rd_x), 
        .rd_y       (rd_y),
        .rd_data (rd_data)
    );

    initial begin
        //--- let init settle
        repeat(5) @(posedge clk);

        rd_x =  1;   rd_y = 0; 
        @(posedge clk); 
        @(posedge clk);
        $display("pixel(  0,  0) = %b", rd_data);

        rd_x = 10;  rd_y = 10; 
        @(posedge clk); 
        @(posedge clk);
        $display("pixel( 10, 10) = %b", rd_data);


        rd_x = 6;  rd_y = 470; 
        @(posedge clk); 
        @(posedge clk);
        $display("pixel(6,  470) = %b", rd_data);
        

        rd_x = 639;  rd_y = 4; 
        @(posedge clk); 
        @(posedge clk);
        $display("pixel(639,  4) = %b", rd_data);

        rd_x = 512;rd_y = 360; 
        @(posedge clk); 
        @(posedge clk);
        $display("pixel(512,360) = %b", rd_data);

        $finish;
    end

endmodule