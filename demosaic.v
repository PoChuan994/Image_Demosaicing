module demosaic(clk, reset, in_en, data_in, wr_r, addr_r, wdata_r, rdata_r, wr_g, addr_g, wdata_g, rdata_g, wr_b, addr_b, wdata_b, rdata_b, done);
input clk;
input reset;
input in_en;
input [7:0] data_in;
output reg wr_r;
output reg [13:0] addr_r;
output reg [7:0] wdata_r;
input [7:0] rdata_r;
output reg wr_g;
output reg [13:0] addr_g;
output reg [7:0] wdata_g;
input [7:0] rdata_g;
output reg wr_b;
output reg [13:0] addr_b;
output reg [7:0] wdata_b;
input [7:0] rdata_b;
output reg done;

// --------------------------------
parameter [3:0] GETDATA = 'd0,
                SETTING = 'd1,
                RESET = 'd2,
                GREEN_BLOCK1_GETDATA = 'd3,
                GREEN_BLOCK2_GETDATA = 'd4,
                RED_BLOCK_GETDATA = 'd5,
                BLUE_BLOCK_GETDATA = 'd6,
                WRITE_MEMORY = 'd7,
                RESULT = 'd8;

reg [3:0] state, nextstate;
reg [13:0] center;  // coordinate
reg [2:0] counter;  // counter for bilinear interpolation

wire [6:0] cx_add1, cx_minus1, cy_add1, cy_minus1;
assign cx_add1 =  center[6:0] + 7'd1;
assign cx_minus1 =  center[6:0] - 7'd1;
assign cy_add1 =  center[13:7] + 7'd1;
assign cy_minus1 =  center[13:7] - 7'd1;

// save RGB temporary value
reg [15:0] r_tmp, g_tmp, b_tmp;

// next state logic
always @(*) begin
    case (state)
        GETDATA: nextstate = (center==16383)? SETTING : GETDATA;
        SETTING: nextstate = RESET;
        RESET:begin
            case ({center[7],center[0]})
                'b00: nextstate = GREEN_BLOCK1_GETDATA;
                'b11: nextstate = GREEN_BLOCK2_GETDATA;
                'b01: nextstate = RED_BLOCK_GETDATA;
                'b10: nextstate = BLUE_BLOCK_GETDATA;
                default: nextstate = GREEN_BLOCK1_GETDATA;
            endcase
        end
        GREEN_BLOCK1_GETDATA: nextstate = (counter<='d1)? GREEN_BLOCK1_GETDATA : WRITE_MEMORY;
        GREEN_BLOCK2_GETDATA: nextstate = (counter<='d1)? GREEN_BLOCK2_GETDATA : WRITE_MEMORY;
        RED_BLOCK_GETDATA: nextstate = (counter<='d3)? RED_BLOCK_GETDATA : WRITE_MEMORY;
        BLUE_BLOCK_GETDATA: nextstate = (counter<='d3)? BLUE_BLOCK_GETDATA : WRITE_MEMORY;
        WRITE_MEMORY: nextstate = (center<='d16253)? RESET : RESULT;
        RESULT: nextstate = RESULT;
        default: nextstate = GETDATA;
    endcase
end

// state control
always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= GETDATA;
    end else begin
        state <= nextstate;
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        wr_r <= 0;
        wr_g <= 0;
        wr_b <= 0;
        addr_r <= 0;
        addr_g <= 0;
        addr_b <= 0;
        wdata_r <= 0;
        wdata_g <= 0;
        wdata_b <= 0;
        center <= 0;
        // test
        done <= 0;
    end else begin
        case (state)
            GETDATA: begin
                if (in_en) begin
                    center <= center + 1;
                    case ({center[7],center[0]})
                        // green case
                        'b00, 'b11: begin
                            wr_r <= 0;
                            wr_g <= 1;
                            wr_b <= 0;
                            addr_g <= center;
                            wdata_g <= data_in;
                        end
                        // red case
                        'b01: begin
                            wr_r <= 1;
                            wr_g <= 0;
                            wr_b <= 0;
                            addr_r <= center;
                            wdata_r <= data_in;
                        end
                        // blue case
                        'b10: begin
                            wr_r <= 0;
                            wr_g <= 0;
                            wr_b <= 1;
                            addr_b <= center;
                            wdata_b <= data_in;
                        end
                    endcase
                end
            end
            SETTING: center <= 129;
            RESET: begin
                r_tmp <= 0;
                g_tmp <= 0;
                b_tmp <= 0;
                counter <= 0;
                wr_r <= 0;
                wr_g <= 0;
                wr_b <= 0;
            end
            GREEN_BLOCK1_GETDATA: begin
                counter <= counter + 1;
                // calculate red/blue memory address
                if (counter<=1) begin
                    case (counter)
                        'd0: begin
                            addr_r <= {center[13:7], cx_minus1};
                            addr_b <= {cy_minus1, center[6:0]};
                        end
                        'd1: begin
                            addr_r <= {center[13:7], cx_add1};
                            addr_b <= {cy_add1, center[6:0]};
                        end
                    endcase
                end
                // bilinear interpolation
                if (counter>=1) begin
                    r_tmp <= r_tmp + rdata_r;
                    b_tmp <= b_tmp + rdata_b;
                end
            end
            GREEN_BLOCK2_GETDATA: begin
                counter <= counter + 1;
                // calculate red/blue memory address
                if (counter<=1) begin
                    case (counter)
                        'd0: begin
                            addr_r <= {cy_minus1, center[6:0]};
                            addr_b <= {center[13:7], cx_minus1};
                        end
                        'd1: begin
                            addr_r <= {cy_add1, center[6:0]};
                            addr_b <= {center[13:7], cx_add1};
                        end
                    endcase
                end
                // bilinear interpolation
                if (counter>=1) begin
                    r_tmp <= r_tmp + rdata_r;
                    b_tmp <= b_tmp + rdata_b;
                end
            end
            RED_BLOCK_GETDATA: begin
                counter <= counter + 1;
                // calculate green/blue memory a ddress
                if (counter<=3) begin
                    case (counter)
                        'd0: begin
                            addr_g <= {cy_minus1, center[6:0]};
                            addr_b <= {cy_minus1, cx_minus1};                        
                        end
                        'd1: begin
                            addr_g <= {center[13:7], cx_minus1};
                            addr_b <= {cy_minus1, cx_add1};
                        end
                        'd2: begin
                            addr_g <= {center[13:7], cx_add1};
                            addr_b <= {cy_add1, cx_minus1};
                        end
                        'd3: begin
                            addr_g <= {cy_add1, center[6:0]};
                            addr_b <= {cy_add1, cx_add1};
                        end
                    endcase
                end
                // bilinear interpolation
                if(counter>=1) begin
                    g_tmp <= g_tmp + rdata_g;
                    b_tmp <= b_tmp + rdata_b;
                end
            end
            BLUE_BLOCK_GETDATA: begin
                counter <= counter + 1;
                // calculate red/green memory address
                if (counter<=3) begin
                    case (counter)
                        'd0: begin
                            addr_r <= {cy_minus1, cx_minus1};
                            addr_g <= {cy_minus1, center[6:0]};
                        end
                        'd1: begin
                            addr_r <= {cy_minus1, cx_add1};
                            addr_g <= {center[13:7], cx_minus1};
                        end
                        'd2: begin
                            addr_r <= {cy_add1, cx_minus1};
                            addr_g <= {center[13:7], cx_add1};
                        end
                        'd3: begin
                            addr_r <= {cy_add1, cx_add1};
                            addr_g <= {cy_add1, center[6:0]};
                        end
                    endcase
                end
                // bilinear interpolation
                if (counter>=1) begin
                    r_tmp <= rdata_r + r_tmp;
                    g_tmp <= rdata_g + g_tmp;
                end
            end
            WRITE_MEMORY: begin
                if (center[6:0]!=126) begin
                    center <= center + 1;
                end else begin
                    center <= center + 3;
                end
                addr_r <= center;
                addr_g <= center;
                addr_b <= center;
                case ({center[7], center[0]})
                    'b00, 'b11: begin
                        wr_r <= 1;
                        wr_g <= 0;
                        wr_b <= 1;
                        wdata_r <= r_tmp[8:1];
                        wdata_b <= b_tmp[8:1];
                    end
                    'b01: begin
                        wr_r <= 0;
                        wr_g <= 1;
                        wr_b <= 1;
                        wdata_g <= g_tmp[9:2];
                        wdata_b <= b_tmp[9:2];
                    end
                    'b10: begin
                        wr_r <= 1;
                        wr_g <= 1;
                        wr_b <= 0;
                        wdata_r <= r_tmp[9:2];
                        wdata_g <= g_tmp[9:2];
                    end
                endcase
            end
            RESULT: begin
                done <= 1;
            end
        endcase
    end
end

endmodule