--------------------------------------------------------------------------------
-- PROJECT: SPI SLAVE FOR FPGA
--------------------------------------------------------------------------------
-- NAME:    SPI_TB
-- AUTHOR:  Diego Perez Lopez
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity SPI_TB is
end SPI_TB;

architecture SIM of SPI_TB is

    constant CLK_PERIOD  : time := 20 ns;
    constant SLAVE_COUNT : integer := 4;

    signal CLK        : std_logic := '0';
    signal RST        : std_logic := '1';

    signal sclk       : std_logic;
    signal cs_n       : std_logic_vector(SLAVE_COUNT-1 downto 0);
    signal miso       : std_logic;
    signal mosi       : std_logic;

    signal m_addr     : std_logic_vector(integer(ceil(log2(real(SLAVE_COUNT))))-1 downto 0);
    signal m_din      : std_logic_vector(7 downto 0);
    signal m_din_last : std_logic;
    signal m_din_vld  : std_logic;
    signal m_ready    : std_logic;
    signal m_dout     : std_logic_vector(7 downto 0);
    signal m_dout_vld : std_logic;

    signal s_din      : std_logic_vector(7 downto 0);
    signal s_din_vld  : std_logic;
    signal s_ready    : std_logic;
    signal s_dout     : std_logic_vector(7 downto 0);
    signal s_dout_vld : std_logic;

begin

    master_i : entity work.SPI_MASTER
    generic map(
        CLK_FREQ    => 50e6,
        SCLK_FREQ   => 5e6,
        SLAVE_COUNT => SLAVE_COUNT
    )
    port map (
        CLK      => CLK,
        RST      => RST,
        -- SPI MASTER INTERFACE
        SCLK_i     => sclk,
        nCS_i     => cs_n,
        MOSI_o     => mosi,
        MISO_i     => miso,
        -- USER INTERFACE
        ADDR     => m_addr,
        SPI_data_i      => m_din,
        SPI_data_i_last => m_din_last,
        SPI_data_i_vld  => m_din_vld,
        IRQ_WT_o    => m_ready,
        SPI_data_o     => m_dout,
        SPI_data_o_vld => m_dout_vld
    );

    slave_i : entity work.SPI_SLAVE
    port map (
        CLK      => CLK,
        RST      => RST,
        -- SPI MASTER INTERFACE
        SCLK_i     => sclk,
        nCS_i     => cs_n(0),
        MOSI_i     => mosi,
        MISO_o     => miso,
        -- USER INTERFACE
        SPI_data_i      => s_din,
        SPI_data_i_vld  => s_din_vld,
        IRQ_WT_o    => s_ready,
        SPI_data_o     => s_dout,
        SPI_data_o_vld => s_dout_vld
    );

    clk_process : process
    begin
        CLK <= '1';
        wait for CLK_PERIOD/2;
        CLK <= '0';
        wait for CLK_PERIOD/2;
    end process;

    rst_process : process
    begin
        RST <= '1';
        wait for 40 ns;
        RST <= '0';
        wait;
    end process;

    master_test_process : process
    begin
        m_addr <= (others => '0');
        m_din <= (others => 'Z');
        m_din_vld <= '0';
        m_din_last <= '0';

        wait until RST = '0';
        wait for 30 ns;
        wait until rising_edge(CLK);

        m_din <= X"12";
        m_din_vld <= '1';
        m_din_last <= '0';
        wait until m_ready = '0';

        m_din <= (others => '0');
        m_din_vld <= '0';

        wait until m_ready = '1';
        wait for 190 ns;
        wait until rising_edge(CLK);

        m_din <= X"F4";
        m_din_vld <= '1';
        m_din_last <= '1';
        wait until m_ready = '0';

        m_din <= X"47";
        m_din_vld <= '1';
        m_din_last <= '1';
        wait until m_ready = '0';

        m_din <= (others => '0');
        m_din_vld <= '0';

        wait;
    end process;

    slave_test_process : process
    begin
        s_din <= (others => 'Z');
        s_din_vld <= '0';

        wait until RST = '0';
        wait until rising_edge(CLK);

        s_din <= X"A1";
        s_din_vld <= '1';
        wait until m_ready = '0';

        s_din <= X"B2";
        s_din_vld <= '1';
        wait until m_ready = '0';

        s_din <= X"E8";
        s_din_vld <= '1';
        wait until m_ready = '0';

        s_din <= (others => '0');
        s_din_vld <= '0';

        wait;
    end process;

end SIM;
