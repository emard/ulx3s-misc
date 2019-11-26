library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.std_logic_unsigned.ALL;

use work.report_decoded_pack.all;

entity usbhid_report_decoder is
generic
(
  C_reg_input: boolean := true; -- take input in register (release timing)
  -- mouse speed also depends on clk
  C_lmouse: boolean := false;
  C_lmousex_scaler: integer := 23; -- less -> faster mouse
  C_lmousey_scaler: integer := 23; -- less -> faster mouse
  C_rmouse: boolean := false;
  C_rmousex_scaler: integer := 23; -- less -> faster mouse
  C_rmousey_scaler: integer := 23  -- less -> faster mouse
);
port
(
  clk: in std_logic; -- USB host core clock domain
  hid_report: in std_logic_vector;
  hid_valid: in std_logic;
  decoded: out T_report_decoded
);
end;

architecture rtl of usbhid_report_decoder is
  signal R_hid_report: std_logic_vector(hid_report'range);
  signal R_hid_valid: std_logic;
  alias S_lstick_x: std_logic_vector(7 downto 0) is R_hid_report(15 downto 8);
  alias S_lstick_y: std_logic_vector(7 downto 0) is R_hid_report(23 downto 16);
  alias S_rstick_x: std_logic_vector(7 downto 0) is R_hid_report(31 downto 24);
  alias S_rstick_y: std_logic_vector(7 downto 0) is R_hid_report(39 downto 32);
  alias S_analog_trigger: std_logic_vector(5 downto 0) is R_hid_report(45 downto 40);
  alias S_btn_x: std_logic is R_hid_report(46);
  alias S_btn_a: std_logic is R_hid_report(47);
  alias S_btn_b: std_logic is R_hid_report(48);
  alias S_btn_y: std_logic is R_hid_report(49);
  alias S_btn_lbumper: std_logic is R_hid_report(50);
  alias S_btn_rbumper: std_logic is R_hid_report(51);
  alias S_btn_ltrigger: std_logic is R_hid_report(52);
  alias S_btn_rtrigger: std_logic is R_hid_report(53);
  alias S_btn_back: std_logic is R_hid_report(54);
  alias S_btn_start: std_logic is R_hid_report(55);
  alias S_btn_lstick: std_logic is R_hid_report(56);
  alias S_btn_rstick: std_logic is R_hid_report(57);
  alias S_btn_fps: std_logic is R_hid_report(58);
  alias S_btn_fps_toggle: std_logic is R_hid_report(59);
  alias S_hat: std_logic_vector(3 downto 0) is R_hid_report(63 downto 60);
  signal S_hat_udlr: std_logic_vector(3 downto 0); -- decoded
  alias S_hat_up: std_logic is S_hat_udlr(3);
  alias S_hat_down: std_logic is S_hat_udlr(2);
  alias S_hat_left: std_logic is S_hat_udlr(1);
  alias S_hat_right: std_logic is S_hat_udlr(0);
  -- decoded stick to digital
  signal S_lstick_up, S_lstick_down, S_lstick_left, S_lstick_right: std_logic;
  signal S_rstick_up, S_rstick_down, S_rstick_left, S_rstick_right: std_logic;
  signal R_lmousecx: std_logic_vector(C_lmousex_scaler-1 downto 0);
  signal R_lmousecy: std_logic_vector(C_lmousey_scaler-1 downto 0);
  signal R_rmousecx: std_logic_vector(C_rmousex_scaler-1 downto 0);
  signal R_rmousecy: std_logic_vector(C_rmousey_scaler-1 downto 0);
begin

  yes_reg_input: if C_reg_input generate
  process(clk) is
  begin
    if rising_edge(clk) then
      if hid_valid = '1' then
        R_hid_report <= hid_report; -- register to release timing closure
      end if;
      R_hid_valid <= hid_valid;
    end if;
  end process;
  end generate;

  no_reg_input: if not C_reg_input generate
    R_hid_report <= hid_report; -- directly take input
    R_hid_valid <= hid_valid;
  end generate;

  -- simple buttons
  decoded.btn_x <= S_btn_x;
  decoded.btn_a <= S_btn_a;
  decoded.btn_b <= S_btn_b;
  decoded.btn_y <= S_btn_y;
  decoded.btn_lbumper <= S_btn_lbumper;
  decoded.btn_rbumper <= S_btn_rbumper;
  decoded.btn_ltrigger <= S_btn_ltrigger;
  decoded.btn_rtrigger <= S_btn_rtrigger;
  decoded.btn_back <= S_btn_back;
  decoded.btn_start <= S_btn_start;
  decoded.btn_lstick <= S_btn_lstick;
  decoded.btn_rstick <= S_btn_rstick;
  decoded.btn_fps <= S_btn_fps;
  decoded.btn_fps_toggle <= S_btn_fps_toggle;

  -- hat decoder 
  S_hat_udlr <= "1000" when S_hat = "0000" else -- up
                "1001" when S_hat = "0001" else -- up+right
                "0001" when S_hat = "0010" else -- right
                "0101" when S_hat = "0011" else -- down+right
                "0100" when S_hat = "0100" else -- down
                "0110" when S_hat = "0101" else -- down+left
                "0010" when S_hat = "0110" else -- left
                "1010" when S_hat = "0111" else -- up+left
                "0000";          -- "1111" when not pressed

  -- hat as buttons
  decoded.hat_up <= S_hat_up;
  decoded.hat_down <= S_hat_down;
  decoded.hat_left <= S_hat_left;
  decoded.hat_right <= S_hat_right;

  -- analog stick to digital decoders
  decoded.lstick_left  <= '1' when S_lstick_x(7 downto 6) = "00" else '0';
  decoded.lstick_right <= '1' when S_lstick_x(7 downto 6) = "11" else '0';
  decoded.lstick_up    <= '1' when S_lstick_y(7 downto 6) = "00" else '0';
  decoded.lstick_down  <= '1' when S_lstick_y(7 downto 6) = "11" else '0';
  decoded.rstick_left  <= '1' when S_rstick_x(7 downto 6) = "00" else '0';
  decoded.rstick_right <= '1' when S_rstick_x(7 downto 6) = "11" else '0';
  decoded.rstick_up    <= '1' when S_rstick_y(7 downto 6) = "00" else '0';
  decoded.rstick_down  <= '1' when S_rstick_y(7 downto 6) = "11" else '0';

  decoded.analog_ltrigger(7 downto 2) <=     S_analog_trigger;
  decoded.analog_rtrigger(7 downto 2) <= not S_analog_trigger;
  
  yes_lmouse: if C_lmouse generate
  -- mouse counters
  process(clk)
  begin
      if rising_edge(clk) then
        R_lmousecx <= R_lmousecx+S_lstick_x-128;
        R_lmousecy <= R_lmousecy+S_lstick_y-128;
      end if;
  end process;

  decoded.btn_lmouse_left  <= S_btn_lstick;
  decoded.btn_lmouse_right <= S_btn_lbumper;
  -- mouse quadrature encoders
  decoded.lmouseq_x  <= "01" when R_lmousecx(R_lmousecx'high downto R_lmousecx'high-1) = "00" else
                        "11" when R_lmousecx(R_lmousecx'high downto R_lmousecx'high-1) = "01" else
                        "10" when R_lmousecx(R_lmousecx'high downto R_lmousecx'high-1) = "10" else
                        "00"; -- when "11"
  decoded.lmouseq_y  <= "01" when R_lmousecy(R_lmousecy'high downto R_lmousecy'high-1) = "00" else
                        "11" when R_lmousecy(R_lmousecy'high downto R_lmousecy'high-1) = "01" else
                        "10" when R_lmousecy(R_lmousecy'high downto R_lmousecy'high-1) = "10" else
                        "00"; -- when "11"
  end generate;

  yes_rmouse: if C_rmouse generate
  -- mouse counters
  process(clk)
  begin
      if rising_edge(clk) then
        R_rmousecx <= R_rmousecx+S_rstick_x-128;
        R_rmousecy <= R_rmousecy+S_rstick_y-128;
      end if;
  end process;

  decoded.btn_rmouse_left  <= S_btn_rstick;
  decoded.btn_rmouse_right <= S_btn_rbumper;
  -- mouse quadrature encoders
  decoded.rmouseq_x  <= "01" when R_rmousecx(R_rmousecx'high downto R_rmousecx'high-1) = "00" else
                        "11" when R_rmousecx(R_rmousecx'high downto R_rmousecx'high-1) = "01" else
                        "10" when R_rmousecx(R_rmousecx'high downto R_rmousecx'high-1) = "10" else
                        "00"; -- when "11"
  decoded.rmouseq_y  <= "01" when R_rmousecy(R_rmousecy'high downto R_rmousecy'high-1) = "00" else
                        "11" when R_rmousecy(R_rmousecy'high downto R_rmousecy'high-1) = "01" else
                        "10" when R_rmousecy(R_rmousecy'high downto R_rmousecy'high-1) = "10" else
                        "00"; -- when "11"
  end generate;
  
end rtl;
