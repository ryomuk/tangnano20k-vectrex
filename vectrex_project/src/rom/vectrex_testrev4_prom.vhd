library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity vectrex_testrev4_prom is
port (
  clk  : in  std_logic;
  addr : in  std_logic_vector(11 downto 0);
  data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of vectrex_testrev4_prom is
  type rom is array(0 to 4095) of std_logic_vector(7 downto 0);
  signal rom_data: rom := (
--
-- insert ROM code here
--
  );
begin
process(clk)
begin
  if rising_edge(clk) then
    data <= rom_data(to_integer(unsigned(addr)));
  end if;
end process;
end architecture;
