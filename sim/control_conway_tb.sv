`timescale 1ns / 1ps
`default_nettype none


//--- DUT is the vga controller which also controls main control signals of the architecture. 
//--- Game logic was debugged and verified here.


module tb_conway_top;


    reg clk_150 = 0;
    reg clk_25  = 0;
    reg      areset;

    always #3.333 clk_150 = ~clk_150;   //--- 150 MHz
    always #20    clk_25  =  ~clk_25;   //---  25 MHz

    //--- VGA 
    wire            hsync, vsync;
    wire [3:0]  red, green, blue;

    //--- Internal wires
    wire [9:0]  copy_rd_x,  copy_wr_x;
    wire [8:0]  copy_rd_y,  copy_wr_y;
    wire        copy_rd_data, copy_wr_data, copy_wr_en;

    wire [9:0]  game_rd_x,  game_wr_x;
    wire [8:0]  game_rd_y,  game_wr_y;
    wire        game_rd_data, game_wr_data, game_wr_en;

    wire [9:0]    vga_rd_x;
    wire [8:0]    vga_rd_y;
    wire       vga_rd_data;

    wire  copy_start, game_start;

    // ── Submodule instantiation (same as conway_top, minus clk_wiz) ──────────
    control_conway control_conway_dut (
        .clk             (clk_25),
        .areset          (areset),
        .data_in    (vga_rd_data),
        .rd_addr_x     (vga_rd_x),
        .rd_addr_y     (vga_rd_y),
        .transfer_en (copy_start),
        .game_en     (game_start),
        .h_sync           (hsync),
        .v_sync           (vsync),
        .red                (red),
        .green            (green),
        .blue              (blue)
    );

    dp_bram vga_bram (
        .clk            (clk_150),
        .we          (copy_wr_en),
        .wr_x         (copy_wr_x),
        .wr_y         (copy_wr_y),
        .wr_data   (copy_wr_data),
        .rd_x          (vga_rd_x),
        .rd_y          (vga_rd_y),
        .rd_data    (vga_rd_data)
    );

    dp_bram current_st_bram (
        .clk            (clk_150),
        .we          (copy_wr_en),
        .wr_x         (copy_wr_x),
        .wr_y         (copy_wr_y),
        .wr_data   (copy_wr_data),
        .rd_x         (game_rd_x),
        .rd_y         (game_rd_y),
        .rd_data   (game_rd_data)
    );

    dp_bram next_st_bram (
        .clk            (clk_150),
        .we          (game_wr_en),
        .wr_x         (game_wr_x),
        .wr_y         (game_wr_y),
        .wr_data   (game_wr_data),
        .rd_x         (copy_rd_x),
        .rd_y         (copy_rd_y),
        .rd_data   (copy_rd_data)
    );

    conway_logic conway_logic (
        .start       (game_start),
        .clk            (clk_150),
        .areset          (areset),
        .rd_data   (game_rd_data),
        .rd_addr_x    (game_rd_x),
        .rd_addr_y    (game_rd_y),
        .wr_data   (game_wr_data),
        .wr_en       (game_wr_en),
        .wr_addr_x    (game_wr_x),
        .wr_addr_y    (game_wr_y)
    );

    copy_bram mid_game_transfer (
        .clk            (clk_150),
        .areset          (areset),
        .start       (copy_start),
        .data_in   (copy_rd_data),
        .rd_addr_x    (copy_rd_x),
        .rd_addr_y    (copy_rd_y),
        .wr_addr_x    (copy_wr_x),
        .wr_addr_y    (copy_wr_y),
        .wr_en       (copy_wr_en),
        .data_out  (copy_wr_data)
    );

    //--- Waveform dump      //best testbench syntax does not exi-
    initial begin
        $dumpfile("conway_top.vcd");
        $dumpvars(0, tb_conway_top);
    end


    // --- Log 
    integer log;
    integer game_wr_count   = 0;
    integer copy_wr_count   = 0;
    integer vga_pixel_count = 0;
    integer frame_count     = 0;

    reg game_start_prev, copy_start_prev, vsync_prev;
    reg [9:0] prev_game_rd_x;
    reg [8:0] prev_game_rd_y;

    // --- stimulus 
    initial begin
        log    = $fopen("conway_probe.log", "w");
        areset = 1;

        $fdisplay(log, "================================================================================");
        $fdisplay(log, "CONWAY TOP - GAME LOGIC vs VGA PROBE LOG");
        $fdisplay(log, "clk_150=150MHz (game+copy)  clk_25=25MHz (VGA)");
        $fdisplay(log, "================================================================================");

        //--- Hold reset for 20 clk_150 cycles - both clocks already running cleanly
        repeat(20) @(posedge clk_150);
        areset = 0;
        $fdisplay(log, "%0t | RESET released", $time);

        //--- 1 full frame = 800*525*40ns = 16,800,000ns
        //--- 3 frames gives enough data to see game→copy→display cycle
        #50_000_000;

        $fdisplay(log, "");
        $fdisplay(log, "================================================================================");
        $fdisplay(log, "SUMMARY");
        $fdisplay(log, "  Frames completed     : %0d", frame_count);
        $fdisplay(log, "  next_st_bram writes  : %0d  (expect 307200/frame = %0d)",
                       game_wr_count, frame_count * 307200);
        $fdisplay(log, "  vga_bram writes(copy): %0d  (expect 307200/frame = %0d)",
                       copy_wr_count, frame_count * 307200);
        $fdisplay(log, "  VGA active pixels    : %0d  (expect 307200/frame = %0d)",
                       vga_pixel_count, frame_count * 307200);
        $fdisplay(log, "================================================================================");
        $fclose(log);
        $finish;
    end

    //--- vsync frame counter (25 MHz) 
    always @(posedge clk_25) begin
        vsync_prev <= vsync;
        if (!vsync && vsync_prev) begin
            frame_count = frame_count + 1;
            $fdisplay(log, "%0t | VSYNC #%0d (frame boundary)", $time, frame_count);
        end
    end

    //--- game_start/copy_start edge log
    always @(posedge clk_25) begin
        game_start_prev <= game_start;
        copy_start_prev <= copy_start;
        if ( game_start && !game_start_prev)
            $fdisplay(log, "%0t | GAME_START  asserted  - conway_logic computing next state", $time);
        if (!game_start &&  game_start_prev)
            $fdisplay(log, "%0t | GAME_START  deasserted", $time);
        if ( copy_start && !copy_start_prev)
            $fdisplay(log, "%0t | COPY_START  asserted  - copy_bram transferring next->vga", $time);
        if (!copy_start &&  copy_start_prev)
            $fdisplay(log, "%0t | COPY_START  deasserted", $time);
    end

    //--- next_st_bram write monitor
    always @(posedge clk_150) begin
        if (game_wr_en) begin
            game_wr_count = game_wr_count + 1;
            if (game_wr_x >= 640 || game_wr_y >= 480)
                $fdisplay(log, "%0t | !! GAME WR OUT-OF-BOUNDS x=%0d y=%0d data=%b",
                    $time, game_wr_x, game_wr_y, game_wr_data);
            if (game_wr_count <= 10 ||
                game_wr_y == 0 || game_wr_y == 479 ||
                game_wr_x == 0 || game_wr_x == 639)
                $fdisplay(log, "%0t | GAME_WR  {9'd%0d,10'd%0d} addr=0x%05X  data=%b  (#%0d)",
                    $time, game_wr_y, game_wr_x,
                    (game_wr_y * 1024 + game_wr_x),
                    game_wr_data, game_wr_count);
        end
    end

    //--- game_rd monitor -? edge/corner addresses only (150 MHz)
    always @(posedge clk_150) begin
        if (game_rd_x != prev_game_rd_x || game_rd_y != prev_game_rd_y) begin
            prev_game_rd_x <= game_rd_x;
            prev_game_rd_y <= game_rd_y;
            if (game_rd_y == 0 || game_rd_y == 479 ||
                game_rd_x == 0 || game_rd_x == 639)
                $fdisplay(log, "%0t | GAME_RD   {9'd%0d,10'd%0d} addr=0x%05X  data=%b",
                    $time, game_rd_y, game_rd_x,
                    (game_rd_y * 1024 + game_rd_x),
                    game_rd_data);
        end
    end

    //--- VGA pixel monitor 
    wire pixel_active = (red != 0 || green != 0 || blue != 0);
    always @(posedge clk_25) begin
        if (pixel_active) begin
            vga_pixel_count = vga_pixel_count + 1;
            if (vga_pixel_count <= 10 ||
                vga_rd_y == 0 || vga_rd_y == 479 ||
                vga_rd_x == 0 || vga_rd_x == 639)
                $fdisplay(log, "%0t | VGA_PIXEL {9'd%0d,10'd%0d} addr=0x%05X  data=%b  RGB=%h%h%h",
                    $time, vga_rd_y, vga_rd_x,
                    (vga_rd_y * 1024 + vga_rd_x),
                    vga_rd_data, red, green, blue);
        end
    end

    //--- copy_bram write monitor
    always @(posedge clk_150) begin
        if (copy_wr_en) begin
            copy_wr_count = copy_wr_count + 1;
            if (copy_wr_count <= 10 ||
                copy_wr_y == 0 || copy_wr_y == 479 ||
                copy_wr_x == 0 || copy_wr_x == 639)
                $fdisplay(log, "%0t | COPY_WR   {9'd%0d,10'd%0d} addr=0x%05X  data=%b  (#%0d)",
                    $time, copy_wr_y, copy_wr_x,
                    (copy_wr_y * 1024 + copy_wr_x),
                    copy_wr_data, copy_wr_count);
        end
    end

    //--- spot-check: game write to (0,0) vs VGA position
    always @(posedge clk_150) begin
        if (game_wr_en && game_wr_x == 0 && game_wr_y == 0)
            $fdisplay(log,
                "%0t | SPOT(0,0): game_wr=%b | VGA at {%0d,%0d} data=%b hsync=%b vsync=%b",
                $time, game_wr_data,
                vga_rd_y, vga_rd_x, vga_rd_data, hsync, vsync);
    end

endmodule