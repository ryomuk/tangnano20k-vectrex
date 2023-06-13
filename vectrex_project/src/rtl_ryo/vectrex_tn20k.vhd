-------------------------------------------------------------------------------
-- Tang Nano 20K top level module for vectrex
-- by Ryo Mukai (github.com/ryomuk)
-- 2023/6/11
-- 
-- modified from vectrex_de10_lite.vhd by Dar
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------
--  
-- Vectrex releases
--
-- Release 0.1 - 05/05/2018 - Dar
--		add sp0256-al2 VHDL speech simulation
--    add speakjet interface (speech IC)
--
-- Release 0.0 - 10/02/2018 - Dar
--		initial release
--
---------------------------------------------------------------------------------
-- Use vectrex_de10_lite.sdc to compile (Timequest constraints)
-- /!\
-- Don't forget to set device configuration mode with memory initialization 
--  (Assignments/Device/Pin options/Configuration mode)
---------------------------------------------------------------------------------
-- TODO :
--   sligt tune of characters drawings (too wide)
--   tune hblank to avoid persistance artifact on first 4 pixels of a line
---------------------------------------------------------------------------------
--
-- Main features :
--  PS2 keyboard input @gpio pins 35/34 (beware voltage translation/protection) 
--  Audio pwm output   @gpio pins 1/3 (beware voltage translation/protection) 
--
--  Uses 1 pll for 25/24MHz and 12.5/12MHz generation from 50MHz
--
--  Horizontal/vertical display selection at compilation 
--  3 or no intensity level selection at compilation
--
--  No external ram
--  FPGA ram usage as low as :
--
--		  336.000b ( 42Ko) without   cartridge, vertical display,   no intensity level (minestrom)
--		  402.000b ( 50Ko) with  8Ko cartridge, vertical display,   no intensity level
--	 	  599.000b ( 74ko) with 32Ko cartridge, vertical display,   no intensity level
--	 	  664.000b ( 82ko) with  8Ko cartridge, horizontal display, no intensity level
--		1.188.000b (146ko) with  8Ko cartridge, horizontal display, 3 intensity level

--  Tested cartridge:
--
--		berzerk          ( 4ko)
--		ripoff           ( 4ko)
--		scramble         ( 4ko)
--		spacewar         ( 4ko)
--		startrek         ( 4ko)
--		pole position    ( 8ko)
--		spike            ( 8ko)
--		webwars          ( 8ko)
--		frogger          (16Ko)
--		vecmania1        (32ko)
--		war of the robot (21ko)
--
-- Board key :
--   0 : reset game
--
-- Keyboard players inputs :
--
--   F3 : button
--   F2 : button
--   F1 : button 
--   SPACE       : button
--   RIGHT arrow : joystick right
--   LEFT  arrow : joystick  left
--   UP    arrow : joystick  up 
--   DOWN  arrow : joystick  down
--
-- Other details : see vectrex.vhd
-- For USB inputs and SGT5000 audio output see my other project: xevious_de10_lite
---------------------------------------------------------------------------------
-- Use tool\vectrex_unzip\make_vectrex_proms.bat to build vhdl rom files
--
--make_vhdl_prom 	exec_rom.bin vectrex_exec_prom.vhd (always needed)
--
--make_vhdl_prom 	scramble.bin vectrex_scramble_prom.vhd
--make_vhdl_prom 	berzerk.bin vectrex_berzerk_prom.vhd
--make_vhdl_prom 	frogger.bin vectrex_frogger_prom.vhd
--make_vhdl_prom 	spacewar.bin vectrex_spacewar_prom.vhd
--make_vhdl_prom 	polepos.bin vectrex_polepos_prom.vhd
--make_vhdl_prom 	ripoff.bin vectrex_ripoff_prom.vhd
--make_vhdl_prom 	spike.bin vectrex_spike_prom.vhd
--make_vhdl_prom 	startrek.bin vectrex_startrek_prom.vhd
--make_vhdl_prom 	vecmania1.bin vectrex_vecmania1_prom.vhd
--make_vhdl_prom 	webwars.bin vectrex_webwars_prom.vhd
--make_vhdl_prom 	wotr.bin vectrex_wotr_prom.vhd
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
--use work.usb_report_pkg.all;

entity vectrex_tn20k is
  port(
    clk     : in std_logic;
    led     : out std_logic_vector(5 downto 0);
    sw1     : in std_logic;
    sw2     : in std_logic;

    -- Dualshock game controller
    joystick_clk2   : out std_logic;
    joystick_mosi2  : out std_logic;
    joystick_miso2  : in  std_logic;
    joystick_cs2    : out std_logic;

    vout_b     : out std_logic;
    vout_g     : out std_logic;
    vout_r     : out std_logic;
    vout_vs    : out std_logic;
    vout_hs    : out std_logic;
    aout_l     : out std_logic;
    aout_r     : out std_logic;
    aout_m     : out std_logic;

    -- DAC
    dac_cs_n   : out std_logic;
    dac_clk    : out std_logic;
    dac_sd     : out std_logic;
    dac_ld_n   : out std_logic;
    beam_z     : out std_logic;
    beam_z_n   : out std_logic
    );
end vectrex_tn20k;

architecture struct of vectrex_tn20k is

  signal clock_12p5 : std_logic;
  signal clock_25   : std_logic;
  signal reset      : std_logic;

  constant CLOCK_FREQ : integer := 27E6;
  signal counter_clk: std_logic_vector(25 downto 0);
  signal clock_4hz : std_logic;
  
-- signal max3421e_clk : std_logic;
  signal r         : std_logic_vector(3 downto 0);
  signal g         : std_logic_vector(3 downto 0);
  signal b         : std_logic_vector(3 downto 0);
  signal csync     : std_logic;
  signal hsync     : std_logic;
  signal vsync     : std_logic;
  signal blankn    : std_logic;
  
  signal vga_r     : std_logic;
  signal vga_g     : std_logic;
  signal vga_b     : std_logic;
  signal vga_hs    : std_logic;
  signal vga_vs    : std_logic;

  signal beam_x    : unsigned(8 downto 0);
  signal beam_y    : unsigned(8 downto 0);
  signal beam_z_buf: std_logic;
  signal beam_z_buf2 : std_logic;
  
  signal audio           : std_logic_vector( 9 downto 0);
  signal pwm_accumulator : std_logic_vector(12 downto 0);

--  alias reset         : std_logic is sw1;
  signal pwm_audio_out_l : std_logic;
  signal pwm_audio_out_r : std_logic;

  signal pot_x : signed(7 downto 0);
  signal pot_y : signed(7 downto 0);
  signal pot_speed_cnt : std_logic_vector(15 downto 0);
  
  signal dbg_cpu_addr : std_logic_vector(15 downto 0);

  signal btn1_1  : std_logic;
  signal btn2_1  : std_logic;
  signal btn3_1  : std_logic;
  signal btn4_1  : std_logic;
  signal right_1 : std_logic;
  signal left_1  : std_logic;
  signal up_1    : std_logic;
  signal down_1  : std_logic;

-- for debug
  signal led_mode : std_logic_vector(1 downto 0);
  signal sw2_cnt  : std_logic_vector(23 downto 0);
  constant SW_WAIT : integer := (27E6 / 1000)*50; -- 50ms
    
--  dualshock buttons:
--  joy_rx[0][7:0]=(L D R U Start R3 L3 Select)
--  jpy_rx[1][7:0]=(4(square) 3(cross) 2(circle) 1(triangle) R1 L1 R2 L2)
--  Vectrex buttons:
--  vec_btn[7:0]  =(R L D U 1 2 3 4)

-- Dualshock controller
--  Generate sclk
  signal  sclk : std_logic; --  250kHz clock
  signal sclk_cnt : std_logic_vector(6 downto 0);

  signal joy_rx2_0 : std_logic_vector(7 downto 0);
  signal joy_rx2_1 : std_logic_vector(7 downto 0);
  signal joy_rx2_2 : std_logic_vector(7 downto 0);
  signal joy_rx2_3 : std_logic_vector(7 downto 0);
  signal joy_rx2_4 : std_logic_vector(7 downto 0);
  signal joy_rx2_5 : std_logic_vector(7 downto 0);

begin
--reset <= not reset_n;
  reset <= sw1;
  clock_25 <= clk;

  process (reset, clock_25)
  begin
    if reset='1' then
      clock_12p5 <= '0';
    else 
      if rising_edge(clock_25) then
        clock_12p5  <= not clock_12p5;
      end if;
    end if;
  end process;

  -- Dualshock controller
  -- Generate sclk
  process(clk)
  begin
    if rising_edge(clk) then
      if ( sclk_cnt = 54 - 1 ) then -- (27M / 250k /2) = 54
        sclk <= not sclk;
        sclk_cnt <= "0000000";
      else
        sclk_cnt <= sclk_cnt + 1;
      end if;
    end if;
  end process;
  
  controller2 : entity work.dualshock_controller
    port map (
      I_CLK250K => (sclk),
      I_RSTn    => ('1'),
      O_psCLK   => (joystick_clk2),
      O_psSEL   => (joystick_cs2),
      O_psTXD   => (joystick_mosi2),
      I_psRXD   => (joystick_miso2),
      O_RXD_1   => (joy_rx2_0),
      O_RXD_2   => (joy_rx2_1),
      O_RXD_3   => (joy_rx2_2),
      O_RXD_4   => (joy_rx2_3),
      O_RXD_5   => (joy_rx2_4),
      O_RXD_6   => (joy_rx2_5),
      I_CONF_SW => ('0'),  I_MODE_SW => ('1'), I_MODE_EN => ('0'),
      I_VIB_SW  => ("00"), I_VIB_DAT => ("11111111")     -- no vibration
      );
  right_1 <= not joy_rx2_0(5);
  left_1  <= not joy_rx2_0(7);
  down_1  <= not joy_rx2_0(6);
  up_1    <= not joy_rx2_0(4);
  btn1_1  <= not joy_rx2_1(4);
  btn2_1  <= not joy_rx2_1(5);
  btn3_1  <= not joy_rx2_1(6);
  btn4_1  <= not joy_rx2_1(7);

  dac : entity work.mcp4922
    port map (
      I_clk    => (clk),
      I_dataA  => (std_logic_vector(beam_x(8 downto 0)) & "000"),
      I_dataB  => (std_logic_vector(beam_y(8 downto 0)) & "000"),
      I_we     => ('1'),
      O_sclk   => (dac_clk),
      O_sd     => (dac_sd),
      O_cs_n   => (dac_cs_n),
      O_ldac_n => (dac_ld_n)
      );
      -- for_debug:
  process(clk)
  begin
    if rising_edge(clk) then
      if( sw2 = '1') then
        if(sw2_cnt = SW_WAIT) then
          led_mode <= led_mode + 1;
          sw2_cnt <= "000000000000000000000000";
        end if;
      elsif (sw2_cnt /= SW_WAIT) then
        sw2_cnt <= sw2_cnt + 1;
      end if;
    end if;
  end process;
  
  process(reset, clk)
  begin
    if reset = '1' then
      clock_4hz <= '0';
      counter_clk <= (others => '0');
    else
      if rising_edge(clk) then
        if counter_clk = CLOCK_FREQ/8 then
          counter_clk <= (others => '0');
          clock_4hz <= not clock_4hz;
          case led_mode is
            when "00" => led <= not std_logic_vector(beam_x(8 downto 3));
--            when "00" => led <= not dbg_cpu_addr(9 downto 4);
            when "01" => led <= not (up_1 & down_1 & left_1 & right_1 & "00");
            when "10" => led <= not (btn1_1 & btn2_1 & btn3_1 & btn4_1 & "00");
            when others => led <= not("000000");
          end case;
        else
          counter_clk <= counter_clk + 1;
        end if;
      end if;
    end if;
  end process;

-- vectrex
  vectrex : entity work.vectrex
    port map(
      clock_24  => clock_25,  
      clock_12  => clock_12p5,
      reset     => reset,
      
      video_r      => r,
      video_g      => g,
      video_b      => b,
      video_csync  => csync,
      video_blankn => blankn,
      video_hs     => hsync,
      video_vs     => vsync,

      beam_x => beam_x,
      beam_y => beam_y,
      beam_z => beam_z_buf,
      beam_z2 => beam_z_buf2,

      audio_out    => audio,
      
      rt_1      => btn4_1,
      lf_1      => btn3_1,
      dn_1      => btn2_1,
      up_1      => btn1_1,
      pot_x_1   => pot_x,
      pot_y_1   => pot_y,

      rt_2      => '0',
      lf_2      => '0',
      dn_2      => '0',
      up_2      => '0',
      pot_x_2   => pot_x,
      pot_y_2   => pot_y,

-- leds       => open,
      
      speakjet_cmd => open,
      speakjet_rdy => '0',
      speakjet_pwm => '0',
      
      external_speech_mode => "00",  -- "00" : no speech synth. "01" : sp0256. "10" : speakjet.  

      dbg_cpu_addr => dbg_cpu_addr,
      sw => "00000000"
      );

  pot_x <= "01111111" when left_1 = '0' and right_1 = '1' else
           "10000000" when left_1 = '1' and right_1 = '0' else
           "00000000";
  pot_y <= "01111111" when up_1 = '1' and down_1 = '0' else
           "10000000" when up_1 = '0' and down_1 = '1' else
           "00000000";

  vga_r <= (r(3) or r(2) or r(1) or r(0)) when blankn = '1' else '0';
  vga_g <= (g(3) or g(2) or g(1) or g(0)) when blankn = '1' else '0';
  vga_b <= (b(3) or b(2) or b(1) or b(0)) when blankn = '1' else '0';

-- synchro composite/ synchro horizontale
--vga_hs <= csync;
  vga_hs <= hsync;
-- commutation rapide / synchro verticale
--vga_vs <= '1';
  vga_vs <= vsync;

  vout_b  <= vga_b or vga_r; -- force red frame_line to white
  vout_g  <= vga_g or vga_r; -- force red frame_line to white
  vout_r  <= vga_r;
  vout_vs <= vga_vs;
  vout_hs <= vga_hs;
  aout_l  <= pwm_audio_out_l;
  aout_r  <= pwm_audio_out_r;
  aout_m  <= pwm_audio_out_l or pwm_audio_out_r;

  beam_z   <=     beam_z_buf when sw2 = '0' else     beam_z_buf2; 
  beam_z_n <= not beam_z_buf when sw2 = '0' else not beam_z_buf2;
  
--led(5 downto 0) <= not gpin(5 downto 0);

--sound_string <= "00" & audio & "000" & "00" & audio & "000";

-- get scancode from keyboard

--
--sample_data <= "00" & audio & "000" & "00" & audio & "000";				

-- Clock 1us for ym_8910

--p_clk_1us_p : process(max10_clk1_50)
--begin
--	if rising_edge(max10_clk1_50) then
--		if cnt_1us = 0 then
--			cnt_1us  <= 49;
--			clk_1us  <= '1'; 
--		else
--			cnt_1us  <= cnt_1us - 1;
--			clk_1us <= '0'; 
--		end if;
--	end if;	
--end process;	 

-- sgtl5000 (teensy audio shield on top of usb host shield)

--e_sgtl5000 : entity work.sgtl5000_dac
--port map(
-- clock_18   => clock_18,
-- reset      => reset,
-- i2c_clock  => clk_1us,  
--
-- sample_data  => sample_data,
-- 
-- i2c_sda   => arduino_io(0), -- i2c_sda, 
-- i2c_scl   => arduino_io(1), -- i2c_scl, 
--
-- tx_data   => arduino_io(2), -- sgtl5000 tx
-- mclk      => arduino_io(4), -- sgtl5000 mclk 
-- 
-- lrclk     => arduino_io(3), -- sgtl5000 lrclk
-- bclk      => arduino_io(6), -- sgtl5000 bclk   
-- 
-- -- debug
-- hex0_di   => open, -- hex0_di,
-- hex1_di   => open, -- hex1_di,
-- hex2_di   => open, -- hex2_di,
-- hex3_di   => open, -- hex3_di,
-- 
-- sw => sw(7 downto 0)
--);

-- pwm sound output

  process(clock_12p5)  -- use same clock as sound process
  begin
    if rising_edge(clock_12p5) then
      pwm_accumulator  <=  std_logic_vector(unsigned("0" & pwm_accumulator(11 downto 0)) + unsigned(audio & "00"));
    end if;
  end process;

  pwm_audio_out_l <= pwm_accumulator(12);
  pwm_audio_out_r <= pwm_accumulator(12); 

-- speakjet pwm direct to audio pwm 
--pwm_audio_out_l <= arduino_io(2);
--pwm_audio_out_r <= arduino_io(2);


end struct;
