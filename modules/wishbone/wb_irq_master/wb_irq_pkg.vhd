--! @file wb_irq_pkg.vhd
--! @brief Wishbone IRQ Master
--!
--! Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
--!
--! Important details about its implementation
--! should go in these comments.
--!
--! @author Mathias Kreider <m.kreider@gsi.de>
--!
--------------------------------------------------------------------------------
--! This library is free software; you can redistribute it and/or
--! modify it under the terms of the GNU Lesser General Public
--! License as published by the Free Software Foundation; either
--! version 3 of the License, or (at your option) any later version.
--!
--! This library is distributed in the hope that it will be useful,
--! but WITHOUT ANY WARRANTY; without even the implied warranty of
--! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
--! Lesser General Public License for more details.
--!  
--! You should have received a copy of the GNU Lesser General Public
--! License along with this library. If not, see <http://www.gnu.org/licenses/>.
---------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.wishbone_pkg.all;

package wb_irq_pkg is
  
  type t_ivec_array_d is array(natural range <>) of t_wishbone_data;
 
  type t_ivec_ad is record
    address     : t_wishbone_address;
    value       : t_wishbone_data;
  end record t_ivec_ad;

  type t_ivec_array_ad is array(natural range <>) of t_ivec_ad;

  function f_hot_to_bin(x : std_logic_vector)       return integer;
  function f_bin_to_hot(x : natural; len : natural) return std_logic_vector;
  function or_all(slv_in : std_logic_vector)        return std_logic; 
  
  component wb_irq_master is
  generic (g_irq_lines  : natural := 8;
           g_ivec_table : t_ivec_array_ad
  );
  port    (clk_i          : std_logic;
           rst_n_i        : std_logic; 
           irql_i         : in  std_logic_vector(g_irq_lines-1 downto 0);
           master_o       : out t_wishbone_master_out;
           master_i       : in  t_wishbone_master_in
  );
  end component;
  
  component wb_irq_slave is
  generic (g_irq_lines  : natural := 8;
           g_ivec_table : t_ivec_array_d
  );
  port    (clk_i         : std_logic;
           rst_n_i       : std_logic; 
           irql_o        : out std_logic_vector(g_irq_lines-1 downto 0);
           slave_o       : out t_wishbone_slave_out;
           slave_i       : in  t_wishbone_slave_in
  );
  end component;
  
end package;

package body wb_irq_pkg is

  

  function f_hot_to_bin(x : std_logic_vector)
    return integer is
    variable rv : integer;
  begin
    rv := 0;
    -- if there are few ones set in _x_ then the most significant will be
    -- translated to bin
    for i in 0 to x'left loop
      if x(i) = '1' then
        rv := i+1;
      end if;
    end loop;
    return rv;
  end function;

function f_bin_to_hot(x : natural; len : natural
  ) return std_logic_vector is

    variable ret : std_logic_vector(len-1 downto 0);

  begin

    ret := (others => '0');
    ret(x) := '1';
    return ret;
  end function;

function or_all(slv_in : std_logic_vector)
return std_logic is
variable I : natural;
variable ret : std_logic;
begin
  ret := '0';
  for I in 0 to slv_in'left loop
	ret := ret or slv_in(I);
  end loop; 	
  return ret;
end function or_all;  
  
end package body;
