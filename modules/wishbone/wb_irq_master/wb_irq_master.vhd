library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.genram_pkg.all;
use work.wb_irq_pkg.all;

entity wb_irq_master is
  generic (g_irq_lines  : natural := 8;
           g_ivec_table : t_ivec_array_ad
  );
  port    (clk_i          : std_logic;
           rst_n_i        : std_logic; 
           irql_i         : in  std_logic_vector(g_irq_lines-1 downto 0);
           master_o       : out t_wishbone_master_out;
           master_i       : in  t_wishbone_master_in
  );
end entity;

architecture behavioral of wb_irq_master is

signal r_ffs_q : std_logic_vector(g_irq_lines-1 downto 0);
signal r_ffs_r : std_logic_vector(g_irq_lines-1 downto 0);
signal s_ffs_s : std_logic_vector(g_irq_lines-1 downto 0);
signal irq     : natural;

type t_state is (s_IDLE, s_LOOKUP, s_SEND, s_DONE);
signal r_state    : t_state;
signal s_master_o   : t_wishbone_master_out;

begin

-------------------------------------------------------------------------
--input rs flipflops
-------------------------------------------------------------------------
G1: for I in 0 to g_irq_lines-1 generate
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if(rst_n_i = '0') then
         r_ffs_q(I) <= '0';
      else 
        if(s_ffs_s(I) = '0' and r_ffs_r(I) = '1') then
          r_ffs_q(I)  <= '0';
        elsif(s_ffs_s(I) = '1' and r_ffs_r(I) = '0') then
          r_ffs_q(I)  <= '1';
        else
          r_ffs_q(I)  <= r_ffs_q(I);
        end if;
      end if;
    end if;
  end process;
end generate;  

 
irq     <= f_hot_to_bin(r_ffs_q);

s_master_o.sel <= (others => '1');
s_master_o.we <= '1';

master_o <= s_master_o;
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- WB master generating IRQ msgs
-------------------------------------------------------------------------
wb_irq_master : process(clk_i, rst_n_i)

      variable v_state        : t_state;
      variable v_irq          : natural;

  begin
    if(rst_n_i = '0') then
      s_master_o.cyc <= '0';
      s_master_o.stb <= '0';
      s_master_o.adr  <= (others => '0');
      s_master_o.dat  <= (others => '0');
      r_state       <= s_IDLE;
      
    elsif rising_edge(clk_i) then

      v_state       := r_state;                    
      v_irq         := irq;  
      
      case r_state is
        when s_IDLE   =>  s_ffs_s <= irql_i; 
                          if(irq /= 0) then
                            v_state      := s_LOOKUP;
                          end if;
                             
        when s_LOOKUP =>  s_ffs_s <= s_ffs_s or irql_i; 
                          s_master_o.adr <= g_ivec_table(v_irq-1).address;
                          s_master_o.dat <= g_ivec_table(v_irq-1).value;
                          v_state      := s_SEND;
                          
        when s_SEND   =>  s_ffs_s <= s_ffs_s or irql_i; 
                          if(master_i.stall = '0') then
                            v_state := s_DONE;
                          end if;
                          
        when s_DONE   =>  s_ffs_s <= s_ffs_s or irql_i; 
                          v_state := s_IDLE;
        when others   =>  v_state := s_IDLE;
      end case;
    
      -- flags on state transition
      if(v_state = s_DONE) then
        r_ffs_r <= f_bin_to_hot(irq-1, g_irq_lines);
      else
        r_ffs_r <= (others => '0');
      end if;
      
      if(v_state = s_SEND) then
        s_master_o.cyc <= '1';
        s_master_o.stb <= '1';
      else
        s_master_o.cyc <= '0';
        s_master_o.stb <= '0';
      end if;
      
      r_state <= v_state;
    
    end if;
                  
  end process;
------------------------------------------------------------------------- 
              
                 

end architecture;
