----------------------------------------------------------------------------
--! @file FE_CPLD_Microphone_Encoder_Decoder.vhd
--! @brief CPLD microphone array encoder/decoder component
--! @details This component translates data from a variable array of microphones as well as a temperature, humidity, 
--           pressure sensor and transmits that data to an decoder on another system.  The component also translates a
--           serial stream of data into commands to configure the microphone array.
--! @author Tyler Davis
--! @date 2020
--! @copyright Copyright 2020 Flat Earth Inc
--
--  Permission is hereby granted, free of charge, to any person obtaining a copy
--  of this software and associated documentation files (the "Software"), to deal
--  IN the Software without restriction, including without limitation the rights
--  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--  copies of the Software, and to permit persons to whom the Software is furnished
--  to do so, subject to the following conditions:
--
--  The above copyright notice and this permission notice shall be included IN all
--  copies or substantial portions of the Software.
--
--  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
--  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
--  PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
--  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
--  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
--  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- Tyler Davis
-- Flat Earth Inc
-- 985 Technology Blvd
-- Bozeman, MT 59718
-- support@flatearthinc.com
----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity FE_CPLD_Microphone_Encoder_Decoder is
  generic ( 
    avalon_data_width   : integer := 32;
    mic_data_width      : integer := 24;
    bme_data_width      : integer := 96;
    rgb_data_width      : integer := 16;
    cfg_data_width      : integer := 16;
    ch_width            : integer := 4;
    n_mics              : integer := 16
  );
  
  port (
    sys_clk               : in  std_logic                     := '0';
    reset_n               : in  std_logic                     := '0';
    
    busy_out              : out std_logic := '0';
        
    bme_input_data        : in std_logic_vector(bme_data_width-1 downto 0) := (others => '0');
    bme_input_valid       : in std_logic := '0';
    bme_input_error       : in std_logic_vector(1 downto 0) := (others => '0');
      
    mic_input_data        : in  std_logic_vector(avalon_data_width-1 downto 0) := (others => '0');
    mic_input_channel     : in  std_logic_vector(ch_width-1 downto 0)  := (others => '0');
    mic_input_error       : in  std_logic_vector(1 downto 0)  := (others => '0');
    mic_input_valid       : in  std_logic                     := '0';
      
    rgb_out_data          : out std_logic_vector(rgb_data_width-1 downto 0) := (others => '0');
    rgb_out_valid         : out std_logic := '0';
    rgb_out_error         : out std_logic_vector(1 downto 0) := (others => '0');

    cfg_out_data          : out std_logic_vector(cfg_data_width-1 downto 0) := (others => '0');
    cfg_out_valid         : out std_logic := '0';
    cfg_out_error         : out std_logic_vector(1 downto 0) := (others => '0');
          
    led_sd                : out std_logic                     := '0';
    led_ws                : out std_logic                     := '0';
          
    serial_data_out       : out std_logic;
    serial_data_in        : in std_logic                      := '0';
    serial_clk_in         : in  std_logic                     := '0'
  );
    
end entity FE_CPLD_Microphone_Encoder_Decoder;

architecture rtl of FE_CPLD_Microphone_Encoder_Decoder is

-- Instantiate the component that shifts the data
component Generic_Shift_Container
  generic (   
    data_width : integer := 8
  );
  port (
  clk         : in  std_logic;
  input_data  : in  std_logic_vector(data_width-1 downto 0);
  output_data : out std_logic_vector(data_width-1 downto 0);
  load        : in  std_logic
  );
end component;

-- Data byte width definitions
signal header_byte_width        : integer := 4;
signal packet_cntr_byte_width   : integer := 4;
signal n_mic_byte_width         : integer := 1;
signal temp_byte_width          : integer := 4;
signal humid_byte_width         : integer := 4;
signal pressure_byte_width      : integer := 4;
signal mic_byte_width           : integer := 3;
signal cfg_byte_width           : integer := 2;
signal rgb_byte_width           : integer := 2;

-- BME word division definitions
signal temp_byte_location       : integer := 12;
signal humid_byte_location      : integer := 8;
signal pressure_byte_location   : integer := 4;

-- Packet DATA_HEADER ID
signal header_width : integer := 32;
signal DATA_HEADER  : std_logic_vector(header_width-1 downto 0) := x"43504C44";
signal CMD_HEADER   : std_logic_vector(header_width-1 downto 0) := x"46504741";

-- Shift state signals
constant shift_width          : integer := 8;
signal shift_data             : std_logic_vector(31 downto 0) := (others => '0');
signal shift_data_in          : std_logic_vector(shift_width-1 downto 0) := (others => '0');
signal shift_data_out         : std_logic_vector(shift_width-1 downto 0) := (others => '0');
signal byte_counter           : integer range 0 to 4 := 0;
signal n_bytes                : integer range 0 to 4 := 0;
signal bit_counter            : integer range 0 to 7 := 0;
signal mic_counter            : integer range 0 to 64 := 0;
signal mic_counter_follower   : integer range 0 to 64 := 0;
signal shift_out              : std_logic;
signal shift_en_n             : std_logic := '0';
signal load_data              : std_logic := '0';
signal packet_counter         : unsigned(31 downto 0) := (others => '0');
signal sdo_mics               : integer range 0 to 64 := 16;

-- TODO change the "trigger" to start shifting
signal channel_trigger        : std_logic_vector(ch_width-1 downto 0) := std_logic_vector(to_unsigned(1,ch_width));


-- Deserialization signals
signal MAX_SDI_SIZE     : integer := 64;
signal parallel_data_r  : std_logic_vector(MAX_SDI_SIZE-1 downto 0) := (others => '0');
signal header_found     : std_logic := '0';
signal read_bits        : integer range 0 to MAX_SDI_SIZE := 0;
signal read_word_bits   : integer range 0 to MAX_SDI_SIZE := 0;


signal send_valid : std_logic := '0';
signal busy : std_logic := '0';

-- Control signals
signal start_shifting : std_logic := '0';
signal end_shifting   : std_logic := '0';
signal shift_busy     : std_logic := '0';

-- Avalon streaming signals
type mic_array_data is array (n_mics-1 downto 0) of std_logic_vector(mic_data_width-1 downto 0);
signal mic_input_data_r : mic_array_data := (others => (others => '0'));
signal bme_input_data_r : std_logic_vector(bme_data_width-1 downto 0) := (others => '0');
signal sdo_mics_r       : integer range 0 to 32 := 16;
signal cfg_data_r    : std_logic_vector(8*cfg_byte_width-1 downto 0) := (others => '0');
signal cfg_out_valid_r : std_logic := '0';
signal rgb_data_r       : std_logic_vector(8*rgb_byte_width-1 downto 0) := (others => '0');
signal rgb_out_valid_r : std_logic := '0';


-- Create states for the output state machine
type serializer_state is (  idle, load_header, load_packet_number, load_n_mics, load_temp, load_pressure, load_humidity,
                      load_mics, load_shift_reg, shift_wait );
-- Enable recovery from illegal state
attribute syn_encoding : string;
attribute syn_encoding of serializer_state : type is "safe";

signal cur_sdo_state  : serializer_state := idle;
signal next_sdo_state : serializer_state := idle;


-- Create the states for the deserialzier state machine
type deser_state is (idle, read_mics, read_enable, read_rgb, valid_pulse);

-- Enable recovery from illegal state
attribute syn_encoding of deser_state : type is "safe";

signal cur_sdi_state : deser_state := idle;

type valid_state is (idle, pulse, low_wait);

-- Enable recovery from illegal state
attribute syn_encoding of valid_state : type is "safe";

signal sdi_valid_state : valid_state := idle;

begin 

-- Create a serializer for the data using the shift width
serial_shift_map: Generic_Shift_Container    
generic map (
  data_width => shift_width
)
port map (  
  clk => serial_clk_in,
  input_data  => shift_data_in,
  output_data => shift_data_out,
  load => load_data
);

-- Process to push the data into the register
mic_in_process : process(sys_clk,reset_n)
begin 
  if reset_n = '0' then 
    mic_input_data_r <= (others => (others => '0'));
  elsif rising_edge(sys_clk) then 
    -- Accept new data only when the valid is asserted
    --if mic_input_valid = '1' and busy = '0' then 
    if mic_input_valid = '1' then 
      mic_input_data_r(to_integer(unsigned(mic_input_channel))) <= mic_input_data;
      
    -- Otherwise, reset the write enable and keep the current data
    else
      mic_input_data_r <= mic_input_data_r;
    end if;
  end if;
end process;

bme_in_process : process(sys_clk,reset_n)
begin 
  if reset_n = '0' then 
    bme_input_data_r <= (others => '0');
  elsif rising_edge(sys_clk) then 
    --if bme_input_valid = '1' and busy = '0'  then 
    if bme_input_valid = '1'  then 
      bme_input_data_r <= bme_input_data;
    else
      bme_input_data_r <= bme_input_data_r;
    end if;
  end if;
end process;

-- Process to start the bit shifting 
shift_start_process : process(serial_clk_in,reset_n)
begin 
  if reset_n = '0' then 
    start_shifting <= '0';
    shift_busy <= '0';
  elsif rising_edge(serial_clk_in) then 
  
    -- When the first data packet is received, start shifting the DATA_HEADER out
    if mic_input_channel(ch_width-1 downto 0) = channel_trigger then -- TODO: Find a better start condition.
      start_shifting <= '1';
      packet_counter <= packet_counter + 1;
    else
      start_shifting <= '0';
    end if;
    
    -- When the shifting has started, assert the shift busy signal
    if start_shifting = '1' then 
      shift_busy <= '1';
      
    -- When the final bit has been shifted, assert the end shifting signal
    elsif end_shifting = '1' then 
      shift_busy <= '0';
    else
      shift_busy <= shift_busy;
    end if;  
  end if;
end process;

data_out_transition_process : process(serial_clk_in,reset_n)
begin
  if reset_n = '0' then 
    cur_sdo_state   <= idle;
    next_sdo_state  <= idle;
  elsif rising_edge(serial_clk_in) then 
    case cur_sdo_state is 
      when idle => 
        -- Wait for the start_shifting signal to load the header
        if start_shifting = '1' then 
          cur_sdo_state <= load_header;
          
        -- Otherwise, stay idle
        else  
          cur_sdo_state <= idle;
        end if;
        
      when load_header =>
        -- Transition to the shift states, then set the next state to load 
        cur_sdo_state <= load_shift_reg;
        next_sdo_state <= load_packet_number;
        
      when load_packet_number =>
        -- Transition to the shift states, then set the next state
        cur_sdo_state <= load_shift_reg;
        next_sdo_state <= load_n_mics;
        
      when load_n_mics =>
        -- Transition to the shift states, then set the next state
        cur_sdo_state <= load_shift_reg;
        next_sdo_state <= load_temp;
        
      when load_temp =>
        -- Transition to the shift states, then set the next state
        cur_sdo_state <= load_shift_reg;
        next_sdo_state <= load_pressure;
        
      when load_pressure =>
        -- Transition to the shift states, then set the next state
        cur_sdo_state <= load_shift_reg;
        next_sdo_state <= load_humidity;
        
      when load_humidity =>
        -- Transition to the shift states, then set the next state
        cur_sdo_state <= load_shift_reg;
        next_sdo_state <= load_mics;
        
      when load_mics =>
        -- Transition to the shift states, decide whether another set of mic data needs to be loaded
        cur_sdo_state <= load_shift_reg;
        
        -- If the last mic data hasn't been loaded, keep loading the mics
        if mic_counter < sdo_mics - 1 then 
          next_sdo_state <= load_mics;
        
        -- Otherwise, go idle after the transfer
        else
          next_sdo_state <= idle;
        end if;
      
      
      when load_shift_reg =>
        -- Immediately transition to the wait state
        cur_sdo_state <= shift_wait;
      
      when shift_wait =>
        -- If the specified number of bytes have been sent, transition to the next load state before the shift register 
        -- "empties"
        if byte_counter = n_bytes and bit_counter = shift_width - 3 then 
          cur_sdo_state <= next_sdo_state;
          
        -- If there are still more bytes to load, load the next byte into the register
        elsif byte_counter < n_bytes and bit_counter = shift_width - 2 then 
          cur_sdo_state <= load_shift_reg;
          
        -- Otherwise, stay in the wait state
        else
          cur_sdo_state <= shift_wait;
        end if;

      when others => 
    
    end case;
  end if;
end process;

data_out_process : process(serial_clk_in,reset_n)
begin
  if reset_n = '0' then 

  elsif rising_edge(serial_clk_in) then 
    case cur_sdo_state is 
      when idle => 
        -- Reset the counters and signal the component is no longer busy
        bit_counter   <= 0;
        mic_counter <= 0;
        busy <= '0';
        
      when load_header =>
        -- Load the header into the shift register
        shift_data <= DATA_HEADER;
        
        -- Set the number of bytes to transfer and reset the byte counter
        n_bytes <= header_byte_width;
        byte_counter <= 0;
        
      when load_packet_number =>
        -- Load the packet counter into the shift register
        shift_data <= std_logic_vector(packet_counter);
        
        -- Set the number of bytes to transfer and reset the byte counter
        n_bytes <= packet_cntr_byte_width;
        byte_counter <= 0;
        
      when load_n_mics =>
        -- Load the number of mics into the shift register
        shift_data(7 downto 0) <= std_logic_vector(to_unsigned(sdo_mics,8));
        -- Set the number of bytes to transfer and reset the byte counter
        n_bytes <= n_mic_byte_width;
        byte_counter <= 0;
        
      when load_temp =>
        -- Load the temperature into the shift register
        shift_data(8*temp_byte_width-1 downto 0) <= bme_input_data_r(8*temp_byte_location-1 downto 8*(temp_byte_location-temp_byte_width));
        
        -- Set the number of bytes to transfer and reset the byte counter
        n_bytes <= temp_byte_width;
        byte_counter <= 0;
        
      when load_pressure =>
        -- Load the pressure into the shift register
        shift_data(8*pressure_byte_width-1 downto 0) <= bme_input_data_r(8*pressure_byte_location-1 downto 8*(pressure_byte_location-pressure_byte_width));
        
        -- Set the number of bytes to transfer and reset the byte counter
        n_bytes <= pressure_byte_width;
        byte_counter <= 0;
        
      when load_humidity =>
        -- Load the humidity into the shift register
        shift_data(8*humid_byte_width-1 downto 0) <= bme_input_data_r(8*humid_byte_location-1 downto 8*(humid_byte_location-humid_byte_width));
        
        -- Set the number of bytes to transfer and reset the byte counter
        n_bytes <= humid_byte_width;
        byte_counter <= 0;
      
      when load_mics =>
        -- Load the next microphone into the shift register
        mic_counter <= mic_counter + 1;
        shift_data(8*mic_byte_width-1 downto 0) <= mic_input_data_r(mic_counter_follower);
        
        -- Set the number of bytes to transfer and reset the byte counter
        n_bytes <= mic_byte_width;
        byte_counter <= 0;
      
      when load_shift_reg =>
        -- Update the microphone follower
        mic_counter_follower <= mic_counter;
        
        -- Reset the bit counter and increment the byte counter
        bit_counter <= 0;
        byte_counter <= byte_counter + 1;
        
        -- Load the next set of data into the shift component
        shift_data_in <= shift_data(8*(n_bytes-byte_counter)-1 downto 8*(n_bytes-byte_counter-1));
        load_data <= '1';
        
        -- Signal the component is busy
        busy <= '1';
      
      when shift_wait =>
        -- Increment the bit counter and reset the shift component load signal
        bit_counter <= bit_counter + 1;
        load_data <= '0';
      
      when others => 
    
    end case;
  end if;
end process;


shift_process: process(serial_clk_in,reset_n)
begin
  if reset_n = '0' then 
    parallel_data_r <= (others => '0');
  elsif rising_edge(serial_clk_in) then 
    -- Always shift the new serial bit into the end of the register
    parallel_data_r <= parallel_data_r(MAX_SDI_SIZE-2 downto 0) & serial_data_in;
  end if;
end process;

bit_counter_process : process(serial_clk_in,reset_n)
begin 
  if reset_n = '0' then 
    read_bits <= 0;
    
  elsif rising_edge(serial_clk_in) then 
    -- If the input state machine is idle, don't count the bits coming into the component
    if cur_sdi_state = idle then 
      read_bits <= 1;
      
    -- When the counter reaches the current number of expected bits, reset it
    elsif read_bits = read_word_bits - 1 then 
      read_bits <= 0;
      
    -- Otherwise, increment the bit counter
    else
      read_bits <= read_bits + 1;
    end if;
  end if;
end process;

data_in_transition_process : process(serial_clk_in, reset_n)
begin 
  if reset_n = '0' then 
  
  elsif rising_edge(serial_clk_in) then 
    case cur_sdi_state is
    
      when idle => 
        -- If the header has been read, transition to reading the number of mics
        if parallel_data_r(8*header_byte_width-1 downto 0) = CMD_HEADER then
          cur_sdi_state <= read_mics;
          
        -- Otherwise, remain idle
        else
          cur_sdi_state <= idle;
        end if;
        
      when read_mics =>
        -- Once the number of microphones have been read, read the mic configuration
        if read_bits = read_word_bits - 2 then 
          cur_sdi_state <= read_enable;
        else
          cur_sdi_state <= read_mics;
        end if;
      
      when read_enable =>
        -- Once the mic configuration has been read, read the rgb configuration
        if read_bits = read_word_bits - 2 then 
          cur_sdi_state <= read_rgb;
        else
          cur_sdi_state <= read_enable;
        end if;
      
      when read_rgb =>
        -- Once the rbg LED configuration has been read, send the valid pulse
        if read_bits = read_word_bits - 2 then 
          cur_sdi_state <= valid_pulse;
        else
          cur_sdi_state <= read_rgb;
        end if;
      
      -- Immediately go idle
      when valid_pulse =>
        cur_sdi_state <= idle;
        
      when others =>
    end case;
  end if;
end process;

data_in_process : process(serial_clk_in, reset_n)
begin 
  if reset_n = '0' then 
  
  elsif rising_edge(serial_clk_in) then 
    case cur_sdi_state is
      when idle => 
        send_valid <= '0';

      when read_mics =>
        -- "Shift in" the number of microphones
        sdo_mics_r <= to_integer(unsigned(parallel_data_r(8*n_mic_byte_width-1 downto 0)));
        read_word_bits <= 8*n_mic_byte_width;

      when read_enable =>
        -- "Shift in" the mic configuration
        cfg_data_r <= parallel_data_r(8*cfg_byte_width-1 downto 0);
        read_word_bits <= 8*cfg_byte_width;
      
      when read_rgb =>
        -- "Shift in" the rbg LED configuration 
        rgb_data_r <= parallel_data_r(8*rgb_byte_width-1 downto 0);
        read_word_bits <= 8*rgb_byte_width;

      when valid_pulse =>
        --sdo_mics <= sdo_mics_r;
        send_valid <= '1';
               
      when others =>
    end case;
  end if;
end process;

sdi_data_valid_transition_process : process(sys_clk,reset_n)
begin
  if reset_n = '0' then 
    sdi_valid_state <= idle;
  elsif rising_edge(sys_clk) then 
    case sdi_valid_state is 
    
      when idle =>
        -- Once the data has been read in, send a valid pulse at the system clock frequency (Avalon streaming)
        if send_valid = '1' then 
          sdi_valid_state <= pulse;
          
        -- Otherwise, stay idle
        else
          sdi_valid_state <= idle;
        end if;
      
      when pulse => 
        -- Transition to the wait state
        sdi_valid_state <= low_wait;
        
      when low_wait =>
        -- When "send" signal goes low (slower clock frequency), go idle again
        if send_valid = '0' then 
          sdi_valid_state <= idle;
          
        -- Otherwise, wait for the valid to go low
        else
          sdi_valid_state <= low_wait;
        end if;
        
      when others =>    
    end case;
  end if;
end process; 

sdi_data_valid_process : process(sys_clk,reset_n)
begin
  if reset_n = '0' then 
      rgb_out_valid_r <= '0';
      cfg_out_valid_r <= '0';
  elsif rising_edge(sys_clk) then 
    case sdi_valid_state is 
      when idle =>
        -- Do nothing
        
      when pulse => 
        -- Pulse the valid Avalon streaming signals
        rgb_out_valid_r <= '1';
        cfg_out_valid_r <= '1';
        
      when low_wait =>
        rgb_out_valid_r <= '0';
        cfg_out_valid_r <= '0';
        
    end case;
  end if;
end process;

-- Map the RJ45 signals to the output ports
serial_data_out <= shift_data_out(shift_width-1);

-- Map the busy signal 
busy_out <= busy;

-- Map the valid signals
rgb_out_valid <= rgb_out_valid_r; 
cfg_out_valid <= cfg_out_valid_r;

-- Map the data signals
cfg_out_data <= cfg_data_r;
rgb_out_data <= rgb_data_r;

end architecture rtl;























































