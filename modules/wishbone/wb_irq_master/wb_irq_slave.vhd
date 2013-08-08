library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.genram_pkg.all;
use work.wb_irq_pkg.all;
use work.eb_internals_pkg.all;

entity wb_irq_slave is
  generic ( g_queues  : natural := 4;
            g_depth   : natural := 8;
            g_datbits : natural := 32;
            g_adrbits : natural := 32;
            g_selbits : natural := 4
  );
  port    (clk_i         : std_logic;
           rst_n_i       : std_logic; 
           
           irq_slave_o   : out t_wishbone_slave_out_array(g_queues-1 downto 0);
           irq_slave_i   : in  t_wishbone_slave_in_array(g_queues-1 downto 0);
           
           ctrl_slave_o  : out t_wishbone_slave_out;
           ctrl_slave_i  : in  t_wishbone_slave_in
  );
end entity;

architecture behavioral of wb_irq_slave is

--memory map for ctrl wb
constant c_RST        : natural := 0;
constant c_STATUS     : natural := c_RST+4;
constant c_POP        : natural := c_STATUS+4;
constant c_QUEUES     : natural := c_POP+4;
constant c_N_QUEUE    : natural := 16; --queue I is found at: c_QUEUES + I * c_N_QUEUE
constant c_OFFS_DATA  : natural := 0;
constant c_OFFS_ADDR  : natural := c_OFFS_DATA+4;
constant c_OFFS_SEL   : natural := c_OFFS_ADDR+4;

--ctrl wb signals
signal r_status, r_pop : std_logic_vector(g_queues-1 downto 0);
signal queue_offs : natural;
signal word_offs  : natural;
signal adr        : unsigned(9 downto 0);

--queue signals
type t_queue_dat is array(natural range <>) of std_logic_vector(g_datbits+g_adrbits+g_selbits-1 downto 0);
signal irq_en, irq_push, irq_pop, irq_full, irq_empty : std_logic_vector(g_queues-1 downto 0);
signal irq_d, irq_q : t_queue_dat(g_queues-1 downto 0);
signal ctrl_en : std_logic;

begin  

  -------------------------------------------------------------------------
  --irq wb and queues
  -------------------------------------------------------------------------
  G1: for I in 0 to g_queues-1 generate
    irq_d(I)              <= irq_slave_i(I).sel & irq_slave_i(I).adr & irq_slave_i(I).dat;
    irq_en(I)             <= irq_slave_i(I).cyc and irq_slave_i(I).stb and not irq_full(I);
    irq_slave_o(I).stall  <= irq_full(I);
    irq_push(I)           <= irq_en(I);
    irq_pop(I)            <= r_pop(I);
    r_status(I)           <= not irq_empty(I);
    
    irq_slave_o(I).int        <= '0';
    irq_slave_o(I).rty        <= '0';
    irq_slave_o(I).err        <= '0';  
    irq_slave_o(I).dat        <= (others => '0');
    irq_slave_o(I).stall      <= '0';

    irq_fifo : eb_fifo
    generic map(
      g_width => 32+32+4,
      g_size  => g_depth)
    port map (
      clk_i     => clk_i,
      rstn_i    => rst_n_i,
      w_full_o  => irq_full(I),
      w_push_i  => irq_en(I),
      w_dat_i   => irq_d(I),
      r_empty_o => irq_empty(I),
      r_pop_i   => irq_pop(I),
      r_dat_o   => irq_q(I));

      p_ack : process(clk_i)
  begin
      if rising_edge(clk_i) then
        irq_slave_o(I).ack <= irq_en(I);
      end if;
  end process;

  end generate;  

  
  -------------------------------------------------------------------------

  -------------------------------------------------------------------------
  -- ctrl wb and output
  -------------------------------------------------------------------------
  ctrl_en     <= ctrL_slave_i.cyc and ctrl_slave_i.stb;
  adr         <= unsigned(ctrl_slave_i.adr(adr'left +2 downto 2));
  queue_offs  <= to_integer(adr(adr'left downto 2)-c_QUEUES);
  word_offs   <= to_integer(adr(1 downto 0));

  process(clk_i)
  
    variable v_dat  : std_logic_vector(g_datbits-1 downto 0);
    variable v_adr  : std_logic_vector(g_adrbits-1 downto 0);  
    variable v_sel  : std_logic_vector(g_selbits-1 downto 0); 
  
  begin
      if rising_edge(clk_i) then
         
         
         ctrl_slave_o.ack <= '1';
         ctrl_slave_o.err <= '1';
         r_pop <= (others => '0'); 
         ctrl_slave_o.dat <= (others => '0');
          
        if(ctrl_en = '1') then
        
          if(adr < c_QUEUES) then
            case to_integer(adr) is
              when c_RST    =>  ctrl_slave_o.dat <= (others => '0');  ctrl_slave_o.ack <= '1';
                                ctrl_slave_o.dat <= (others => '0');  ctrl_slave_o.ack <= '1';
              
              when c_STATUS =>  ctrl_slave_o.dat <= r_status;         ctrl_slave_o.ack <= '1';
              
              when c_POP    =>  if(ctrl_slave_i.we = '1') then 
                                  r_pop <= ctrl_slave_i.dat;
                                end if;
                                ctrl_slave_o.dat <= (others => '0');  ctrl_slave_o.ack <= '1';
              
              when others   =>  null;                                 ctrl_slave_o.err <= '1';
            end case;
          else
            if(adr < c_QUEUES + c_N_QUEUE * g_queues and ctrl_slave_i.we = '0') then
              v_dat := irq_q(queue_offs)(g_datbits-1 downto 0); 
              v_adr := irq_q(queue_offs)(g_adrbits+g_datbits-1 downto g_datbits);
              v_sel := irq_q(queue_offs)(g_selbits + g_adrbits + g_datbits-1 downto g_adrbits+g_datbits);
              
              case word_offs is
                when c_OFFS_DATA =>  ctrl_slave_o.dat <= std_logic_vector(to_unsigned(0, 32-g_datbits)) & v_dat; ctrl_slave_o.ack <= '1';
                when c_OFFS_ADDR =>  ctrl_slave_o.dat <= std_logic_vector(to_unsigned(0, 32-g_adrbits)) & v_adr; ctrl_slave_o.ack <= '1';
                when c_OFFS_SEL  =>  ctrl_slave_o.dat <= std_logic_vector(to_unsigned(0, 32-g_selbits)) & v_sel; ctrl_slave_o.ack <= '1';
                when others =>  ctrl_slave_o.err <= '1';
              end case;
            else
              ctrl_slave_o.err <= '1';            
            end if;
          end if;
        
        end if;   
      end if;
  end process;
  
end architecture;
