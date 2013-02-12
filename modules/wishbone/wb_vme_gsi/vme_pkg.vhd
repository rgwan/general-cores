library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;

package vme_pkg is
  component vmelogic is
         port (asis  :in std_logic; 
               dsr   :in std_logic; 
               ad   :inout std_logic_vector(31 downto 0);
               ad_reg :inout std_logic_vector(31 downto 0);
               wri   :in std_logic;
               ckcsr :out std_logic; -- clock data into csr
               oecsr :out std_logic; -- output data from csr to VME
               con   :inout std_logic_vector(15 downto 0);
               hplb  :out std_logic_vector(15 downto 0);
               ck50, ck100   :in std_logic);	
	end component;
end;