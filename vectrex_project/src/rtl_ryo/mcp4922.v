// mcp4922.v
// module for MCP4922 12bit dual channel DAC with SPI interface
// written by Ryo Mukai

module mcp4922(
	       input	    I_clk,
	       input [11:0] I_dataA,
	       input [11:0] I_dataB,
	       input	    I_we,
	       output reg   O_sclk,
	       output reg   O_sd,
	       output reg   O_ldac_n,
	       output reg   O_cs_n
);

  parameter CLK_FRE  = 27_000_000; // 27MHz
  parameter SCLK_FRE =  2_700_000; // 2.7MHz

  parameter S_WAIT = 2'd0;
  parameter S_SEND = 2'd1;
  parameter S_LDAC = 2'd2;
  reg [1:0] state;
  reg [32:0] sendbuf;
  reg [7:0] send_cnt;
  reg [4:0] sclk_cnt;
  

  always @(negedge I_clk) begin
     if(sclk_cnt == 5'd4) begin // CLK_FRE / SCLK_FRE / 2 - 1= 4;
	O_sclk <= ~O_sclk;
	sclk_cnt <= 0;
     end
     else
       sclk_cnt <=  sclk_cnt + 1'd1;
  end
  always @(negedge O_sclk) begin
     case( state )
       S_WAIT: begin
	  O_ldac_n <= 1;
	  O_cs_n <= 1;
	  if( I_we == 1) begin
	     state <= S_SEND;
	     sendbuf <= { 4'b0011, I_dataA, 1'b0,
			  4'b1011, I_dataB};
	     send_cnt <= 0;
	  end
       end
       S_SEND: begin
	  case (send_cnt)
	    6'd0:  O_cs_n <= 0;
	    6'd16: O_cs_n <= 1;
	    6'd17: O_cs_n <= 0;
	    6'd33: begin
	       O_cs_n <= 1;
	       state <= S_LDAC;
	    end
	  endcase
	  O_sd <= sendbuf[32];
	  sendbuf <= {sendbuf[31:0], 1'd0};
	  send_cnt <= send_cnt + 1'd1;
       end
       S_LDAC: begin
	  O_ldac_n <= 0;
	  state <= S_WAIT;
       end
     endcase
  end
endmodule
