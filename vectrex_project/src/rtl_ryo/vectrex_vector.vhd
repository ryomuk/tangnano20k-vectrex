-------------------------------------------------------------------------------
-- vectrex_vector.vhd
--
-- modified by Ryo Mukai to output beam parameters for XY monitor
-- deleted raster output
-- deleted speech simulation
-- from vectrex.vhd by Dar
-------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Vectrex by Dar (darfpga@aol.fr) (27/12/2017)
-- http://darfpga.blogspot.fr
-------------------------------------------------------------------------------
--  
-- Vectrex releases
--
-- Release 0.2 - 12/06/2018 - Dar
--	delays ramp related signals w.r.t. blank signal 
--	result is not perfect but clean sweep maze is much more correct and playable
--
-- Release 0.1 - 05/05/2018 - Dar
--	add sp0256-al2 VHDL speech simulation
--	add speakjet interface (speech IC)
--
-- Release 0.0 - 10/02/2018 - Dar
--	initial release
-------------------------------------------------------------------------------
-- SP0256-al2 prom decoding scheme and speech synthesis algorithm are from :
--
-- Copyright Joseph Zbiciak, all rights reserved.
-- Copyright tim lindner, all rights reserved.
--
-- See C source code and license in sp0256.c from MAME source
--
-- VHDL code is by Dar.
-------------------------------------------------------------------------------
-- gen_ram.vhd & io_ps2_keyboard
-- Copyright 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)
-- http://www.syntiac.com/fpga64.html
-------------------------------------------------------------------------------
-- VIA m6522
-- Copyright (c) MikeJ - March 2003
-- + modification
-------------------------------------------------------------------------------
-- YM2149 (AY-3-8910)
-- Copyright (c) MikeJ - Jan 2005
-------------------------------------------------------------------------------
-- cpu09l_128
-- Copyright (C) 2003 - 2010 John Kent
-- + modification 
-------------------------------------------------------------------------------
-- Vectrex beam control hardware
--   Uses via port_A, dac and capacitor to set beam x/y displacement speed
--   when done beam displacement is released (port_B_7 = 0)
--   beam displacement duration is controled by Timer 1 (that drive port_B_7)
--   or by 6809 instructions execution duration.
--
--   Uses via port_A, dac and capacitor to set beam intensity before displacment

--   Before drawing any object (or text) the beam position is reset to screen center. 
--   via_CA2 is used to reset beam position.
--
--	  Uses via_CB2 to set pen ON/OFF. CB2 is always driven by via shift register (SR)
--   output. SR is loaded with 0xFF for plain line drawing. SR is loaded with 0x00
--   for displacement with no drawing. SR is loaded with characters graphics 
--   (character by character and line by line). SR is ALWAYS used in one shot mode
--   although SR bits are recirculated, SR shift stops on the last data bit (and 
--   not on the first bit of data recirculated)
--
--   Exec_rom uses line drawing with Timer 1 and FF/00 SR loading (FF or 00 with
--   recirculation always output respectively 1 or 0). Timer 1 timeout is checked
--   by software polling loop.
--
--	  Exec_rom draw characters in the following manner : start displacement and feed
--   SR with character grahics (at the right time) till the end of the complete line.
--   Then move down one line and then backward up to the begining of the next line 
--   with no drawing. Then start drawing the second line... ans so on 7 times. 
--   CPU has enough time to get the next character and the corresponding graphics 
--   line data between each SR feed. T1 is not used.
--   
--   Most games seems to use those exec_rom routines.
--
--   During cut scene of spike sound sample have to be interlaced (through dac) while
--   drawing. Spike uses it's own routine for that job. That routine prepare drawing
--   data (graphics and vx/vy speeds) within working ram before cut scene start to be
--   able to feed sound sample between each movement segment. T1 and SR are used but 
--   T1 timeout is not check. CPU expect there is enough time from T1 start to next 
--   dac modification (dac ouput is alway vx during move). Modifying dac before T1 
--   timeout will corrupt drawing. eg : when starting from @1230 (clr T1h), T1 must
--   have finished before reaching @11A4 (put sound sample value on dac). Drawing
--   characters with this routine is done by going backward between each character
--   graphic. Beam position is reset to screen center after/before each graphic line.
--   one sound sample is sent to dac after each character graphic.

-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity vectrex is
port
(
	clock_12     : in std_logic;
	reset        : in std_logic;
	 
        beam_x : out std_logic_vector(8 downto 0);
        beam_y : out std_logic_vector(8 downto 0);
        beam_z : out std_logic_vector(7 downto 0);

        audio_out    : out std_logic_vector(9 downto 0);
		
	up_1      : in std_logic;
	dn_1      : in std_logic;
	lf_1      : in std_logic;
	rt_1      : in std_logic;
	pot_x_1   : in signed(7 downto 0);
	pot_y_1   : in signed(7 downto 0);

	up_2      : in std_logic;
	dn_2      : in std_logic;
	lf_2      : in std_logic;
	rt_2      : in std_logic;
	pot_x_2   : in signed(7 downto 0);
	pot_y_2   : in signed(7 downto 0);

        cart_num  : in std_logic_vector(1 downto 0)
  );
end vectrex;

architecture syn of vectrex is

--------------------------------------------------------------
-- Configuration
--------------------------------------------------------------
-- Select catridge rom around line 700
--------------------------------------------------------------
-- vertical display (comment/uncomment whole section)
-------------------
-- constant horizontal_display : integer := 0;
 constant max_h           : integer := 312; -- have to be multiple of 4
 constant max_v           : integer := 416;
 constant max_x           : integer := 22500*8;
 constant max_y           : integer := 16875*8;
--------------------------------------------------------------
 
 signal clock_div : std_logic_vector(2 downto 0) := "000";
 signal reset_n   : std_logic;

 signal cpu_clock  : std_logic;
 signal cpu_addr   : std_logic_vector(15 downto 0);
 signal cpu_di     : std_logic_vector( 7 downto 0);
 signal cpu_do     : std_logic_vector( 7 downto 0);
 signal cpu_rw     : std_logic;
 signal cpu_irq    : std_logic;
 signal cpu_firq   : std_logic;
 signal cpu_ifetch : std_logic;
 signal cpu_fetch  : std_logic;

 signal ram_cs   : std_logic;
 signal ram_do   : std_logic_vector( 7 downto 0);
 signal ram_we   : std_logic;

 signal rom_cs   : std_logic;
 signal rom_do   : std_logic_vector( 7 downto 0);

 signal cart_cs  : std_logic;
 signal cart_do  : std_logic_vector( 7 downto 0);

 signal cart_num_latch : std_logic_vector(1 downto 0);
 signal cart_do0 : std_logic_vector( 7 downto 0);
 signal cart_do1 : std_logic_vector( 7 downto 0);
 signal cart_do2 : std_logic_vector( 7 downto 0);
 signal cart_do3 : std_logic_vector( 7 downto 0);

 signal via_cs_n  : std_logic;
 signal via_do    : std_logic_vector(7 downto 0);
 signal via_ca1_i : std_logic;
 signal via_ca2_o : std_logic;
 signal via_cb2_o : std_logic;
 signal via_pa_i  : std_logic_vector(7 downto 0);
 signal via_pa_o  : std_logic_vector(7 downto 0);
 signal via_pb_i  : std_logic_vector(7 downto 0);
 signal via_pb_o  : std_logic_vector(7 downto 0);
 signal via_irq_n : std_logic;
 signal via_en_4  : std_logic;
 
 type delay_buffer_t is array(0 to 255) of std_logic_vector(17 downto 0);
 signal delay_buffer : delay_buffer_t;

 signal via_ca2_o_d : std_logic;
 signal via_cb2_o_d : std_logic;
 signal via_pa_o_d  : std_logic_vector(7 downto 0);
 signal via_pb_o_d  : std_logic_vector(7 downto 0);

 signal sh_dac            : std_logic;
 signal dac_mux           : std_logic_vector(2 downto 1);
 signal zero_integrator_n : std_logic;
 signal ramp_integrator_n : std_logic;
 
 signal beam_blank_n : std_logic; 

 signal dac       : signed(8 downto 0);
 signal dac_y     : signed(8 downto 0);
 signal dac_z     : unsigned(7 downto 0);
 signal ref_level : signed(8 downto 0);
-- signal z_level   : std_logic_vector(1 downto 0);
 signal dac_sound : std_logic_vector(7 downto 0);
 
 signal integrator_x : signed(19 downto 0);
 signal integrator_y : signed(19 downto 0);

 signal shifted_x : signed(19 downto 0);
 signal shifted_y : signed(19 downto 0);

 signal limited_x : unsigned(19 downto 0);
 signal limited_y : unsigned(19 downto 0);

 signal beam_h : unsigned(9 downto 0);
 signal beam_v : unsigned(9 downto 0);
  
 constant offset_y : integer := 0;
 constant offset_x : integer := 0;
 
 constant scale_x : integer := max_v*256*256/(2*max_x); 
 constant scale_y : integer := max_h*256*256/(2*max_y);
 
 signal phase : std_logic_vector(1 downto 0);
 
 signal ay_do          : std_logic_vector(7 downto 0);
 signal ay_audio_muxed : std_logic_vector(7 downto 0);
 signal ay_audio_chan  : std_logic_vector(1 downto 0);
 signal ay_chan_a      : std_logic_vector(7 downto 0);
 signal ay_chan_b      : std_logic_vector(7 downto 0);
 signal ay_chan_c      : std_logic_vector(7 downto 0);
 signal ay_ioa_oe      : std_logic;
 
 signal pot     : signed(7 downto 0);
 signal compare : std_logic;
 signal players_switches : std_logic_vector(7 downto 0);
 
 signal audio_1        : std_logic_vector(9 downto 0);
 
begin

-- clocks
  reset_n <= not reset;
  
  process (clock_12, reset)
  begin
    if rising_edge(clock_12) then
      if clock_div = "111" then 
        clock_div <= "000";
      else
        clock_div <= clock_div + '1';
      end if;
    end if;
  end process;

  via_en_4  <= clock_div(0);
  cpu_clock <= clock_div(2);

--static ADDRESS_MAP_START(vectrex_map, AS_PROGRAM, 8, vectrex_state )
--	AM_RANGE(0x0000, 0x7fff) AM_NOP // cart area, handled at machine_start
--	AM_RANGE(0xc800, 0xcbff) AM_RAM AM_MIRROR(0x0400) AM_SHARE("gce_vectorram")
--	AM_RANGE(0xd000, 0xd7ff) AM_READWRITE(vectrex_via_r, vectrex_via_w)
--	AM_RANGE(0xe000, 0xffff) AM_ROM AM_REGION("maincpu", 0)
--ADDRESS_MAP_END

-- chip select
  cart_cs  <= '1' when cpu_addr(15) = '0' else '0'; 	
  ram_cs   <= '1' when cpu_addr(15 downto 12) = X"C"  else '0'; 
  via_cs_n <= '0' when cpu_addr(15 downto 12) = X"D"  else '1'; 
  rom_cs   <= '1' when cpu_addr(15 downto 13) = "111" else '0'; 
	
-- write enable working ram
  ram_we <=   '1' when cpu_rw = '0' and ram_cs = '1' else '0';

-- misc
  cpu_irq <= not via_irq_n;
  cpu_firq <= '0';

  cpu_di <= cart_do when cart_cs  = '1' else
            ram_do  when ram_cs   = '1' else
            via_do  when via_cs_n = '0' else
            rom_do  when rom_cs   = '1' else
            X"00";

  via_pa_i <= ay_do;
  via_pb_i <= "00"&compare&"00000";

-- players controls / + speech serial handshake in speech mode
  players_switches <= not(rt_2&lf_2&dn_2&up_2&rt_1&lf_1&dn_1&up_1);
  
  with via_pb_o(2 downto 1) select  -- dac_mux but not delayed
    pot <= pot_x_1 when "00",
           pot_y_1 when "01",
           pot_x_2 when "10",
           pot_y_2 when others;
  
  compare <= '1' when (pot(7)&pot) > signed(via_pa_o(7)&via_pa_o) else '0'; -- dac but not delayed

-- beam control
  sh_dac            <= via_pb_o(0);
  dac_mux           <= via_pb_o(2 downto 1);
  zero_integrator_n <= via_ca2_o;
  ramp_integrator_n <= via_pb_o(7);
  beam_blank_n      <= via_cb2_o;
	 			 
  dac <= signed(via_pa_o(7)&via_pa_o);
  -- must ensure sign extension for 0x80 value to be used in integrator equation

  process (clock_12, reset)
    variable limit_n : std_logic;
  begin
    if reset='1' then
      null;
    else
      if rising_edge(clock_12) then
        
        if sh_dac = '0' then
          case dac_mux is
            when "00"   => dac_y     <= dac;
            when "01"   => ref_level <= dac;
            when "10"   => dac_z     <= unsigned(via_pa_o);
            when others => dac_sound <= via_pa_o;
          end case;
        end if;
        
        if zero_integrator_n = '0' then
          integrator_x <= (others=>'0');
          integrator_y <= (others=>'0');
        else
          if ramp_integrator_n = '0' then
            integrator_x <= integrator_x + (ref_level - dac_y); -- vertical display
            integrator_y <= integrator_y - (ref_level - dac);   -- vertical display
          end if;
        end if;
        
      -- set 'preserve registers' wihtin assignments editor to ease signaltap debuging
      
        shifted_x <= integrator_x+max_x-offset_x;
        shifted_y <= integrator_y+max_y-offset_y;
      
      -- limit and scaling should be enhanced
      
        limit_n := '1';
        if    shifted_x > 2*max_x then limited_x <= to_unsigned(2*max_x,20);
                                       limit_n := '0'; 
        elsif shifted_x < 0       then limited_x <= (others=>'0');
                                       limit_n := '0'; 
        else                           limited_x <= unsigned(shifted_x); end if;
        if    shifted_y > 2*max_y then limited_y <= to_unsigned(2*max_y,20);
                                       limit_n := '0'; 
        elsif shifted_y < 0       then limited_y <= (others=>'0');
                                       limit_n := '0'; 
        else                           limited_y <= unsigned(shifted_y); end if;
      
        -- integer computation to try making rounding computation during division 
      
        beam_v <= to_unsigned(to_integer(limited_x*to_unsigned(scale_x,10))/(256*256),10);
        beam_h <= to_unsigned(to_integer(limited_y*to_unsigned(scale_y,10))/(256*256),10);
      
      end if;
    end if;
  end process;

  beam_x <= std_logic_vector(beam_h(9 downto 1));
  beam_y <= std_logic_vector(beam_v(9 downto 1));
  beam_z <= std_logic_vector(dac_z) when beam_blank_n = '1' else (others=>'0');

-- sound	
  process (cpu_clock)
  begin
    if rising_edge(cpu_clock) then
      if ay_audio_chan = "00" then ay_chan_a <= ay_audio_muxed; end if;
      if ay_audio_chan = "01" then ay_chan_b <= ay_audio_muxed; end if;
      if ay_audio_chan = "10" then ay_chan_c <= ay_audio_muxed; end if;
    end if;	
  end process;

  audio_1  <= 	("00"&ay_chan_a) +
                ("00"&ay_chan_b) +
                ("00"&ay_chan_c) +
                ("00"&dac_sound);

  audio_out <=  "000"&audio_1(9 downto 3);

---------------------------
-- components
---------------------------			

-- microprocessor 6809
  main_cpu : entity work.cpu09
    port map(	
      clk      => cpu_clock,-- E clock input (falling edge)
      rst      => reset,    -- reset input (active high)
      vma      => open,     -- valid memory address (active high)
      lic_out  => open,     -- last instruction cycle (active high)
      ifetch   => cpu_ifetch, -- instruction fetch cycle (active high)
      opfetch  => cpu_fetch,-- opcode fetch (active high)
      ba       => open,     -- bus available (high on sync wait or DMA grant)
      bs       => open,     -- bus status (high on interrupt or reset vector fetch or DMA grant)
      addr     => cpu_addr, -- address bus output
      rw       => cpu_rw,   -- read not write output
      data_out => cpu_do,   -- data bus output
      data_in  => cpu_di,   -- data bus input
      irq      => cpu_irq,  -- interrupt request input (active high)
      firq     => cpu_firq, -- fast interrupt request input (active high)
      nmi      => '0',      -- non maskable interrupt request input (active high)
      halt     => '0',      -- halt input (active high) grants DMA
      hold_in  => '0'       -- hold input (active high) extend bus cycle
      );
  
  cpu_prog_rom : entity work.vectrex_exec_prom
    port map(
      clk  => cpu_clock,
      addr => cpu_addr(12 downto 0),
      data => rom_do
      );

--------------------------------------------------------------------
  -- latch cart_num on reset
  process (cpu_clock, reset)
  begin
    if rising_edge(cpu_clock) then
      if reset='1' then
        cart_num_latch <= cart_num;
      end if;
    end if;
  end process;
    
--cart_do <= (others => '0');  -- no cartridge
  with cart_num_latch(1 downto 0) select -- cart select
    cart_do <= cart_do0 when "00",
               cart_do1 when "01",
               cart_do2 when "10",
               cart_do3 when others;
  
  cart_rom0 : entity work.vectrex_testrev4_prom        -- 4k 
    port map(
      clk  => cpu_clock,
      addr => cpu_addr(11 downto 0), -- 4k
      data => cart_do0
      );

  cart_rom1 : entity work.vectrex_scramble_prom        -- 4k 
    port map(
      clk  => cpu_clock,
      addr => cpu_addr(11 downto 0), -- 4k
      data => cart_do1
      );
  cart_rom2 : entity work.vectrex_starhawk_prom        -- 4k 
    port map(
      clk  => cpu_clock,
      addr => cpu_addr(11 downto 0), -- 4k
      data => cart_do2
      );
  cart_do3 <= (others => '0');  -- no cartridge


--------------------------------------------------------------------

  working_ram : entity work.gen_ram
    generic map( dWidth => 8, aWidth => 10)
    port map(
      clk  => cpu_clock,
      we   => ram_we,
      addr => cpu_addr(9 downto 0),
      d    => cpu_do,
      q    => ram_do
      );

  via6522_inst : entity work.M6522
    port map(
      I_RS            => cpu_addr(3 downto 0),
      I_DATA          => cpu_do,
      O_DATA          => via_do,
      O_DATA_OE_L     => open,

      I_RW_L          => cpu_rw,
      I_CS1           => cpu_addr(12),
      I_CS2_L         => via_cs_n,

      O_IRQ_L         => via_irq_n,

      -- port a
      I_CA1           => via_ca1_i,
      I_CA2           => '0',
      O_CA2           => via_ca2_o,
      O_CA2_OE_L      => open,

      I_PA            => via_pa_i,
      O_PA            => via_pa_o,
      O_PA_OE_L       => open,

      -- port b
      I_CB1           => '0',
      O_CB1           => open,
      O_CB1_OE_L      => open,

      I_CB2           => '0',
      O_CB2           => via_cb2_o,
      O_CB2_OE_L      => open,

      I_PB            => via_pb_i,
      O_PB            => via_pb_o,
      O_PB_OE_L       => open,

      RESET_L         => reset_n,
      CLK             => clock_12,
      I_P2_H          => cpu_clock,    -- high for phase 2 clock  ____----__
      ENA_4           => via_en_4      -- 4x system clock (4HZ)   _-_-_-_-_-
      );

-- AY-3-8910
  ay_3_8910_2 : entity work.YM2149
    port map(
      -- data bus
      I_DA       => via_pa_o,    -- in  std_logic_vector(7 downto 0);
      O_DA       => ay_do,     -- out std_logic_vector(7 downto 0);
      O_DA_OE_L  => open,      -- out std_logic;
      -- control
      I_A9_L     => '0',       -- in  std_logic;
      I_A8       => '1',       -- in  std_logic;
      I_BDIR     => via_pb_o(4),  -- in  std_logic;
      I_BC2      => '1',       -- in  std_logic;
      I_BC1      => via_pb_o(3),   -- in  std_logic;
      I_SEL_L    => '0',       -- in  std_logic;

      O_AUDIO    => ay_audio_muxed, -- out std_logic_vector(7 downto 0);
      O_CHAN     => ay_audio_chan,  -- out std_logic_vector(1 downto 0);
      
      -- port a
      I_IOA      => players_switches, -- in  std_logic_vector(7 downto 0);
      O_IOA      => open,             -- out std_logic_vector(7 downto 0);
      O_IOA_OE_L => ay_ioa_oe,        -- out std_logic;
      -- port b
      I_IOB      => (others => '0'), -- in  std_logic_vector(7 downto 0);
      O_IOB      => open,            -- out std_logic_vector(7 downto 0);
      O_IOB_OE_L => open,            -- out std_logic;

      ENA        => '1', --cpu_ena,  -- in  std_logic; -- clock enable for higher speed operation
      RESET_L    => reset_n,         -- in  std_logic;
      CLK        => cpu_clock        -- in  std_logic  -- note 6 Mhz
      );

end SYN;
