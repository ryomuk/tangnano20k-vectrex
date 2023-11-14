#!/usr/bin/perl
use strict;
use warnings;

my $file = $ARGV[0];
open my $fh, "<", $file or die $!;
binmode($fh);

my $ROMNAME = "xxxx";
my $ROMSIZE = 4096;
my $ADDSIZE = log($ROMSIZE)/log(2);
my $buf;
my $data;

print
"library ieee;\n".
"use ieee.std_logic_1164.all,ieee.numeric_std.all;\n".
"\n".
"entity vectrex_".$ROMNAME."_prom is\n".
"port (\n".
"  clk  : in  std_logic;\n".
"  addr : in  std_logic_vector(".($ADDSIZE-1)." downto 0);\n".
"  data : out std_logic_vector(7 downto 0)\n".
");\n".
"end entity;\n".
"\n".
"architecture prom of vectrex_".$ROMNAME."_prom is\n".
"  type rom is array(0 to ".($ROMSIZE-1).") of std_logic_vector(7 downto 0);\n".
"  signal rom_data: rom := (\n";

for(my $addr = 0; $addr < $ROMSIZE; $addr++){
    if($addr % 16 == 0){
	printf "    ";
    }
    if(sysread($fh, $buf, 1)){
	$data = unpack("C", $buf);
    } else {
	$data = 0;
    }
    printf("X\"%02X\"", $data);
    if($addr != $ROMSIZE-1){
	printf ",";
    }
    if($addr % 16 == 15){
	printf "\n";
    }
}
print
"  );\n".
"begin\n".
"process(clk)\n".
"begin\n".
"  if rising_edge(clk) then\n".
"    data <= rom_data(to_integer(unsigned(addr)));\n".
"  end if;\n".
"end process;\n".
"end architecture;\n";

close $fh;
    
