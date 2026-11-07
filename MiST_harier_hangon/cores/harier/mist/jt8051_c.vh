localparam CPCW = 12;
reg              jsr_en;
reg  [CPCW-1:0]  cpc, cpc_nx, cjsr_ret, cjsr_ua;
reg  [     7:0]  uidx;
reg  [     7:0]  uidx_rom[0:3282];
reg  [    47:0]  ucode_data;

initial begin
    $readmemh("jt8051_cidx.hex",uidx_rom);
end

localparam [CPCW-1:0] CFETCH0 = 12'd2995, CISR = 12'd3261;

always @* begin
    case( uidx )
        8'd1: ucode_data = 48'h000000000002;
        8'd2: ucode_data = 48'h000000000004;
        8'd3: ucode_data = 48'h000000000006;
        8'd4: ucode_data = 48'h000000000008;
        8'd5: ucode_data = 48'h00000000000A;
        8'd6: ucode_data = 48'h00000000000C;
        8'd7: ucode_data = 48'h000000000200;
        8'd8: ucode_data = 48'h000000000400;
        8'd9: ucode_data = 48'h000000000600;
        8'd10: ucode_data = 48'h000002000000;
        8'd11: ucode_data = 48'h000004000000;
        8'd12: ucode_data = 48'h000006000000;
        8'd13: ucode_data = 48'h000008000000;
        8'd14: ucode_data = 48'h00000A000000;
        8'd15: ucode_data = 48'h00000C000000;
        8'd16: ucode_data = 48'h00000E000000;
        8'd17: ucode_data = 48'h000010000000;
        8'd18: ucode_data = 48'h000012000000;
        8'd19: ucode_data = 48'h000014000000;
        8'd20: ucode_data = 48'h000016000000;
        8'd21: ucode_data = 48'h000018000000;
        8'd22: ucode_data = 48'h00001A000000;
        8'd23: ucode_data = 48'h00001C000000;
        8'd24: ucode_data = 48'h00001E000000;
        8'd25: ucode_data = 48'h000020000000;
        8'd26: ucode_data = 48'h000022000000;
        8'd27: ucode_data = 48'h000024000000;
        8'd28: ucode_data = 48'h000026000000;
        8'd29: ucode_data = 48'h000028000000;
        8'd30: ucode_data = 48'h00002A000000;
        8'd31: ucode_data = 48'h00002C000000;
        8'd32: ucode_data = 48'h00002E000000;
        8'd33: ucode_data = 48'h000030000000;
        8'd34: ucode_data = 48'h000032000000;
        8'd35: ucode_data = 48'h000034000000;
        8'd36: ucode_data = 48'h000036000000;
        8'd37: ucode_data = 48'h000036000200;
        8'd38: ucode_data = 48'h000036000400;
        8'd39: ucode_data = 48'h000038000000;
        8'd40: ucode_data = 48'h00003A000000;
        8'd41: ucode_data = 48'h00003C000000;
        8'd42: ucode_data = 48'h00003E000000;
        8'd43: ucode_data = 48'h000040000000;
        8'd44: ucode_data = 48'h000042000000;
        8'd45: ucode_data = 48'h000044000000;
        8'd46: ucode_data = 48'h000046000000;
        8'd47: ucode_data = 48'h000080000000;
        8'd48: ucode_data = 48'h000100000002;
        8'd49: ucode_data = 48'h000100000004;
        8'd50: ucode_data = 48'h000200000000;
        8'd51: ucode_data = 48'h000400000000;
        8'd52: ucode_data = 48'h000600000000;
        8'd53: ucode_data = 48'h000A00000000;
        8'd54: ucode_data = 48'h000C00000000;
        8'd55: ucode_data = 48'h000E00000800;
        8'd56: ucode_data = 48'h000E00001800;
        8'd57: ucode_data = 48'h001000001000;
        8'd58: ucode_data = 48'h001000002000;
        8'd59: ucode_data = 48'h001000003000;
        8'd60: ucode_data = 48'h001000004000;
        8'd61: ucode_data = 48'h001200000000;
        8'd62: ucode_data = 48'h003200000000;
        8'd63: ucode_data = 48'h004000060000;
        8'd64: ucode_data = 48'h0040000C0000;
        8'd65: ucode_data = 48'h004000100000;
        8'd66: ucode_data = 48'h004000110000;
        8'd67: ucode_data = 48'h004000120000;
        8'd68: ucode_data = 48'h008000070000;
        8'd69: ucode_data = 48'h00C000010030;
        8'd70: ucode_data = 48'h00C000010050;
        8'd71: ucode_data = 48'h00C000010070;
        8'd72: ucode_data = 48'h00C000010090;
        8'd73: ucode_data = 48'h00C0000100B0;
        8'd74: ucode_data = 48'h00C0000100C0;
        8'd75: ucode_data = 48'h00C0000100E0;
        8'd76: ucode_data = 48'h00C000010110;
        8'd77: ucode_data = 48'h00C000010130;
        8'd78: ucode_data = 48'h00C000030050;
        8'd79: ucode_data = 48'h00C000050030;
        8'd80: ucode_data = 48'h00C000050050;
        8'd81: ucode_data = 48'h00C0000500B0;
        8'd82: ucode_data = 48'h00C000060030;
        8'd83: ucode_data = 48'h00C000060070;
        8'd84: ucode_data = 48'h00C000060090;
        8'd85: ucode_data = 48'h00C0000600B0;
        8'd86: ucode_data = 48'h00C000060130;
        8'd87: ucode_data = 48'h00C000080090;
        8'd88: ucode_data = 48'h00C000110070;
        8'd89: ucode_data = 48'h00C000110090;
        8'd90: ucode_data = 48'h00C000110120;
        8'd91: ucode_data = 48'h00C000120070;
        8'd92: ucode_data = 48'h00C000120090;
        8'd93: ucode_data = 48'h00C000210010;
        8'd94: ucode_data = 48'h00C000210020;
        8'd95: ucode_data = 48'h00C000210100;
        8'd96: ucode_data = 48'h00C000610060;
        8'd97: ucode_data = 48'h00C0006100D0;
        8'd98: ucode_data = 48'h00C0006100F0;
        8'd99: ucode_data = 48'h00C000810080;
        8'd100: ucode_data = 48'h00C0008100A0;
        8'd101: ucode_data = 48'h00CE00063870;
        8'd102: ucode_data = 48'h00CE00402840;
        8'd103: ucode_data = 48'h00D000123870;
        8'd104: ucode_data = 48'h010000020080;
        8'd105: ucode_data = 48'h0100000200A0;
        8'd106: ucode_data = 48'h01002A010120;
        8'd107: ucode_data = 48'h014000100000;
        8'd108: ucode_data = 48'h018000050000;
        8'd109: ucode_data = 48'h0180000C0000;
        8'd110: ucode_data = 48'h018000100000;
        8'd111: ucode_data = 48'h01C0000D0000;
        8'd112: ucode_data = 48'h01C0360D0000;
        8'd113: ucode_data = 48'h01C1000D0000;
        8'd114: ucode_data = 48'h01C1360D0000;
        8'd115: ucode_data = 48'h020000030000;
        8'd116: ucode_data = 48'h0200000C0000;
        8'd117: ucode_data = 48'h024000010200;
        8'd118: ucode_data = 48'h024000010400;
        8'd119: ucode_data = 48'h0248000B0000;
        8'd120: ucode_data = 48'h0248000E0000;
        8'd121: ucode_data = 48'h0248000F0000;
        8'd122: ucode_data = 48'h0248360B0000;
        8'd123: ucode_data = 48'h0248360E0000;
        8'd124: ucode_data = 48'h0248360F0000;
        8'd125: ucode_data = 48'h0280000D0000;
        8'd126: ucode_data = 48'h0280360D0000;
        8'd127: ucode_data = 48'h0281000D0000;
        8'd128: ucode_data = 48'h0281360D0000;
        8'd129: ucode_data = 48'h02C0000C0000;
        8'd130: ucode_data = 48'h038000010000;
        8'd131: ucode_data = 48'h038000060000;
        8'd132: ucode_data = 48'h0380000A0000;
        8'd133: ucode_data = 48'h0380000C0000;
        8'd134: ucode_data = 48'h038000100000;
        8'd135: ucode_data = 48'h038000110000;
        8'd136: ucode_data = 48'h038000120000;
        8'd137: ucode_data = 48'h03C000100000;
        8'd138: ucode_data = 48'h040000030000;
        8'd139: ucode_data = 48'h040000050000;
        8'd140: ucode_data = 48'h044000010000;
        8'd141: ucode_data = 48'h044000100000;
        8'd142: ucode_data = 48'h044000110000;
        8'd143: ucode_data = 48'h044000120000;
        8'd144: ucode_data = 48'h048000060000;
        8'd145: ucode_data = 48'h048000100000;
        8'd146: ucode_data = 48'h048036090000;
        8'd147: ucode_data = 48'h054000090000;
        8'd148: ucode_data = 48'h0540000D0000;
        8'd149: ucode_data = 48'h0540000D8000;
        8'd150: ucode_data = 48'h0540000E8000;
        8'd151: ucode_data = 48'h0540000F8000;
        8'd152: ucode_data = 48'h054036090000;
        8'd153: ucode_data = 48'h0540360D0000;
        8'd154: ucode_data = 48'h05C000010000;
        8'd155: ucode_data = 48'h05C000030000;
        8'd156: ucode_data = 48'h05C000050000;
        8'd157: ucode_data = 48'h05CE00040800;
        8'd158: ucode_data = 48'h0B000100000E;
        8'd159: ucode_data = 48'h0B400100000E;
        8'd160: ucode_data = 48'h0B800100000E;
        8'd161: ucode_data = 48'h0CC00100000E;
        8'd162: ucode_data = 48'h0D000100000E;
        8'd163: ucode_data = 48'h100000000000;
        8'd164: ucode_data = 48'h104000130000;
        8'd165: ucode_data = 48'h158000010000;
        8'd166: ucode_data = 48'h200000000000;
        8'd167: ucode_data = 48'h204000130000;
        8'd168: ucode_data = 48'h258000010000;
        8'd169: ucode_data = 48'h500000000001;
        8'd170: ucode_data = 48'h600000000001;
        8'd171: ucode_data = 48'h900000000001;
        8'd172: ucode_data = 48'hA00000000001;
        default: ucode_data = 48'h0;
    endcase
end

assign x_acc      = ucode_data[ 0+:1];
assign sp_dec     = ucode_data[15+:1];
assign sp_inc     = ucode_data[24+:1];
assign ni         = ucode_data[31+:1];
assign latch      = ucode_data[32+:1];
assign reti       = ucode_data[37+:1];
assign wr         = ucode_data[43+:1];
assign addr_sel   = ucode_data[ 1+:3];
assign alu_sel    = ucode_data[ 4+:5];
assign code_sel   = ucode_data[ 9+:2];
assign cond_sel   = ucode_data[11+:4];
assign dst_sel    = ucode_data[16+:5];
assign flag_sel   = ucode_data[21+:3];
assign jsr_sel    = ucode_data[25+:6];
assign pc_sel     = ucode_data[33+:4];
assign src_sel    = ucode_data[38+:5];
assign x_sel      = ucode_data[44+:2];
assign xwr_sel    = ucode_data[46+:2];

function [CPCW-1:0] op_base( input [7:0] op );
    case( op )
        8'h00: op_base = 12'd1;
        8'h01: op_base = 12'd12;
        8'h02: op_base = 12'd30;
        8'h03: op_base = 12'd43;
        8'h04: op_base = 12'd54;
        8'h05: op_base = 12'd64;
        8'h06: op_base = 12'd71;
        8'h07: op_base = 12'd78;
        8'h08: op_base = 12'd85;
        8'h09: op_base = 12'd93;
        8'h0A: op_base = 12'd101;
        8'h0B: op_base = 12'd109;
        8'h0C: op_base = 12'd117;
        8'h0D: op_base = 12'd125;
        8'h0E: op_base = 12'd133;
        8'h0F: op_base = 12'd141;
        8'h10: op_base = 12'd149;
        8'h11: op_base = 12'd159;
        8'h12: op_base = 12'd177;
        8'h13: op_base = 12'd190;
        8'h14: op_base = 12'd201;
        8'h15: op_base = 12'd211;
        8'h16: op_base = 12'd218;
        8'h17: op_base = 12'd225;
        8'h18: op_base = 12'd232;
        8'h19: op_base = 12'd240;
        8'h1A: op_base = 12'd248;
        8'h1B: op_base = 12'd256;
        8'h1C: op_base = 12'd264;
        8'h1D: op_base = 12'd272;
        8'h1E: op_base = 12'd280;
        8'h1F: op_base = 12'd288;
        8'h20: op_base = 12'd296;
        8'h21: op_base = 12'd306;
        8'h22: op_base = 12'd324;
        8'h23: op_base = 12'd347;
        8'h24: op_base = 12'd358;
        8'h25: op_base = 12'd367;
        8'h26: op_base = 12'd374;
        8'h27: op_base = 12'd381;
        8'h28: op_base = 12'd388;
        8'h29: op_base = 12'd396;
        8'h2A: op_base = 12'd404;
        8'h2B: op_base = 12'd412;
        8'h2C: op_base = 12'd420;
        8'h2D: op_base = 12'd428;
        8'h2E: op_base = 12'd436;
        8'h2F: op_base = 12'd444;
        8'h30: op_base = 12'd452;
        8'h31: op_base = 12'd462;
        8'h32: op_base = 12'd480;
        8'h33: op_base = 12'd503;
        8'h34: op_base = 12'd514;
        8'h35: op_base = 12'd523;
        8'h36: op_base = 12'd530;
        8'h37: op_base = 12'd537;
        8'h38: op_base = 12'd544;
        8'h39: op_base = 12'd552;
        8'h3A: op_base = 12'd560;
        8'h3B: op_base = 12'd568;
        8'h3C: op_base = 12'd576;
        8'h3D: op_base = 12'd584;
        8'h3E: op_base = 12'd592;
        8'h3F: op_base = 12'd600;
        8'h40: op_base = 12'd608;
        8'h41: op_base = 12'd626;
        8'h42: op_base = 12'd644;
        8'h43: op_base = 12'd651;
        8'h44: op_base = 12'd668;
        8'h45: op_base = 12'd677;
        8'h46: op_base = 12'd684;
        8'h47: op_base = 12'd691;
        8'h48: op_base = 12'd698;
        8'h49: op_base = 12'd706;
        8'h4A: op_base = 12'd714;
        8'h4B: op_base = 12'd722;
        8'h4C: op_base = 12'd730;
        8'h4D: op_base = 12'd738;
        8'h4E: op_base = 12'd746;
        8'h4F: op_base = 12'd754;
        8'h50: op_base = 12'd762;
        8'h51: op_base = 12'd780;
        8'h52: op_base = 12'd798;
        8'h53: op_base = 12'd805;
        8'h54: op_base = 12'd822;
        8'h55: op_base = 12'd831;
        8'h56: op_base = 12'd838;
        8'h57: op_base = 12'd845;
        8'h58: op_base = 12'd852;
        8'h59: op_base = 12'd860;
        8'h5A: op_base = 12'd868;
        8'h5B: op_base = 12'd876;
        8'h5C: op_base = 12'd884;
        8'h5D: op_base = 12'd892;
        8'h5E: op_base = 12'd900;
        8'h5F: op_base = 12'd908;
        8'h60: op_base = 12'd916;
        8'h61: op_base = 12'd934;
        8'h62: op_base = 12'd952;
        8'h63: op_base = 12'd959;
        8'h64: op_base = 12'd976;
        8'h65: op_base = 12'd985;
        8'h66: op_base = 12'd992;
        8'h67: op_base = 12'd999;
        8'h68: op_base = 12'd1006;
        8'h69: op_base = 12'd1014;
        8'h6A: op_base = 12'd1022;
        8'h6B: op_base = 12'd1030;
        8'h6C: op_base = 12'd1038;
        8'h6D: op_base = 12'd1046;
        8'h6E: op_base = 12'd1054;
        8'h6F: op_base = 12'd1062;
        8'h70: op_base = 12'd1070;
        8'h71: op_base = 12'd1088;
        8'h72: op_base = 12'd1106;
        8'h73: op_base = 12'd1125;
        8'h74: op_base = 12'd1148;
        8'h75: op_base = 12'd1157;
        8'h76: op_base = 12'd1170;
        8'h77: op_base = 12'd1177;
        8'h78: op_base = 12'd1184;
        8'h79: op_base = 12'd1193;
        8'h7A: op_base = 12'd1202;
        8'h7B: op_base = 12'd1211;
        8'h7C: op_base = 12'd1220;
        8'h7D: op_base = 12'd1229;
        8'h7E: op_base = 12'd1238;
        8'h7F: op_base = 12'd1247;
        8'h80: op_base = 12'd1256;
        8'h81: op_base = 12'd1274;
        8'h82: op_base = 12'd1292;
        8'h83: op_base = 12'd1311;
        8'h84: op_base = 12'd1329;
        8'h85: op_base = 12'd1376;
        8'h86: op_base = 12'd1385;
        8'h87: op_base = 12'd1397;
        8'h88: op_base = 12'd1409;
        8'h89: op_base = 12'd1424;
        8'h8A: op_base = 12'd1439;
        8'h8B: op_base = 12'd1454;
        8'h8C: op_base = 12'd1469;
        8'h8D: op_base = 12'd1484;
        8'h8E: op_base = 12'd1499;
        8'h8F: op_base = 12'd1514;
        8'h90: op_base = 12'd1529;
        8'h91: op_base = 12'd1542;
        8'h92: op_base = 12'd1560;
        8'h93: op_base = 12'd1579;
        8'h94: op_base = 12'd1597;
        8'h95: op_base = 12'd1606;
        8'h96: op_base = 12'd1613;
        8'h97: op_base = 12'd1620;
        8'h98: op_base = 12'd1627;
        8'h99: op_base = 12'd1635;
        8'h9A: op_base = 12'd1643;
        8'h9B: op_base = 12'd1651;
        8'h9C: op_base = 12'd1659;
        8'h9D: op_base = 12'd1667;
        8'h9E: op_base = 12'd1675;
        8'h9F: op_base = 12'd1683;
        8'hA0: op_base = 12'd1691;
        8'hA1: op_base = 12'd1706;
        8'hA2: op_base = 12'd1724;
        8'hA3: op_base = 12'd1731;
        8'hA4: op_base = 12'd1753;
        8'hA5: op_base = 12'd1800;
        8'hA6: op_base = 12'd1811;
        8'hA7: op_base = 12'd1823;
        8'hA8: op_base = 12'd1835;
        8'hA9: op_base = 12'd1854;
        8'hAA: op_base = 12'd1873;
        8'hAB: op_base = 12'd1892;
        8'hAC: op_base = 12'd1911;
        8'hAD: op_base = 12'd1930;
        8'hAE: op_base = 12'd1949;
        8'hAF: op_base = 12'd1968;
        8'hB0: op_base = 12'd1987;
        8'hB1: op_base = 12'd2002;
        8'hB2: op_base = 12'd2020;
        8'hB3: op_base = 12'd2027;
        8'hB4: op_base = 12'd2037;
        8'hB5: op_base = 12'd2056;
        8'hB6: op_base = 12'd2073;
        8'hB7: op_base = 12'd2086;
        8'hB8: op_base = 12'd2099;
        8'hB9: op_base = 12'd2116;
        8'hBA: op_base = 12'd2133;
        8'hBB: op_base = 12'd2150;
        8'hBC: op_base = 12'd2167;
        8'hBD: op_base = 12'd2184;
        8'hBE: op_base = 12'd2201;
        8'hBF: op_base = 12'd2218;
        8'hC0: op_base = 12'd2235;
        8'hC1: op_base = 12'd2254;
        8'hC2: op_base = 12'd2272;
        8'hC3: op_base = 12'd2279;
        8'hC4: op_base = 12'd2289;
        8'hC5: op_base = 12'd2300;
        8'hC6: op_base = 12'd2307;
        8'hC7: op_base = 12'd2314;
        8'hC8: op_base = 12'd2321;
        8'hC9: op_base = 12'd2329;
        8'hCA: op_base = 12'd2337;
        8'hCB: op_base = 12'd2345;
        8'hCC: op_base = 12'd2353;
        8'hCD: op_base = 12'd2361;
        8'hCE: op_base = 12'd2369;
        8'hCF: op_base = 12'd2377;
        8'hD0: op_base = 12'd2385;
        8'hD1: op_base = 12'd2404;
        8'hD2: op_base = 12'd2422;
        8'hD3: op_base = 12'd2429;
        8'hD4: op_base = 12'd2439;
        8'hD5: op_base = 12'd2450;
        8'hD6: op_base = 12'd2467;
        8'hD7: op_base = 12'd2474;
        8'hD8: op_base = 12'd2481;
        8'hD9: op_base = 12'd2500;
        8'hDA: op_base = 12'd2519;
        8'hDB: op_base = 12'd2538;
        8'hDC: op_base = 12'd2557;
        8'hDD: op_base = 12'd2576;
        8'hDE: op_base = 12'd2595;
        8'hDF: op_base = 12'd2614;
        8'hE0: op_base = 12'd2633;
        8'hE1: op_base = 12'd2655;
        8'hE2: op_base = 12'd2673;
        8'hE3: op_base = 12'd2692;
        8'hE4: op_base = 12'd2711;
        8'hE5: op_base = 12'd2721;
        8'hE6: op_base = 12'd2728;
        8'hE7: op_base = 12'd2735;
        8'hE8: op_base = 12'd2742;
        8'hE9: op_base = 12'd2750;
        8'hEA: op_base = 12'd2758;
        8'hEB: op_base = 12'd2766;
        8'hEC: op_base = 12'd2774;
        8'hED: op_base = 12'd2782;
        8'hEE: op_base = 12'd2790;
        8'hEF: op_base = 12'd2798;
        8'hF0: op_base = 12'd2806;
        8'hF1: op_base = 12'd2828;
        8'hF2: op_base = 12'd2846;
        8'hF3: op_base = 12'd2865;
        8'hF4: op_base = 12'd2884;
        8'hF5: op_base = 12'd2894;
        8'hF6: op_base = 12'd2901;
        8'hF7: op_base = 12'd2908;
        8'hF8: op_base = 12'd2915;
        8'hF9: op_base = 12'd2925;
        8'hFA: op_base = 12'd2935;
        8'hFB: op_base = 12'd2945;
        8'hFC: op_base = 12'd2955;
        8'hFD: op_base = 12'd2965;
        8'hFE: op_base = 12'd2975;
        8'hFF: op_base = 12'd2985;
    endcase
endfunction

always @* begin
    case( jsr_sel )
        FETCH_JSR:     begin jsr_en=1; cjsr_ua = 12'd2999; end
        ISRFETCH_JSR:  begin jsr_en=1; cjsr_ua = 12'd3002; end
        NONE_JSR:      begin jsr_en=1; cjsr_ua = 12'd3006; end
        IMM_JSR:       begin jsr_en=1; cjsr_ua = 12'd3008; end
        REL_JSR:       begin jsr_en=1; cjsr_ua = 12'd3011; end
        ABS_JSR:       begin jsr_en=1; cjsr_ua = 12'd3017; end
        AJMP_JSR:      begin jsr_en=1; cjsr_ua = 12'd3028; end
        ACALL_JSR:     begin jsr_en=1; cjsr_ua = 12'd3034; end
        DIRECT_JSR:    begin jsr_en=1; cjsr_ua = 12'd3040; end
        DIRECTL_JSR:   begin jsr_en=1; cjsr_ua = 12'd3045; end
        DIMM_JSR:      begin jsr_en=1; cjsr_ua = 12'd3050; end
        DIRECTIMML_JSR: begin jsr_en=1; cjsr_ua = 12'd3068; end
        RN_JSR:        begin jsr_en=1; cjsr_ua = 12'd3075; end
        RI_JSR:        begin jsr_en=1; cjsr_ua = 12'd3079; end
        RIIMM_JSR:     begin jsr_en=1; cjsr_ua = 12'd3084; end
        BIT_JSR:       begin jsr_en=1; cjsr_ua = 12'd3089; end
        BITL_JSR:      begin jsr_en=1; cjsr_ua = 12'd3094; end
        BITREL_JSR:    begin jsr_en=1; cjsr_ua = 12'd3099; end
        BITRELL_JSR:   begin jsr_en=1; cjsr_ua = 12'd3113; end
        APC_JSR:       begin jsr_en=1; cjsr_ua = 12'd3127; end
        ADPTR_JSR:     begin jsr_en=1; cjsr_ua = 12'd3133; end
        XDPTR_JSR:     begin jsr_en=1; cjsr_ua = 12'd3139; end
        XRI_JSR:       begin jsr_en=1; cjsr_ua = 12'd3141; end
        NBIT_JSR:      begin jsr_en=1; cjsr_ua = 12'd3146; end
        DDIRECT_JSR:   begin jsr_en=1; cjsr_ua = 12'd3155; end
        RIDIRECT_JSR:  begin jsr_en=1; cjsr_ua = 12'd3170; end
        DIRECTRI_JSR:  begin jsr_en=1; cjsr_ua = 12'd3182; end
        RNDIRECT_JSR:  begin jsr_en=1; cjsr_ua = 12'd3194; end
        CJNEI_JSR:     begin jsr_en=1; cjsr_ua = 12'd3203; end
        CJNED_JSR:     begin jsr_en=1; cjsr_ua = 12'd3208; end
        CJNERI_JSR:    begin jsr_en=1; cjsr_ua = 12'd3215; end
        CJNERN_JSR:    begin jsr_en=1; cjsr_ua = 12'd3226; end
        DIRECTRELL_JSR: begin jsr_en=1; cjsr_ua = 12'd3240; end
        RNREL_JSR:     begin jsr_en=1; cjsr_ua = 12'd3256; end
        RET_JSR:       begin jsr_en=1; cjsr_ua = cjsr_ret; end
        default:       begin jsr_en=0; cjsr_ua = 0; end
    endcase
end
