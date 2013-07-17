library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.genram_pkg.all;
use work.wb_irq_pkg.all;

entity wb_irq_slave is
  generic (g_irq_lines  : natural := 8;
           g_ivec_table : t_ivec_array_d
  );
  port    (clk_i         : std_logic;
           rst_n_i       : std_logic; 
           irql_o        : out std_logic_vector(g_irq_lines-1 downto 0);
           slave_o       : out t_wishbone_slave_out;
           slave_i       : in  t_wishbone_slave_in
  );
end entity;

architecture behavioral of wb_irq_slave is

begin

slave_o.rty <= '0';
slave_o.err <= '0';
slave_o.dat <= (others => '0');
slave_o.stall <= '0';

-------------------------------------------------------------------------
--input rs flipflops
-------------------------------------------------------------------------
G1: for I in 0 to g_irq_lines-1 generate
  process(clk_i, rst_n_i)
  begin
    if(rst_n_i = '0') then
         irql_o(I) <= '0';
    elsif (rising_edge(clk_i)) then
      if(slave_i.cyc = '1' and slave_i.stb  = '1' and (slave_i.dat = g_ivec_table(I))) then
        irql_o(I) <= '1';
      else
        irql_o(I) <= '0';
      end if;
    end if;
  end process;
end generate;  

  process(clk_i)
  begin
      if rising_edge(clk_i) then
        slave_o.ack <= '0';
        if(slave_i.cyc = '1' and slave_i.stb = '1') then
          slave_o.ack <= '1';
        end if;  
      end if;
  end process;
  
end architecture;
