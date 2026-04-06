`timescale 1ns / 1ps



//--- generates different display patterns to test VGA.

module display_gen #(

    parameter T_WIDTH  = 800,
    parameter T_HEIGHT = 525

)(
    input wire          clk,
    input wire     frame_en,
    input wire [1:0]   mode,
        
    input wire [$clog2(T_WIDTH):0]  xpixel,
    input wire [$clog2(T_HEIGHT):0] ypixel,
        
    output reg [3:0]    red,
    output reg [3:0]  green,
    output reg [3:0]   blue

);
    
    parameter BLANK = 0, RNG = 1, SQUARE = 2, GRADIENT = 3;

    reg [15:0] offset, random;
    wire checker;

    wire [9:0] sum = xpixel + offset[15:13];
    assign  checker = sum[5]^ypixel[5];
   
    always @(*) begin

        case (mode) 
        
            BLANK       : begin {red, green, blue} = 12'b0; end
            RNG         : begin {red, green, blue} = (frame_en) ? (random): 12'b0; end
            SQUARE      : begin {red, green, blue} = (frame_en) ? (checker? (12'hFFF): 12'b0) : 12'b0; end
            GRADIENT    : begin if (frame_en) begin red= xpixel[9:6]; green = ypixel[8:5]; blue = xpixel[8:5]; end else {red,green,blue} = 12'b0; end 
        
        endcase
    end


    always @(posedge clk) begin

        offset <= offset + 1'b1;
        random <= {((random >> 0)^(random >>1) ^ (random >>2) ^ (random >> 8) ^ (1'b1)), random[11:1]}; 
    end
endmodule


