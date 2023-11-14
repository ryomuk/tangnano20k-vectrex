-------------------------------------------------------------------------------
-- vectrex_tn20k.vhd
--
-- Tang Nano 20K top level module for vectrex
-- by Ryo Mukai (github.com/ryomuk)
-- 2023/11/08
-- 
-- modified from vectrex_de10_lite.vhd by Dar
-------------------------------------------------------------------------------
-- Main features :
--   * Output X, Y vector and Z intensity data for MCP4911 DAC
--   * No raster output
--   * PCM audio output
--   * Dualshock analog controller
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
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
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;

entity vectrex_tn20k is
  port(
    sclk    : in std_logic; -- 27MHz system clock
    led     : out std_logic_vector(5 downto 0); -- negative logic (lit on 0)
    sw1     : in std_logic; -- positive logic (1 on push)
    sw2     : in std_logic; -- positive logic (1 on push)

    -- Dualshock game controller
    -- TangNano 20K's Joystick1 port is used for onboard LEDs,
    -- so joystick is connected to joystick2 port.
    joystick_clk2   : out std_logic;
    joystick_mosi2  : out std_logic;
    joystick_miso2  : in  std_logic;
    joystick_cs2    : out std_logic;

    -- PWM Audio
    audio_pwm  : out std_logic;

    -- DAC
    dac_clk     : out std_logic;
    dac_cs_n    : out std_logic;
    dac_ld_n    : out std_logic;
    dac_sd0     : out std_logic;
    dac_sd1     : out std_logic;
    dac_sd2     : out std_logic;

    debug       : out std_logic
    );
end vectrex_tn20k;

architecture struct of vectrex_tn20k is

  signal reset      : std_logic;
  signal reset_n    : std_logic;
  signal reset_cnt  : std_logic_vector(15 downto 0) := (others =>'0');
  constant RESET_WIDTH : integer := 27_000; -- clock count (=1ms)
    
  constant FREQ_SCLK : integer := 27_000_000;
  signal cnt_4Hz   : std_logic_vector(25 downto 0) := (others =>'0');
  signal clk_4Hz   : std_logic := '0';
  signal clk_12M   : std_logic := '0';
  signal clk_dac   : std_logic := '0';
  
  signal beam_x    : std_logic_vector(8 downto 0);
  signal beam_y    : std_logic_vector(8 downto 0);
  signal beam_z    : std_logic_vector(7 downto 0);

  signal dac_x     : std_logic_vector(9 downto 0);
  signal dac_y     : std_logic_vector(9 downto 0);
  signal dac_z     : std_logic_vector(9 downto 0);
  
  signal audio           : std_logic_vector( 9 downto 0);
  signal pwm_accumulator : std_logic_vector(12 downto 0);

-- player1
  signal pot_x_1 : signed(7 downto 0);
  signal pot_y_1 : signed(7 downto 0);
  signal right_1 : std_logic;
  signal left_1  : std_logic;
  signal up_1    : std_logic;
  signal down_1  : std_logic;
  signal btn1_1  : std_logic;
  signal btn2_1  : std_logic;
  signal btn3_1  : std_logic;
  signal btn4_1  : std_logic;
-- player2
  signal pot_x_2 : signed(7 downto 0);
  signal pot_y_2 : signed(7 downto 0);
  signal btn1_2  : std_logic;
  signal btn2_2  : std_logic;
  signal btn3_2  : std_logic;
  signal btn4_2  : std_logic;

-- for sw2
  constant SW_WAIT  : integer := (27_000_000 / 1000)*50; -- 50ms
  signal sw2_cnt    : std_logic_vector(23 downto 0) := (others =>'0');
  signal cart_num   : std_logic_vector(1 downto 0)  := "00";

-- Dualshock controller
--  Generate clk_ds250k
  signal clk_ds250k : std_logic := '0'; --  250kHz clock
  signal cnt_ds250k : std_logic_vector(6 downto 0) := (others =>'0');

  signal joy_rx2_0 : std_logic_vector(7 downto 0);
  signal joy_rx2_1 : std_logic_vector(7 downto 0);
  signal joy_rx2_2 : std_logic_vector(7 downto 0);
  signal joy_rx2_3 : std_logic_vector(7 downto 0);
  signal joy_rx2_4 : std_logic_vector(7 downto 0);
  signal joy_rx2_5 : std_logic_vector(7 downto 0);

  component Gowin_rPLL
    port (
      clkout: out std_logic;
      clkin: in std_logic
      );
  end component;
begin
  pll27Mto12M: Gowin_rPLL
    port map (
      clkout => clk_12M,
      clkin => sclk
      );

  -- Reset button and power on reset
  process(sclk)
  begin
    if rising_edge(sclk) then
      if(sw1 = '1') then
        reset <= '1';
        reset_cnt <= (others => '0');
      elsif (reset_cnt /= RESET_WIDTH) then
        reset <= '1';
        reset_cnt <= reset_cnt + 1;
      else
        reset <= '0';
      end if;
    end if;
  end process;
  reset_n <= not reset;
  
  -- Dualshock controller
  -- Generate clk_ds250k
  process(sclk)
  begin
    if rising_edge(sclk) then
      if ( cnt_ds250k = 54 - 1 ) then -- (27M / 250k /2) = 54
        clk_ds250k <= not clk_ds250k;
        cnt_ds250k <= (others => '0');
      else
        cnt_ds250k <= cnt_ds250k + 1;
      end if;
    end if;
  end process;
  
--  dualshock buttons:
--  joy_rx2_0=joy_rx[0][7:0]=(L D R U Start R3 L3 Select)
--  joy_rx2_1=joy_rx[1][7:0]=(4(square) 3(cross) 2(circle) 1(triangle) R1 L1 R2 L2)
--  joy_rx2_2=joy_rx[2][7:0]=Right Analog
--  joy_rx2_3=joy_rx[3][7:0]=Right Analog 
--  joy_rx2_4=joy_rx[4][7:0]=Left  Analog
--  joy_rx2_5=joy_rx[5][7:0]=Left  Analog
--  left:0x00, center:0x80, right: 0xff
--    up:0x00, center:0x80,  down: 0xff
-- dual shock buttons are negative logic ('0' on push)
--  Player1:
  btn1_1  <= not joy_rx2_1(4); -- 1(triangle)
  btn2_1  <= not joy_rx2_1(5); -- 2(circle)
  btn3_1  <= not joy_rx2_1(6); -- 3(cross)
  btn4_1  <= not joy_rx2_1(7); -- 4(square)
  right_1 <= not joy_rx2_0(5); -- R (digital)
  left_1  <= not joy_rx2_0(7); -- L (digital)
  down_1  <= not joy_rx2_0(6); -- D (digital)
  up_1    <= not joy_rx2_0(4); -- U (digital)

  pot_x_1 <= "01111111" when left_1 = '0' and right_1 = '1' else
             "10000000" when left_1 = '1' and right_1 = '0' else
             signed((not joy_rx2_4(7)) & joy_rx2_4(6 downto 0));
  pot_y_1 <= "01111111" when up_1 = '1' and down_1 = '0' else
             "10000000" when up_1 = '0' and down_1 = '1' else
             signed(joy_rx2_5(7)& (not joy_rx2_5(6 downto 0)));

--  Player2:
  btn1_2  <= not joy_rx2_1(2); -- L1
  btn2_2  <= not joy_rx2_1(3); -- R1
  btn3_2  <= not joy_rx2_1(0); -- L2
  btn4_2  <= not joy_rx2_1(1); -- R2
  pot_x_2 <= signed((not joy_rx2_2(7))&joy_rx2_2(6 downto 0));
  pot_y_2 <= signed(joy_rx2_3(7)& (not joy_rx2_3(6 downto 0)));
  
  controller2 : entity work.dualshock_controller
    port map (
      I_CLK250K => (clk_ds250k),
      I_RSTn    => (reset_n),
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
      I_CONF_SW => ('1'),
      I_MODE_SW => ('1'), -- Analog
      I_MODE_EN => ('1'),
      I_VIB_SW  => ("00"),
      I_VIB_DAT => ("11111111")     -- no vibration
      );

  clk_dac <= clk_12M;

-- center:
-- beam_x = "001001101" = 0x4d (0x00 to 0x9a(154))
-- beam_y = "001100110" = 0x66 (0x00 to 0xcc(204))
--  dac_x <= beam_x(8 downto 0) & "0";
--  dac_y <= beam_y(8 downto 0) & "0";
  dac_x <= beam_x(7 downto 0) & "00";
  dac_y <= beam_y(7 downto 0) & "00";
  dac_z <= "00" & beam_z(7 downto 0);
  
  dac : entity work.mcp4911x3
    port map (
      I_clk    => (clk_dac),
      I_data0  => (dac_x),
      I_data1  => (dac_y),
      I_data2  => (dac_z),
      I_header => ("0011"),
      I_we     => ('1'),
      O_sclk   => (dac_clk),
      O_cs_n   => (dac_cs_n),
      O_ldac_n => (dac_ld_n),
      O_sd0    => (dac_sd0),
      O_sd1    => (dac_sd1),
      O_sd2    => (dac_sd2)
      );

  -- for_debug:
  debug <= '0';
  process(sclk)
  begin
    if rising_edge(sclk) then
      if( sw2 = '1') then
        if(sw2_cnt = SW_WAIT) then
          cart_num <= cart_num + 1;
          sw2_cnt <= (others => '0');
        end if;
      elsif (sw2_cnt /= SW_WAIT) then
        sw2_cnt <= sw2_cnt + 1;
      end if;
    end if;
  end process;
  
  process(sclk)
  begin
    if rising_edge(sclk) then
      if cnt_4Hz = FREQ_SCLK/2/4 then
        cnt_4Hz <= (others => '0');
        clk_4Hz <= not clk_4Hz;
        led <= not (std_logic_vector(beam_x(8 downto 7)) &
                    std_logic_vector(beam_y(8 downto 7)) &
                    cart_num);
--        case cart_num is
--          when "00" => led <= not (joy_rx2_4(7 downto 4) & cart_num);
--          when "01" => led <= not (joy_rx2_4(3 downto 0) & cart_num);
--          when "10" => led <= not (joy_rx2_5(7 downto 4) & cart_num);
--          when "11" => led <= not (joy_rx2_5(3 downto 0) & cart_num);
--        end case;
--        led <= not reset_cnt(15 downto 10);
      else
        cnt_4Hz <= cnt_4Hz + 1;
      end if;
    end if;
  end process;

-- vectrex
  vectrex : entity work.vectrex
    port map(
      clock_12  => clk_12M,
      reset     => reset,
      
      beam_x => beam_x,
      beam_y => beam_y,
      beam_z => beam_z,
      
      audio_out    => audio,
      
      rt_1      => btn4_1,
      lf_1      => btn3_1,
      dn_1      => btn2_1,
      up_1      => btn1_1,
      pot_x_1   => pot_x_1,
      pot_y_1   => pot_y_1,

      rt_2      => btn4_2,
      lf_2      => btn3_2,
      dn_2      => btn2_2,
      up_2      => btn1_2,
      pot_x_2   => pot_x_2,
      pot_y_2   => pot_y_2,

      cart_num  => cart_num
      );

-- pwm sound output

  process(clk_12M)  -- use same clock as sound process
  begin
    if rising_edge(clk_12M) then
      pwm_accumulator  <=  std_logic_vector(
        unsigned("0" & pwm_accumulator(11 downto 0)) + unsigned(audio & "00"));
    end if;
  end process;

  audio_pwm  <= pwm_accumulator(12);

end struct;
