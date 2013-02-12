library IEEE;
use IEEE.STD_LOGIC_1164.ALL;																						
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
--
--	vme_1: vmelogic port map (asis=>asis, dsr=>dsr, ad=>ad, wri=>wri, ami=>ami, mon=>mon, con=>con, xxx=>xxx, 

 entity vmelogic is
			port (asis	:in std_logic; -- 
					dsr	:in std_logic; --
					ad   :inout std_logic_vector(31 downto 0);
					ad_reg :inout std_logic_vector(31 downto 0);
					wri   :in std_logic;
					ckcsr	:out std_logic; -- clock data into csr
					oecsr	:out std_logic; -- output data from csr to VME
					con   :inout std_logic_vector(15 downto 0);
					hplb	:out std_logic_vector(15 downto 0);
					ck50, ck100   :in std_logic
					);
end vmelogic;
--
architecture RTL of vmelogic is
-------------------------------------------------------------------------------------------
------------------------------- vme signals -----------------------------------------------
signal ckad		: std_logic;				-- clock for internal address register
signal stda		: std_logic;				-- start data phase	state machine
signal wrs		: std_logic;				-- synchronized VME WRITE
signal ack_csr		: std_logic;				-- internal acknowledge csr
signal ack_hpi		: std_logic;				-- internal acknowledge hpi
signal ack_fsh		: std_logic;				-- internal acknowledge flash
signal ack_vr		: std_logic;				-- internal acknowledge vram 32
signal aph_sta, dph_sta	: std_logic_vector (3 downto 0);  	-- states of aph machine
signal enable		: std_logic;				-- enable internal data bus to outside of fpga
--signal vafsh	: std_logic_vector (3 downto 0);  	-- vme address phase outputs for flash
--signal va64	   : std_logic_vector (3 downto 0);  	-- vme data phase for VRAM64 (dual port ram) 
signal vdcsr	: std_logic_vector (3 downto 0);  	-- vme data phase outputs for external vme buffer register 
signal amr		: std_logic_vector (5 downto 0);	 -- internal address modifier register for VME address
signal int_res		: std_logic_vector (23 downto 22);	 -- internal address register for VME address
signal sel_rnd		: std_logic;	 -- FLASH, CSR, HPI, DPRAM random access
signal sel_bt32	: std_logic;	 -- DPRAM BT 32 access
--signal sel_bt64	: std_logic;	 -- DPRAM BT 64 access
signal selcsr, sel_int		: std_logic;	 -- CSR selected
signal selflsh		: std_logic;	 -- FLASH selected
signal ad_co	: std_logic_vector (1 downto 0);  	-- vme address phase outputs for: stda = start data phase...
signal csr_o	: std_logic_vector (1 downto 0);  	-- vme data phase outputs for csr 
signal pr_ou	: std_logic_vector (1 downto 0);  	-- priority encoder outputs  
signal tr_ou	: std_logic_vector (15 downto 0);  	-- priority encoder outputs  
signal vram		: std_logic;	 -- vram1 or vram2 32/64 bit selected
signal vulom_sel	: std_logic;
signal ckcsro		: std_logic_vector (1 downto 0);	 -- internal CSR
signal oecsro		: std_logic_vector (1 downto 0);	 -- internal CSR
signal din,csrr0,csrr1		: std_logic_vector (31 downto 0);	 -- internal data bus, CSR
------------------ VME address modifier ------------------------------
constant am_f	:std_logic_vector(5 downto 0)  := b"001111";--AM543210=001111 ext. Extended supervisory block transfer    
constant am_e	:std_logic_vector(5 downto 0)  := b"001110";--AM543210=001110 ext. supervisory program access    
constant am_d	:std_logic_vector(5 downto 0)  := b"001101";--AM543210=001101 ext. Extended supervisory data access    
constant am_a	:std_logic_vector(5 downto 0)  := b"001010";--AM543210=001010 ext. Extended non-privileged program access    
constant am_b	:std_logic_vector(5 downto 0)  := b"001011";--AM543210=001011 ext. Extended non-privileged  block transfer    
constant am_9	:std_logic_vector(5 downto 0)  := b"001001";--AM543210=001001 ext. Extended non-privileged data access    
constant am_8	:std_logic_vector(5 downto 0)  := b"001000";--AM543210=001000 ext. Extended non-privileged 64-bit block transfer    
constant am_1b	:std_logic_vector(5 downto 0)  := b"011011";--AM543210=011011 ext. Eurogram Readout    
constant am_29	:std_logic_vector(5 downto 0)  := b"101001";--AM543210=101001 ext. Direct Configuration of FPGA    
------------------ VME addresses --------------------------------------
constant csr_ad	:std_logic_vector(3 downto 2)  := b"00";----vmeaddr=XX00 0000 - XX00 000C    
--constant sram_ad	:std_logic_vector(3 downto 2)  := x"01";----vmeaddr=XX40 0000 - XX40 FFFC    
-- ............... vme address phase state machine, states declaration .........................
type vme_adr_typ is (va00,va01,va02,va03,va04,va05,va0b);	-- va06,va07,va08,va09,va0a,
signal vme_adr, vme_anx : vme_adr_typ;
-- ............... vme data phase state machine for CSR .........................
signal st_csr_drd		: std_logic;	 -- start state machine for CSR read
signal st_csr_dwr		: std_logic;	 -- start state machine for CSR write   
type vmdacs_typ is (vc00,vc01,vc02,vc03,vc04,vc05,vc06,vc07,vc08,vc09,vc0a,vc0b,vc0c,vc0d,vc0e);
signal vmdacs, vmdacs_nx : vmdacs_typ;

------------------------------------------------------------------------------------------
begin ---- BEGIN  BEGIN  BEGIN  BEGIN  BEGIN  BEGIN  BEGIN  BEGIN  BEGIN  BEGIN  BEGIN 
------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
--..........................................................................................
--...................... VME address phase state machine .......................
	process (vme_adr,asis) 	-- states are - va00,va01,va02,va03,va04,va05,va06,va07,va08 
		begin			-- 							ad_co[]=stda,ckad  
			case vme_adr is
				when va00 => 							ad_co <= b"00"; aph_sta <= x"0";		
					if 		asis ='1' then	vme_anx <= va01;
					else    vme_anx <= va00;
					end if;
				when va01 => 							ad_co <= b"00"; aph_sta <= x"1";		
					if 		asis ='1' then	 vme_anx <= va02;
					else    vme_anx <= va00;
					end if;
				when va02 => vme_anx <= va03;		ad_co <= b"01"; aph_sta <= x"2";
				when va03 => vme_anx <= va04;		ad_co <= b"01"; aph_sta <= x"3";
				when va04 => vme_anx <= va05;		ad_co <= b"00"; aph_sta <= x"4";
				when va05 => vme_anx <= va0b;		ad_co <= b"00"; aph_sta <= x"5";
				when va0b => 							ad_co <= b"10"; aph_sta <= x"b";
					if 		asis ='1'	 then  vme_anx <= va0b;
					else 	vme_anx <= va00;				
					end if;
			 end case;
	end process;
-- ............................ clock for address phase state machine ................................
	 process(ck50) begin  -- 50 MHz clock
		if (rising_edge(ck50)) then 
		    vme_adr <= vme_anx;
		end if;
	end process ;
-- .............................. synchronize outputs ..................................
	process(ck100) begin
		if (rising_edge(ck100)) then 
		stda		<=	ad_co(1);	-- start data phase	(low=address phase - high =data phase)
		ckad		<=	ad_co(0);	-- ckad = clock for internal address register
		end if;
	end process ;
----................... end of VME address phase state machine ...................
--
---................... save VME address into FPGA internal address register ...................
		process(ck100, ckad)
			begin
				if (rising_edge(ck100)) then
					if  ckad = '1' then
						ad_reg <= ad;       wrs <= wri;  
					end if;
				end if;
		end process;
		int_res	<= ad_reg(23 downto 22);  -- internal resources 
--..................  compare address register and address modifier .............................
--		process(ck100, ad_reg)								  
--		begin
--   			if (rising_edge(ck100)) then   
--    				if (con(7) = '1') then sel_rnd <= '1'; -- CSR random access
--    				else sel_rnd <= '0';
--    				end if;    
--    				if (con(8) = '1') then sel_bt32 <= '1'; --  BT 32 bit access
--    				else sel_bt32 <= '0';
--    				end if;    
--    			end if;
--		end process;
		sel_rnd	<=	con(7);
		sel_bt32	<=	con(8);
-- * CSR0 @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ DATA PHASE for CSR @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
--................................  comparator for CSR  .......................................
		sel_int <= '1' when (int_res=csr_ad) else '0';
		selcsr  <= '1' when (sel_int='1' and sel_rnd='1') else '0';
		process(ck100)
		begin
   			if (rising_edge(ck100)) then   
    				if (dsr='1' and stda='1' and wrs='1' and sel_int='1' and sel_rnd='1') then st_csr_drd <= '1'; -- CSR sta-ma
    				else st_csr_drd <= '0';
    				end if;  
    			end if;
		end process;	
--		
		process(ck100)
		begin
   			if (rising_edge(ck100)) then   					
    				if (dsr='1' and stda='1' and wrs='0' and sel_int='1' and sel_rnd='1') then st_csr_dwr <= '1'; -- CSR sta-ma
    				else st_csr_dwr <= '0';
    				end if; 
    			end if;
		end process;					
--		begin
--   			if (rising_edge(ck100)) then   
--    				if (sel_int='1' and sel_rnd='1') then selcsr <= '1'; -- CSR selected
--    				else selcsr <= '0';
--    				end if;    
--    			end if;
--		end process;
--			csr_o[]=ckcsr,oecsr, 		vdcsr[]=odvi,cdvi,odiv,cdiv
	process (vmdacs, dsr, st_csr_dwr, st_csr_drd) 	-- states are - vc00,vc01,vc02,vc03,vc04,vc05,vc06,vc07,vc08 
		begin
			csr_o <= b"00"; vdcsr <= b"1011"; ack_csr	<='1';
			case vmdacs is
				when vc00 => csr_o <= b"00"; vdcsr <= b"1011"; ack_csr	<='1'; dph_sta <= x"0"; 		
					if 	 st_csr_drd ='1' then vmdacs_nx <= vc01;						
					elsif st_csr_dwr ='1' then vmdacs_nx <= vc08;		
					else 	
						vmdacs_nx <= vc00;
					end if;
--
--............................. read csr ................................
				when vc01 => vmdacs_nx <= vc02;	csr_o <= b"00"; vdcsr <= b"1010"; ack_csr	<='1'; dph_sta <= x"1"; 								
				when vc02 => vmdacs_nx <= vc03;	csr_o <= b"01"; vdcsr <= b"1010"; ack_csr	<='1'; dph_sta <= x"2";						
				when vc03 => vmdacs_nx <= vc04;	csr_o <= b"01"; vdcsr <= b"1010"; ack_csr	<='1'; dph_sta <= x"3";						
				when vc04 => vmdacs_nx <= vc05;	csr_o <= b"01"; vdcsr <= b"1010"; ack_csr	<='1'; dph_sta <= x"4";						
				when vc05 => vmdacs_nx <= vc06;	csr_o <= b"01"; vdcsr <= b"1000"; ack_csr	<='1'; dph_sta <= x"5";						
				when vc06 => 							csr_o <= b"01"; vdcsr <= b"1001"; ack_csr	<='0'; dph_sta <= x"6"; 		
					if 		dsr ='1' then	vmdacs_nx <= vc06;						
					else 	vmdacs_nx <= vc07;						
					end if;
				when vc07 => vmdacs_nx <= vc00;	csr_o <= b"00"; vdcsr <= b"1011"; ack_csr	<='1'; dph_sta <= x"7";						
--............................. write csr ................................
				when vc08 => vmdacs_nx <= vc09;	csr_o <= b"00"; vdcsr <= b"0011"; ack_csr	<='1'; dph_sta <= x"8";
				when vc09 => vmdacs_nx <= vc0a;	csr_o <= b"10"; vdcsr <= b"0011"; ack_csr	<='1'; dph_sta <= x"9";
				when vc0a => vmdacs_nx <= vc0b;	csr_o <= b"10"; vdcsr <= b"0111"; ack_csr	<='1'; dph_sta <= x"a";
				when vc0b => vmdacs_nx <= vc0c;	csr_o <= b"10"; vdcsr <= b"0111"; ack_csr	<='1'; dph_sta <= x"b";
				when vc0c => vmdacs_nx <= vc0d;	csr_o <= b"10"; vdcsr <= b"0111"; ack_csr	<='1'; dph_sta <= x"c";
				when vc0d => 							csr_o <= b"10"; vdcsr <= b"0111"; ack_csr	<='0'; dph_sta <= x"d"; 		
					if 		dsr ='1' then	vmdacs_nx <= vc0d;
					else   vmdacs_nx <= vc0e;	
					end if;
				when vc0e => vmdacs_nx <= vc00;	csr_o <= b"00"; vdcsr <= b"1011"; ack_csr	<='1'; dph_sta <= x"e";
			 end case;
	end process;
-- ............................ clock for vmedacs state machine ................................
	 process(ck100) begin
		if (rising_edge(ck100)) then 
		    vmdacs <= vmdacs_nx;
		end if;
	end process ;
-- .............................. synchronize outputs ..................................
	process(ck100) begin
		if (rising_edge(ck100)) then 
--			csr_o = ckcsr,oecsr, 		
		ckcsr		<=	csr_o(1);	-- clock data into csr
		oecsr		<=	csr_o(0);	-- output data from csr to VME
		end if;
	end process ;
--------------------------- Multiplexer	for VME buffer and VME control signals -------------------------------
--			vdbuf = odvi,cdvi,odiv,cdiv
		process(ck100)
		begin
   			if (rising_edge(ck100)) then   
    				if (selcsr='1') then 
					con(4)	<=	vdcsr(3);	-- odvi = OE for data register VME<-internal
					con(3)	<=	vdcsr(2);	-- cdvi = clock for data register VME<-internal
					con(2)	<=	vdcsr(1);	-- odiv = OE for data register internal<-VME  
					con(1)	<=	vdcsr(0);	-- cdiv = clock for data register internal<-VME
					con(0)	<=	ack_csr;		-- acknowledge from csr
   				else 
					con(4) <= '1'; con(3)	<=	'1'; con(2) <= '1';	con(1) <= '1'; con(0) <= '1';	-- inactive
    				end if;    
    			end if;
		end process; 
----------------------------------------------------------------------------------
--		hplb <= (others =>'0');
		hplb(0) <= asis;
		hplb(1) <= ckad;
		hplb(2) <= csr_o(0); -- oecsr
		hplb(3) <= csr_o(1); -- ckcsr
		hplb(6 downto 4) <= aph_sta(2 downto 0);
		hplb(7) <= sel_rnd;
		hplb(11 downto 8) <= vdcsr; -- odvi,cdvi,odiv,cdiv
		hplb(15 downto 12) <= dph_sta;

end RTL;
