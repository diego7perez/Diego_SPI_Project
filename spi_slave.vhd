--------------------------------------------------------------------------------
-- PROJECT: SPI SLAVE FOR FPGA
--------------------------------------------------------------------------------
-- NAME:    SPI_SLAVE
-- AUTHOR:  Diego Perez Lopez
--------------------------------------------------------------------------------



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- THIS SPI SLAVE MODULE SUPPORT ONLY SPI MODE 0 (CPOL=0, CPHA=0)!!!

entity SPI_SLAVE is
    Port (

        CLK      : in  std_logic; -- system clock
        RST      : in  std_logic; -- high active synchronous reset
        -- SPI SLAVE INTERFACE
        SCLK_i     : in  std_logic; -- SPI clock
        nCS_i     : in  std_logic; -- SPI chip select, active in low
        MOSI_i     : in  std_logic; -- SPI serial data from master to slave
        MISO_o     : out std_logic; -- SPI serial data from slave to master
        -- USER INTERFACE
        SPI_data_i     : in  std_logic_vector(7 downto 0); -- input data for SPI master
        SPI_data_i_vld  : in  std_logic; -- when SPI_data_i_vld = 1, input data are valid
        IRQ_WT_o    : out std_logic; -- when IRQ_WT_o = 1, valid input data are accept
        SPI_data_o     : out std_logic_vector(7 downto 0); -- output data from SPI master
        SPI_data_o_vld : out std_logic  -- when SPI_data_o_vld = 1, output data are valid
    );
end SPI_SLAVE;

architecture RTL of SPI_SLAVE is

    signal spi_clk_reg        : std_logic;
    signal spi_clk_redge_en   : std_logic;
    signal spi_clk_fedge_en   : std_logic;
    signal bit_cnt            : unsigned(2 downto 0);
    signal bit_cnt_max        : std_logic;
    signal last_bit_en        : std_logic;
    signal load_data_en       : std_logic;
    signal data_shreg         : std_logic_vector(7 downto 0);
    signal slave_ready        : std_logic;
    signal shreg_busy         : std_logic;
    signal rx_data_vld        : std_logic;

begin

    -- -------------------------------------------------------------------------
    --  SPI CLOCK REGISTER
    -- -------------------------------------------------------------------------

    -- The SPI clock register is necessary for clock edge detection.
    spi_clk_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                spi_clk_reg <= '0';
            else
                spi_clk_reg <= SCLK_i;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --  SPI CLOCK EDGES FLAGS
    -- -------------------------------------------------------------------------

    -- Falling edge is detect when SCLK_i=0 and spi_clk_reg=1.
    spi_clk_fedge_en <= not SCLK_i and spi_clk_reg;
    -- Rising edge is detect when SCLK_i=1 and spi_clk_reg=0.
    spi_clk_redge_en <= SCLK_i and not spi_clk_reg;

    -- -------------------------------------------------------------------------
    --  RECEIVED BITS COUNTER
    -- -------------------------------------------------------------------------

    -- The counter counts received bits from the master. Counter is enabled when
    -- falling edge of SPI clock is detected and not asserted nCS_i.
    bit_cnt_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                bit_cnt <= (others => '0');
            elsif (spi_clk_fedge_en = '1' and nCS_i = '0') then
                if (bit_cnt_max = '1') then
                    bit_cnt <= (others => '0');
                else
                    bit_cnt <= bit_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- The flag of maximal value of the bit counter.
    bit_cnt_max <= '1' when (bit_cnt = "111") else '0';

    -- -------------------------------------------------------------------------
    --  LAST BIT FLAG REGISTER
    -- -------------------------------------------------------------------------

    -- The flag of last bit of received byte is only registered the flag of
    -- maximal value of the bit counter.
    last_bit_en_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                last_bit_en <= '0';
            else
                last_bit_en <= bit_cnt_max;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --  RECEIVED DATA VALID FLAG
    -- -------------------------------------------------------------------------

    -- Received data from master are valid when falling edge of SPI clock is
    -- detected and the last bit of received byte is detected.
    rx_data_vld <= spi_clk_fedge_en and last_bit_en;

    -- -------------------------------------------------------------------------
    --  SHIFT REGISTER BUSY FLAG REGISTER
    -- -------------------------------------------------------------------------

    -- Data shift register is busy until it sends all input data to SPI master.
    shreg_busy_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                shreg_busy <= '0';
            else
                if (SPI_data_i_vld = '1' and (nCS_i = '1' or rx_data_vld = '1')) then
                    shreg_busy <= '1';
                elsif (rx_data_vld = '1') then
                    shreg_busy <= '0';
                else
                    shreg_busy <= shreg_busy;
                end if;
            end if;
        end if;
    end process;

    -- The SPI slave is ready for accept new input data when nCS_i is assert and
    -- shift register not busy or when received data are valid.
    slave_ready <= (nCS_i and not shreg_busy) or rx_data_vld;
    
    -- The new input data is loaded into the shift register when the SPI slave
    -- is ready and input data are valid.
    load_data_en <= slave_ready and SPI_data_i_vld;

    -- -------------------------------------------------------------------------
    --  DATA SHIFT REGISTER
    -- -------------------------------------------------------------------------

    -- The shift register holds data for sending to master, capture and store
    -- incoming data from master.
    data_shreg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (load_data_en = '1') then
                data_shreg <= SPI_data_i;
            elsif (spi_clk_redge_en = '1' and nCS_i = '0') then
                data_shreg <= data_shreg(6 downto 0) & MOSI_i; --QUE CONO HACE
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --  MISO_o REGISTER
    -- -------------------------------------------------------------------------

    -- The output MISO_o register ensures that the bits are transmit to the master
    -- when is not assert nCS_i and falling edge of SPI clock is detected.
    miso_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (load_data_en = '1') then
                MISO_o <= SPI_data_i(7);
            elsif (spi_clk_fedge_en = '1' and nCS_i = '0') then
                MISO_o <= data_shreg(7);
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --  ASSIGNING OUTPUT SIGNALS
    -- -------------------------------------------------------------------------
    
    IRQ_WT_o    <= slave_ready;
    SPI_data_o     <= data_shreg;
    SPI_data_o_vld <= rx_data_vld;

end RTL;