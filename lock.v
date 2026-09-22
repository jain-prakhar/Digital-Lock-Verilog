// lock_vga_final.v
// VGA-C + normal font (A) implementation for DE2-115
// Password default: 4 3 2 1
// Entry mode: C1 (SW[3:0] per digit, press KEY[0] to confirm)
// KEY[0]=ENTER, KEY[1]=RESET, KEY[2]=CLEAR (all active-low on board)
// Author: ChatGPT (final deliverable)
// Date: 2025-10-29

`timescale 1ns / 1ps
module lock(
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,     // KEY[0]=ENTER, KEY[1]=RESET, KEY[2]=CLEAR (active-low)
    input  wire [3:0]  SW,      // SW[3:0] = digit input (0..9)
    output wire [9:0]  LEDR,    // LEDR[0]=LOCKED, LEDR[1]=UNLOCKED
    output wire [6:0]  HEX0,
    output wire [6:0]  HEX1,
    output wire [6:0]  HEX2,
    output wire [6:0]  HEX3,
    output wire [6:0]  HEX4,
    output wire [6:0]  HEX5,
    output wire [2:0]  VGA_R,
    output wire [2:0]  VGA_G,
    output wire [1:0]  VGA_B,
    output wire        VGA_HS,
    output wire        VGA_VS
);

    // -----------------------
    // Configurable password (change here)
    // -----------------------
    localparam [3:0] SECRET0 = 4'd4;
    localparam [3:0] SECRET1 = 4'd3;
    localparam [3:0] SECRET2 = 4'd2;
    localparam [3:0] SECRET3 = 4'd1;

    // -----------------------
    // Buttons (active-low on DE2)
    // -----------------------
    wire clk = CLOCK_50;
    wire enter_raw = ~KEY[0]; // internal active-high on press
    wire reset_raw = ~KEY[1];
    wire clear_raw = ~KEY[2];

    // Debounced / pulse signals
    wire enter_db, enter_pulse;
    wire clear_db, clear_pulse;
    wire reset_db, reset_pulse;

    debouncer #(.CLK_FREQ(50000000), .DEB_MS(20)) db_enter (.clk(clk), .reset(reset_raw), .noisy(enter_raw), .clean(enter_db));
    one_pulse op_enter (.clk(clk), .reset(reset_raw), .sig(enter_db), .pulse(enter_pulse));

    debouncer #(.CLK_FREQ(50000000), .DEB_MS(20)) db_clear (.clk(clk), .reset(reset_raw), .noisy(clear_raw), .clean(clear_db));
    one_pulse op_clear (.clk(clk), .reset(reset_raw), .sig(clear_db), .pulse(clear_pulse));

    debouncer #(.CLK_FREQ(50000000), .DEB_MS(20)) db_reset (.clk(clk), .reset(reset_raw), .noisy(reset_raw), .clean(reset_db));
    one_pulse op_reset (.clk(clk), .reset(reset_raw), .sig(reset_db), .pulse(reset_pulse));

    // -----------------------
    // Entry state (C1: single digit per press)
    // -----------------------
    reg [3:0] entered0, entered1, entered2, entered3; // entered0 = newest (first shown)
    reg [1:0] count;   // counts entries already stored: 0..3 (counts previous entries)
    reg locked;        // 1 = locked, 0 = unlocked
    reg show_wrong;    // brief wrong message
    reg [23:0] wrong_cnt;

    integer i;
    always @(posedge clk or posedge reset_raw) begin
        if (reset_raw) begin
            entered0 <= 4'd0; entered1 <= 4'd0; entered2 <= 4'd0; entered3 <= 4'd0;
            count <= 2'd0;
            locked <= 1'b1;
            show_wrong <= 1'b0;
            wrong_cnt <= 24'd0;
        end else begin
            // CLEAR resets entry & lock
            if (clear_pulse) begin
                entered0 <= 4'd0; entered1 <= 4'd0; entered2 <= 4'd0; entered3 <= 4'd0;
                count <= 2'd0;
                locked <= 1'b1;
                show_wrong <= 1'b0;
                wrong_cnt <= 24'd0;
            end else begin
                // On enter_pulse capture digit (C1)
                if (enter_pulse) begin
                    // shift older digits
                    entered3 <= entered2;
                    entered2 <= entered1;
                    entered1 <= entered0;
                    entered0 <= SW & 4'hF;
                    if (count < 2'd3) begin
                        count <= count + 1'b1;
                    end else begin
                        // After the 4th press, check password
                        if ({SW & 4'hF, entered0, entered1, entered2} == {SECRET0, SECRET1, SECRET2, SECRET3}) begin
                            locked <= 1'b0;
                            show_wrong <= 1'b0;
                            wrong_cnt <= 24'd0;
                        end else begin
                            locked <= 1'b1;
                            show_wrong <= 1'b1;
                            wrong_cnt <= 24'd1; // start
                        end
                        count <= 2'd0;
                        // optionally clear entered regs after attempt (keeps UI clean)
                        entered0 <= 4'd0; entered1 <= 4'd0; entered2 <= 4'd0; entered3 <= 4'd0;
                    end
                end

                // wrong message timing (~0.2s)
                if (show_wrong) begin
                    if (wrong_cnt < 24'd10_000_000) wrong_cnt <= wrong_cnt + 1;
                    else begin
                        show_wrong <= 1'b0;
                        wrong_cnt <= 24'd0;
                    end
                end
            end
        end
    end

    // LED mapping
    assign LEDR[0] = locked;
    assign LEDR[1] = ~locked;
    assign LEDR[9:2] = 8'b0;

    // -----------------------
    // HEX displays (visible digits E2)
    // active-low segment map + mirror fix (DE2 physical orientation)
    // -----------------------
    function [6:0] seg7;
        input [3:0] d;
        begin
            case(d)
                4'd0: seg7 = 7'b1000000;
                4'd1: seg7 = 7'b1111001;
                4'd2: seg7 = 7'b0100100;
                4'd3: seg7 = 7'b0110000;
                4'd4: seg7 = 7'b0011001;
                4'd5: seg7 = 7'b0010010;
                4'd6: seg7 = 7'b0000010;
                4'd7: seg7 = 7'b1111000;
                4'd8: seg7 = 7'b0000000;
                4'd9: seg7 = 7'b0010000;
                default: seg7 = 7'b1111111;
            endcase
        end
    endfunction

    function [6:0] flip7;
        input [6:0] s;
        begin
            flip7 = { s[6], s[4], s[5], s[3], s[1], s[2], s[0] };
        end
    endfunction

    assign HEX0 = flip7(seg7(entered0));
    assign HEX1 = flip7(seg7(entered1));
    assign HEX2 = flip7(seg7(entered2));
    assign HEX3 = flip7(seg7(entered3));
    assign HEX4 = 7'b1111111;
    assign HEX5 = 7'b1111111;

    // -----------------------
    // VGA: 640x480 @ 25 MHz pixel clock from 50 MHz input (divide by 2)
    // We'll use a scaled 8x8 font doubled to 16x16 cells (big display)
    // -----------------------
    reg pix; always @(posedge clk) pix <= ~pix; // 50MHz -> 25MHz

    // timing constants
    localparam H_VISIBLE = 640;
    localparam H_FRONT = 16;
    localparam H_SYNC = 96;
    localparam H_BACK = 48;
    localparam H_TOTAL = H_VISIBLE + H_FRONT + H_SYNC + H_BACK; // 800

    localparam V_VISIBLE = 480;
    localparam V_FRONT = 10;
    localparam V_SYNC = 2;
    localparam V_BACK = 33;
    localparam V_TOTAL = V_VISIBLE + V_FRONT + V_SYNC + V_BACK; // 525

    reg [10:0] hcnt;
    reg [9:0] vcnt;

    always @(posedge pix) begin
        if (hcnt == H_TOTAL-1) begin
            hcnt <= 11'd0;
            if (vcnt == V_TOTAL-1) vcnt <= 10'd0;
            else vcnt <= vcnt + 1;
        end else hcnt <= hcnt + 1;
    end

    wire hsync = ~((hcnt >= H_VISIBLE + H_FRONT) && (hcnt < H_VISIBLE + H_FRONT + H_SYNC));
    wire vsync = ~((vcnt >= V_VISIBLE + V_FRONT) && (vcnt < V_VISIBLE + V_FRONT + V_SYNC));
    assign VGA_HS = hsync;
    assign VGA_VS = vsync;

    wire visible = (hcnt < H_VISIBLE) && (vcnt < V_VISIBLE);

    // scaled cell: use 16x16 (scale factor 2 of 8x8)
    localparam CELL_W = 16;
    localparam CELL_H = 16;
    wire [9:0] px = hcnt;
    wire [9:0] py = vcnt;
    wire [6:0] col = px / CELL_W; // 0..39 (640/16 = 40 columns)
    wire [5:0] row = py / CELL_H; // 0..29 (480/16 = 30 rows)
    wire [3:0] fx = px[3:0]; // pixel within 16-wide cell (0..15)
    wire [3:0] fy = py[3:0]; // pixel within 16-high cell

    // Use font8 (8x8). We'll map each font row to two fy rows (scale 2).
    function [7:0] font8;
        input [7:0] ch;
        input [2:0] r;
        begin
            font8 = 8'b00000000;
            case (ch)
                " " : font8 = 8'b00000000;
                "L": case(r)
                    3'd0: font8 = 8'b10000000;
                    3'd1: font8 = 8'b10000000;
                    3'd2: font8 = 8'b10000000;
                    3'd3: font8 = 8'b10000000;
                    3'd4: font8 = 8'b10000000;
                    3'd5: font8 = 8'b10000010;
                    3'd6: font8 = 8'b01111111;
                    3'd7: font8 = 8'b00000000;
                endcase
                "O": case(r)
                    3'd0: font8 = 8'b00111100;
                    3'd1: font8 = 8'b01000010;
                    3'd2: font8 = 8'b10000001;
                    3'd3: font8 = 8'b10000001;
                    3'd4: font8 = 8'b10000001;
                    3'd5: font8 = 8'b01000010;
                    3'd6: font8 = 8'b00111100;
                    3'd7: font8 = 8'b00000000;
                endcase
                "K": case(r)
                    3'd0: font8 = 8'b10000010;
                    3'd1: font8 = 8'b10000100;
                    3'd2: font8 = 8'b10001000;
                    3'd3: font8 = 8'b10010000;
                    3'd4: font8 = 8'b10001000;
                    3'd5: font8 = 8'b10000100;
                    3'd6: font8 = 8'b10000010;
                    3'd7: font8 = 8'b00000000;
                endcase
                "!": case(r)
                    3'd0: font8 = 8'b00011000;
                    3'd1: font8 = 8'b00011000;
                    3'd2: font8 = 8'b00011000;
                    3'd3: font8 = 8'b00011000;
                    3'd4: font8 = 8'b00011000;
                    3'd5: font8 = 8'b00000000;
                    3'd6: font8 = 8'b00011000;
                    3'd7: font8 = 8'b00000000;
                endcase
                "U": case(r)
                    3'd0: font8 = 8'b10000001;
                    3'd1: font8 = 8'b10000001;
                    3'd2: font8 = 8'b10000001;
                    3'd3: font8 = 8'b10000001;
                    3'd4: font8 = 8'b10000001;
                    3'd5: font8 = 8'b01000010;
                    3'd6: font8 = 8'b00111100;
                    3'd7: font8 = 8'b00000000;
                endcase
                "N": case(r)
                    3'd0: font8 = 8'b10000001;
                    3'd1: font8 = 8'b11000001;
                    3'd2: font8 = 8'b10100001;
                    3'd3: font8 = 8'b10010001;
                    3'd4: font8 = 8'b10001001;
                    3'd5: font8 = 8'b10000101;
                    3'd6: font8 = 8'b10000011;
                    3'd7: font8 = 8'b00000000;
                endcase
                "D": case(r)
                    3'd0: font8 = 8'b11111100;
                    3'd1: font8 = 8'b10000010;
                    3'd2: font8 = 8'b10000001;
                    3'd3: font8 = 8'b10000001;
                    3'd4: font8 = 8'b10000001;
                    3'd5: font8 = 8'b10000010;
                    3'd6: font8 = 8'b11111100;
                    3'd7: font8 = 8'b00000000;
                endcase
                "W": case(r)
                    3'd0: font8 = 8'b10000001;
                    3'd1: font8 = 8'b10000001;
                    3'd2: font8 = 8'b10000001;
                    3'd3: font8 = 8'b10010001;
                    3'd4: font8 = 8'b10101001;
                    3'd5: font8 = 8'b11000110;
                    3'd6: font8 = 8'b10000001;
                    3'd7: font8 = 8'b00000000;
                endcase
                "E": case(r)
                    3'd0: font8 = 8'b11111111;
                    3'd1: font8 = 8'b10000000;
                    3'd2: font8 = 8'b10000000;
                    3'd3: font8 = 8'b11111110;
                    3'd4: font8 = 8'b10000000;
                    3'd5: font8 = 8'b10000000;
                    3'd6: font8 = 8'b11111111;
                    3'd7: font8 = 8'b00000000;
                endcase
                "T": case(r)
                    3'd0: font8 = 8'b11111111;
                    3'd1: font8 = 8'b00011000;
                    3'd2: font8 = 8'b00011000;
                    3'd3: font8 = 8'b00011000;
                    3'd4: font8 = 8'b00011000;
                    3'd5: font8 = 8'b00011000;
                    3'd6: font8 = 8'b00111100;
                    3'd7: font8 = 8'b00000000;
                endcase
                "A": case(r)
                    3'd0: font8 = 8'b00111100;
                    3'd1: font8 = 8'b01000010;
                    3'd2: font8 = 8'b10000001;
                    3'd3: font8 = 8'b11111111;
                    3'd4: font8 = 8'b10000001;
                    3'd5: font8 = 8'b10000001;
                    3'd6: font8 = 8'b10000001;
                    3'd7: font8 = 8'b00000000;
                endcase
                "C": case(r)
                    3'd0: font8 = 8'b00111110;
                    3'd1: font8 = 8'b01000001;
                    3'd2: font8 = 8'b10000000;
                    3'd3: font8 = 8'b10000000;
                    3'd4: font8 = 8'b10000000;
                    3'd5: font8 = 8'b01000001;
                    3'd6: font8 = 8'b00111110;
                    3'd7: font8 = 8'b00000000;
                endcase
                "P": case(r)
                    3'd0: font8 = 8'b11111110;
                    3'd1: font8 = 8'b10000001;
                    3'd2: font8 = 8'b10000001;
                    3'd3: font8 = 8'b11111110;
                    3'd4: font8 = 8'b10000000;
                    3'd5: font8 = 8'b10000000;
                    3'd6: font8 = 8'b10000000;
                    3'd7: font8 = 8'b00000000;
                endcase
                "R": case(r)
                    3'd0: font8 = 8'b11111100;
                    3'd1: font8 = 8'b10000010;
                    3'd2: font8 = 8'b10000010;
                    3'd3: font8 = 8'b11111100;
                    3'd4: font8 = 8'b10100000;
                    3'd5: font8 = 8'b10010000;
                    3'd6: font8 = 8'b10001000;
                    3'd7: font8 = 8'b00000000;
                endcase
                "G": case(r)
                    3'd0: font8 = 8'b00111100;
                    3'd1: font8 = 8'b01000010;
                    3'd2: font8 = 8'b10000000;
                    3'd3: font8 = 8'b10001110;
                    3'd4: font8 = 8'b10000010;
                    3'd5: font8 = 8'b01000010;
                    3'd6: font8 = 8'b00111100;
                    3'd7: font8 = 8'b00000000;
                endcase
                "S": case(r)
                    3'd0: font8 = 8'b01111110;
                    3'd1: font8 = 8'b01000000;
                    3'd2: font8 = 8'b01000000;
                    3'd3: font8 = 8'b00111100;
                    3'd4: font8 = 8'b00000010;
                    3'd5: font8 = 8'b00000010;
                    3'd6: font8 = 8'b11111100;
                    3'd7: font8 = 8'b00000000;
                endcase
                "1": case(r)
                    3'd0: font8 = 8'b00001000;
                    3'd1: font8 = 8'b00011000;
                    3'd2: font8 = 8'b00101000;
                    3'd3: font8 = 8'b00001000;
                    3'd4: font8 = 8'b00001000;
                    3'd5: font8 = 8'b00001000;
                    3'd6: font8 = 8'b00111110;
                    3'd7: font8 = 8'b00000000;
                endcase
                "2": case(r)
                    3'd0: font8 = 8'b00111100;
                    3'd1: font8 = 8'b01000010;
                    3'd2: font8 = 8'b00000010;
                    3'd3: font8 = 8'b00011100;
                    3'd4: font8 = 8'b00100000;
                    3'd5: font8 = 8'b01000000;
                    3'd6: font8 = 8'b01111110;
                    3'd7: font8 = 8'b00000000;
                endcase
                "3": case(r)
                    3'd0: font8 = 8'b00111100;
                    3'd1: font8 = 8'b01000010;
                    3'd2: font8 = 8'b00000010;
                    3'd3: font8 = 8'b00011100;
                    3'd4: font8 = 8'b00000010;
                    3'd5: font8 = 8'b01000010;
                    3'd6: font8 = 8'b00111100;
                    3'd7: font8 = 8'b00000000;
                endcase
                "4": case(r)
                    3'd0: font8 = 8'b00000100;
                    3'd1: font8 = 8'b00001100;
                    3'd2: font8 = 8'b00010100;
                    3'd3: font8 = 8'b00100100;
                    3'd4: font8 = 8'b01111110;
                    3'd5: font8 = 8'b00000100;
                    3'd6: font8 = 8'b00000100;
                    3'd7: font8 = 8'b00000000;
                endcase
                default: font8 = 8'b00000000;
            endcase
        end
    endfunction

    // -----------------------
    // Determine which character to render for the 3 main rows:
    // top: "WELCOME TO DE2-115" (we render as multiple chars)
    // mid: big status line (LOCKED!!! / UNLOCKED)
    // bot: "ENTER PASSWORD BELOW" and show entered digits on next line
    // We'll place big status centered across the 40 columns (each cell 16px)
    // -----------------------

    // helper to pick top string char by index
    function [7:0] top_str;
        input [5:0] idx; // 0..39 but we use 0..23
        begin
            case (idx)
                6'd0: top_str = "W";
                6'd1: top_str = "E";
                6'd2: top_str = "L";
                6'd3: top_str = "C";
                6'd4: top_str = "O";
                6'd5: top_str = "M";
                6'd6: top_str = "E";
                6'd7: top_str = " ";
                6'd8: top_str = "T";
                6'd9: top_str = "O";
                6'd10: top_str = " ";
                6'd11: top_str = "D";
                6'd12: top_str = "E";
                6'd13: top_str = "2";
                6'd14: top_str = "-";
                6'd15: top_str = "1";
                6'd16: top_str = "5";
                default: top_str = " ";
            endcase
        end
    endfunction

    // compute render pixel
    reg pixel_on;
    reg [7:0] cur_ch;
    integer left_top;
    integer left_mid;
    integer left_bot;
    integer ch_idx;
    wire [6:0] cell_col = col; // 0..39
    wire [5:0] cell_row = row; // 0..29
    // map font row inside 16x16 cell:
    wire [2:0] font_row = fy[4:1]; // map 0..15 to 0..7 (divide by 2)
    wire [2:0] font_col_index = fx[4:1]; // 0..7

    always @(*) begin
        pixel_on = 1'b0;
        cur_ch = " ";

        if (visible) begin
            // TOP: row 3 (approx) -> show WELCOME TO DE2-15 (we picked small area)
            if (cell_row == 3) begin
                left_top = (40 - 17) / 2; // center length ~17
                ch_idx = cell_col - left_top;
                if (ch_idx >= 0 && ch_idx < 17) begin
                    // map indices to our top_str mapping (we left gaps)
                    case (ch_idx)
                        0: cur_ch = "W"; 1: cur_ch = "E"; 2: cur_ch = "L"; 3: cur_ch = "C";
                        4: cur_ch = "O"; 5: cur_ch = "M"; 6: cur_ch = "E"; 7: cur_ch = " ";
                        8: cur_ch = "T"; 9: cur_ch = "O"; 10: cur_ch = " ";
                        11: cur_ch = "D"; 12: cur_ch = "E"; 13: cur_ch = "2"; 14: cur_ch = "-";
                        15: cur_ch = "1"; 16: cur_ch = "5";
                        default: cur_ch = " ";
                    endcase
                end else cur_ch = " ";
                pixel_on = font8(cur_ch, font_row)[7 - font_col_index];
            end
            // MID: row 12 -> big status (LOCKED!!! or UNLOCKED)
            else if (cell_row == 12) begin
                if (locked) begin
                    left_mid = (40 - 7)/2; // "LOCKED!" length approx 7
                    ch_idx = cell_col - left_mid;
                    case (ch_idx)
                        0: cur_ch = "L"; 1: cur_ch = "O"; 2: cur_ch = "C";
                        3: cur_ch = "K"; 4: cur_ch = "E"; 5: cur_ch = "D"; 6: cur_ch = "!";
                        default: cur_ch = " ";
                    endcase
                end else begin
                    left_mid = (40 - 8)/2; // "UNLOCKED"
                    ch_idx = cell_col - left_mid;
                    case (ch_idx)
                        0: cur_ch = "U";1: cur_ch = "N";2: cur_ch = "L";3: cur_ch = "O";
                        4: cur_ch = "C";5: cur_ch = "K";6: cur_ch = "E";7: cur_ch = "D";
                        default: cur_ch = " ";
                    endcase
                end
                pixel_on = font8(cur_ch, font_row)[7 - font_col_index];
            end
            // BOT prompt: row 18 -> "ENTER PASSWORD BELOW" approx, and next row show digits
            else if (cell_row == 18) begin
                left_bot = (40 - 19)/2; // center
                ch_idx = cell_col - left_bot;
                case (ch_idx)
                    0: cur_ch = "E";1: cur_ch="N";2:cur_ch="T";3:cur_ch="E";4:cur_ch="R";
                    5: cur_ch=" ";6: cur_ch="P";7:cur_ch="A";8:cur_ch="S";9:cur_ch="S";
                    10: cur_ch="W";11: cur_ch="O";12: cur_ch="R";13:cur_ch="D";14:cur_ch=" ";
                    15: cur_ch="B";16: cur_ch="E";17:cur_ch="L";18:cur_ch="O";19:cur_ch="W";
                    default: cur_ch = " ";
                endcase
                pixel_on = font8(cur_ch, font_row)[7 - font_col_index];
            end
            // DIGITS row below prompt: row 20 -> show entered digits visible
            else if (cell_row == 20) begin
                // center "D1 D2 D3 D4" with spaces
                integer left_digits;
                left_digits = (40 - 7)/2; // something like " 4 3 _ _ "
                ch_idx = cell_col - left_digits;
                if (ch_idx == 1) begin
                    cur_ch = (entered0 <= 4'd9) ? (8'h30 + entered0) : " ";
                end else if (ch_idx == 3) begin
                    cur_ch = (entered1 <= 4'd9) ? (8'h30 + entered1) : " ";
                end else if (ch_idx == 5) begin
                    cur_ch = (entered2 <= 4'd9) ? (8'h30 + entered2) : " ";
                end else if (ch_idx == 7) begin
                    cur_ch = (entered3 <= 4'd9) ? (8'h30 + entered3) : " ";
                end else begin
                    cur_ch = " ";
                end
                pixel_on = font8(cur_ch, font_row)[7 - font_col_index];
            end
            // WRONG message: if show_wrong true, overwrite mid area with "WRONG PASSWORD"
            else if (show_wrong && (cell_row == 12)) begin
                left_mid = (40 - 14)/2;
                ch_idx = cell_col - left_mid;
                case (ch_idx)
                    0: cur_ch="W";1:cur_ch="R";2:cur_ch="O";3:cur_ch="N";4:cur_ch="G";
                    5: cur_ch=" ";6:cur_ch="P";7:cur_ch="A";8:cur_ch="S";9:cur_ch="S";
                    10: cur_ch="W";11: cur_ch="O";12: cur_ch="R";13: cur_ch="D";
                    default: cur_ch = " ";
                endcase
                pixel_on = font8(cur_ch, font_row)[7 - font_col_index];
            end
            else pixel_on = 1'b0;
        end else pixel_on = 1'b0;
    end

    // color mapping: white text on dark blue background
    wire [2:0] out_r = (pixel_on ? 3'b111 : 3'b000);
    wire [2:0] out_g = (pixel_on ? 3'b111 : 3'b000);
    wire [1:0] out_b = (pixel_on ? 2'b11  : 2'b01);

    assign VGA_R = out_r;
    assign VGA_G = out_g;
    assign VGA_B = out_b;

endmodule


// ===================================================
// Debouncer and one_pulse modules (Verilog-2001)
// ===================================================
module debouncer #(
    parameter CLK_FREQ = 50000000,
    parameter DEB_MS = 20
) (
    input  wire clk,
    input  wire reset,
    input  wire noisy,
    output reg  clean
);
    localparam integer COUNT_MAX = (CLK_FREQ/1000) * DEB_MS;
    reg [31:0] counter;
    reg sampled;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 32'd0;
            sampled <= noisy;
            clean <= noisy;
        end else begin
            if (noisy == sampled) begin
                if (counter < COUNT_MAX) counter <= counter + 1;
                else clean <= sampled;
            end else begin
                sampled <= noisy;
                counter <= 32'd0;
            end
        end
    end
endmodule

module one_pulse (
    input  wire clk,
    input  wire reset,
    input  wire sig,
    output wire pulse
);
    reg sig_d;
    always @(posedge clk or posedge reset) begin
        if (reset) sig_d <= 1'b0;
        else sig_d <= sig;
    end
    assign pulse = sig & ~sig_d;
endmodule
