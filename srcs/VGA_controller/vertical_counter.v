`default_nettype none

module vertical_counter #(
    parameter VERT_RES = 525 - 1
)(
    input wire vga_clk,
    input wire areset,
    input wire eol_horiz,

    output reg [($clog2(VERT_RES))-1 : 0] v_cnt
    //output wire eof_vert
);

always @(posedge vga_clk or posedge areset) begin
    if (areset) begin
        v_cnt <= 0;
    end else begin
        if (eol_horiz) begin
            if (v_cnt == VERT_RES) begin
                v_cnt <= 0;
            end else begin
                v_cnt <= v_cnt + 1'b1;
            end
            
       end
    end
end

//assign eof_vert = (v_cnt == VERT_RES);
endmodule