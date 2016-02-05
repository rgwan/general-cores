-------------------------------------------------------------------------------
-- Title      : Parametrizable dual-port synchronous RAM (Xilinx version)
-- Project    : Generics RAMs and FIFOs collection
-------------------------------------------------------------------------------
-- File       : generic_dpram_sameclock.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-CO-HT
-- Created    : 2011-01-25
-- Last update: 2012-07-09
-- Platform   : 
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: True dual-port synchronous RAM for Xilinx FPGAs with:
-- - configurable address and data bus width
-- - byte-addressing mode (data bus width restricted to multiple of 8 bits)
-- Todo:
-- - loading initial contents from file
-- - add support for read-first/write-first address conflict resulution (only
--   supported by Xilinx in VHDL templates)
-------------------------------------------------------------------------------
-- Copyright (c) 2011 CERN
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2011-01-25  1.0      twlostow        Created
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.genram_pkg.all;
use work.memory_loader_pkg.all;

entity generic_dpram_sameclock is

  generic (
    g_data_width : natural := 32;
    g_size       : natural := 16384;

    g_with_byte_enable         : boolean := false;
    g_addr_conflict_resolution : string  := "read_first";
    g_init_file                : string  := "";
    g_fail_if_file_not_found   : boolean := true
    );

  port (
    rst_n_i : in std_logic := '1';      -- synchronous reset, active LO

    -- Port A
    clk_i : in std_logic;

    bwea_i : in  std_logic_vector((g_data_width+7)/8-1 downto 0);
    wea_i  : in  std_logic;
    aa_i   : in  std_logic_vector(f_log2_size(g_size)-1 downto 0);
    da_i   : in  std_logic_vector(g_data_width-1 downto 0);
    qa_o   : out std_logic_vector(g_data_width-1 downto 0);

    -- Port B
    bweb_i : in  std_logic_vector((g_data_width+7)/8-1 downto 0);
    web_i  : in  std_logic;
    ab_i   : in  std_logic_vector(f_log2_size(g_size)-1 downto 0);
    db_i   : in  std_logic_vector(g_data_width-1 downto 0);
    qb_o   : out std_logic_vector(g_data_width-1 downto 0)
    );

end generic_dpram_sameclock;



architecture syn of generic_dpram_sameclock is

  constant c_num_bytes : integer := (g_data_width+7)/8;

component s6_native_dpram
    generic (

      g_size       : integer;
      g_simulation : integer := 0
      );
    port (
      clk_i : in std_logic;

      ena_i  : in  std_logic;
      wea_i  : in  std_logic;
      aa_i   : in  std_logic_vector(31 downto 0);
      bwea_i : in  std_logic_vector(3 downto 0);
      da_i   : in  std_logic_vector(31 downto 0);
      qa_o   : out std_logic_vector(31 downto 0);

      enb_i  : in  std_logic;
      web_i  : in  std_logic;
      ab_i   : in  std_logic_vector(31 downto 0);
      bweb_i : in  std_logic_vector(3 downto 0);
      db_i   : in  std_logic_vector(31 downto 0);
      qb_o   : out std_logic_vector(31 downto 0)
      );
  end component;

  type t_ram_type is array(0 to g_size-1) of std_logic_vector(g_data_width-1 downto 0);

  function f_memarray_to_ramtype(arr : t_meminit_array) return t_ram_type is
    variable tmp    : t_ram_type;
    variable n, pos : integer;
  begin
    pos := 0;
    while(pos < g_size)loop
      n := 0;
      -- avoid ISE loop iteration limit
      while (pos < g_size and n < 4096) loop
        for i in 0 to g_data_width-1 loop
          tmp(pos)(i) := arr(pos, i);
        end loop;  -- i
        n   := n+1;
        pos := pos + 1;
      end loop;
    end loop;
    return tmp;
  end f_memarray_to_ramtype;

  function f_file_contents return t_meminit_array is
  begin
    return f_load_mem_from_file(g_init_file, g_size, g_data_width, g_fail_if_file_not_found);
  end f_file_contents;

  function f_is_synthesis return boolean is
  begin
    -- synthesis translate_off
    return false;
    -- synthesis translate_on
    return true;
  end f_is_synthesis;

  shared variable ram : t_ram_type := f_memarray_to_ramtype(f_file_contents);

  signal s_we_a     : std_logic_vector(c_num_bytes-1 downto 0);
  signal s_ram_in_a : std_logic_vector(g_data_width-1 downto 0);
  signal s_we_b     : std_logic_vector(c_num_bytes-1 downto 0);
  signal s_ram_in_b : std_logic_vector(g_data_width-1 downto 0);


  signal wea_rep, web_rep : std_logic_vector(c_num_bytes-1 downto 0);

  function f_check_bounds(x : integer; minx : integer; maxx : integer) return integer is
  begin
    if(x < minx) then
      return minx;
    elsif(x > maxx) then
      return maxx;
    else
      return x;
    end if;
  end f_check_bounds;

  impure function f_use_native_dpram return boolean is
  begin
    -- for simulations, always use the generic model (so that it can be
    -- initialized from a .ram file)
    if not f_is_synthesis then
      assert false report "synth" severity note;
      return false;
    end if;

    -- only 32-bit memories are currently implemented using native primitives
    if (g_data_width /= 32) then
      assert false report "dw" severity note;
      return false;
    end if;

    -- user specfied a .ram init file (slow but works, no data2mem though)
    if (g_init_file /= "") then
      assert false report "initf" severity note;
      return false;
    end if;

    if(g_addr_conflict_resolution /= "dont_care") then
      assert false report "ac" severity note;
      return false;
    end if;

    if (g_size = 4096 or g_size = 8192 or g_size = 16384 or g_size = 24576 or g_size = 32768) then
      return true;
    end if;

    assert false report "??" severity note;

    return false;
    
  end f_use_native_dpram;

  signal aa_ext, ab_ext : std_logic_vector(31 downto 0);
  
begin
 gen_native : if f_use_native_dpram generate

    assert false report "Using native DPRAM model" severity note;
    
    aa_ext(f_log2_size(g_size) + 1 downto 0) <= aa_i & "00";
    ab_ext(f_log2_size(g_size) + 1 downto 0) <= ab_i & "00";

    U_Native_DPRAM : s6_native_dpram
    generic map (
      g_size       => g_size * 4,
      g_simulation => 0)
    port map (
      clk_i  => clk_i,
      ena_i  => '1',
      wea_i  => wea_i,
      bwea_i => bwea_i,
      aa_i   => aa_ext,
      da_i   => da_i,
      qa_o   => qa_o,

      enb_i  => '1',
      web_i  => web_i,
      bweb_i => bweb_i,
      
      ab_i   => ab_ext,
      db_i   => db_i,
      qb_o   => qb_o
    );

  end generate gen_native;

  gen_inferred : if not f_use_native_dpram generate

  wea_rep <= (others => wea_i);
  web_rep <= (others => web_i);

  s_we_a <= bwea_i and wea_rep;
  s_we_b <= bweb_i and web_rep;

  gen_with_byte_enable_readfirst : if(g_with_byte_enable = true and (g_addr_conflict_resolution = "read_first" or
                                                                     g_addr_conflict_resolution = "dont_care")) generate

    process (clk_i)
    begin
      if rising_edge(clk_i) then
        qa_o <= ram(f_check_bounds(to_integer(unsigned(aa_i)), 0, g_size-1));
        qb_o <= ram(f_check_bounds(to_integer(unsigned(ab_i)), 0, g_size-1));
        for i in 0 to c_num_bytes-1 loop
          if s_we_a(i) = '1' then
            ram(f_check_bounds(to_integer(unsigned(aa_i)), 0, g_size-1))((i+1)*8-1 downto i*8) := da_i((i+1)*8-1 downto i*8);
          end if;
          if(s_we_b(i) = '1') then
            ram(f_check_bounds(to_integer(unsigned(ab_i)), 0, g_size-1))((i+1)*8-1 downto i*8) := db_i((i+1)*8-1 downto i*8);
          end if;
        end loop;
      end if;
    end process;

  end generate gen_with_byte_enable_readfirst;



  gen_without_byte_enable_readfirst : if(g_with_byte_enable = false and (g_addr_conflict_resolution = "read_first" or
                                                                         g_addr_conflict_resolution = "dont_care")) generate

    process(clk_i)
    begin
      if rising_edge(clk_i) then
        if f_is_synthesis then
          qa_o <= ram(to_integer(unsigned(aa_i)));
          qb_o <= ram(to_integer(unsigned(ab_i)));
        else
          qa_o <= ram(to_integer(unsigned(aa_i)) mod g_size);
          qb_o <= ram(to_integer(unsigned(ab_i)) mod g_size);
        end if;
        if(wea_i = '1') then
          ram(to_integer(unsigned(aa_i))) := da_i;
        end if;
        if(web_i = '1') then
          ram(to_integer(unsigned(ab_i))) := db_i;
        end if;
      end if;
    end process;
  end generate gen_without_byte_enable_readfirst;

  gen_without_byte_enable_writefirst : if(g_with_byte_enable = false and g_addr_conflict_resolution = "write_first") generate

    process(clk_i)
    begin
      if rising_edge(clk_i) then
        if(wea_i = '1') then
          ram(to_integer(unsigned(aa_i))) := da_i;
          qa_o                            <= da_i;
        else
          if f_is_synthesis then
            qa_o <= ram(to_integer(unsigned(aa_i)));
          else
            qa_o <= ram(to_integer(unsigned(aa_i)) mod g_size);
          end if;
        end if;
        if(web_i = '1') then
          ram(to_integer(unsigned(ab_i))) := db_i;
          qb_o                            <= db_i;
        else
          if f_is_synthesis then
            qb_o <= ram(to_integer(unsigned(ab_i)));
          else
            qb_o <= ram(to_integer(unsigned(ab_i)) mod g_size);
          end if;
        end if;
      end if;

    end process;
  end generate gen_without_byte_enable_writefirst;


  gen_without_byte_enable_nochange : if(g_with_byte_enable = false and g_addr_conflict_resolution = "no_change") generate

    process(clk_i)
    begin
      if rising_edge(clk_i) then
        if(wea_i = '1') then
          ram(to_integer(unsigned(aa_i))) := da_i;
        else
          if f_is_synthesis then
            qa_o <= ram(to_integer(unsigned(aa_i)));
          else
            qa_o <= ram(to_integer(unsigned(aa_i)) mod g_size);
          end if;
        end if;
        if(web_i = '1') then
          ram(to_integer(unsigned(ab_i))) := db_i;
        else
          if f_is_synthesis then
            qb_o <= ram(to_integer(unsigned(ab_i)));
          else
            qb_o <= ram(to_integer(unsigned(ab_i)) mod g_size);
          end if;
        end if;
      end if;
    end process;


    
  end generate gen_without_byte_enable_nochange;
  end generate gen_inferred;

end syn;
