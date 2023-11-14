// mcp4911x3.v
// module for triple MCP4811/4911 10bit single channel DAC with SPI interface
// written by Ryo Mukai

module mcp4911x3(
	       input	   I_clk,
	       input [9:0] I_data0,
	       input [9:0] I_data1,
	       input [9:0] I_data2,
	       input [3:0] I_header,
	       input	   I_we,
	       output	   O_sclk,
	       output reg  O_cs_n,
	       output reg  O_ldac_n,
	       output reg  O_sd0,
	       output reg  O_sd1,
	       output reg  O_sd2
);

  parameter S_WAIT  = 1'd0;
  parameter S_SEND  = 1'd1;
  reg state;
  reg [15:0] sendbuf0;
  reg [15:0] sendbuf1;
  reg [15:0] sendbuf2;
  reg [7:0] send_cnt;
  
  assign O_sclk = I_clk;

  always @(negedge O_sclk) begin
     case( state )
       S_WAIT: begin
	  O_ldac_n <= 1;
	  O_cs_n <= 1;
	  if( I_we == 1) begin
	     state <= S_SEND;
	     sendbuf0 <= {I_header, I_data0, 2'b0};
	     sendbuf1 <= {I_header, I_data1, 2'b0};
	     sendbuf2 <= {I_header, I_data2, 2'b0};
	     send_cnt <= 0;
	  end
       end
       S_SEND: begin
	  case (send_cnt)
	    6'd0:  O_cs_n <= 0;
	    6'd16: O_cs_n <= 1;
	    6'd17: O_ldac_n <= 0;  // T_LD>=100ns
	    6'd18: state <= S_WAIT;
	  endcase
	  O_sd0 <= sendbuf0[15];
	  O_sd1 <= sendbuf1[15];
	  O_sd2 <= sendbuf2[15];
	  sendbuf0 <= {sendbuf0[14:0], 1'b0};
	  sendbuf1 <= {sendbuf1[14:0], 1'b0};
	  sendbuf2 <= {sendbuf2[14:0], 1'b0};
	  send_cnt <= send_cnt + 1'd1;
       end
     endcase
  end
endmodule
