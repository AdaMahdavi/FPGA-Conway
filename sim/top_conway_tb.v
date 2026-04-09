//--- a high level testbench to check if system's end-to-end datapath exists or not (before proceeding with lower-level debugs)

`timescale 1ns / 1ps
module tb_conway_top;

    reg   clk     =  0;
    reg   areset  =  1;

    wire         hsync;
    wire         vsync;

    wire [3:0] red, green, blue;


    //--- 150mhz
    always #3.3 clk = ~clk;

    //while conway_top includes a clocking wiz ip, simulation wouldn't run. 
    //to launch this testbench, you should proceed as the following: 
    // - remove clocking wizard ip from conway_top_wrapper entirely;
    // - use a clk divider to derive a 25mhz clock from the 150mhz input
    // wire it to clk_25


    conway_top dut (
        .clk       (clk),
        .areset (areset),
        .hsync   (hsync),
        .vsync   (vsync),
        .red       (red),
        .green   (green),
        .blue     (blue)
    );

    initial begin
        repeat(4) @(posedge clk);
        areset = 0;
    end

    initial begin
        $dumpfile("tb_conway_top.vcd");
        $dumpvars(0, tb_conway_top);

        @(negedge areset);

        repeat(10) begin
            @(posedge dut.copy_start);
            $display("t=%0t  copy_start HIGH", $time);

            @(posedge dut.game_start);
            $display("t=%0t  game_start HIGH", $time);

            @(posedge dut.copy_wr_en);
            $display("t=%0t  copy_wr_en HIGH -> copy_bram started", $time);

            @(posedge dut.game_wr_en);
            $display("t=%0t  game_wr_en HIGH -> conway_logic started writing", $time);

            $display("--- frame done ---");
        end

        $finish;
    end

    // timeout after 3 full frames
    initial begin
        #(800*525*3*7);
        $display("TIMEOUT : pipeline never fired:");
        $display("  copy_start=%b game_start=%b copy_wr_en=%b game_wr_en=%b",
            dut.copy_start, dut.game_start, dut.copy_wr_en, dut.game_wr_en);
        $finish;
    end

endmodule
