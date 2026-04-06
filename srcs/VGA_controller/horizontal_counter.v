`default_nettype none

module horizontal_counter #(

    parameter HORIZ_RES = 800 - 1
    
)(

    input  wire   vga_clk,
    input  wire    areset,

    //--- horizontal counter: 0 to 799
    output reg [($clog2(HORIZ_RES))-1 : 0] h_cnt, 
    
    //--- end of horizontal line
    output wire     eol_h 
    
);

always @(posedge vga_clk or posedge areset) begin

    if (areset) begin
        h_cnt <= 0;
        
    end else begin
    
        if (h_cnt == HORIZ_RES) begin
            h_cnt <= 0;
        end else begin
            h_cnt <= h_cnt + 1'b1;
        end
    end
end

assign eol_h = (h_cnt == HORIZ_RES);
endmodule