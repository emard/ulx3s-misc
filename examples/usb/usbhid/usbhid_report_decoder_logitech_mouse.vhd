library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.std_logic_unsigned.ALL;

use work.report_decoded_pack.all;

entity usbhid_report_decoder is
generic
(
  C_reg_input: boolean := false; -- take input in register (release timing)
  -- mouse speed also depends on clk
  C_lmouse: boolean := false;
  C_lmousex_scaler: integer := 24; -- not used
  C_lmousey_scaler: integer := 24; -- not used
  C_rmouse: boolean := false;
  C_rmousex_scaler: integer := 24; -- not used
  C_rmousey_scaler: integer := 24  -- not used
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
  constant S_lstick_x: std_logic_vector(7 downto 0) := (others => '0');
  constant S_lstick_y: std_logic_vector(7 downto 0) := (others => '0');
  constant S_rstick_x: std_logic_vector(7 downto 0) := (others => '0');
  constant S_rstick_y: std_logic_vector(7 downto 0) := (others => '0');
  constant S_analog_trigger: std_logic_vector(5 downto 0) := (others => '0');
  constant S_btn_x: std_logic := '0';
  constant S_btn_a: std_logic := '0';
  constant S_btn_b: std_logic := '0';
  constant S_btn_y: std_logic := '0';
  constant S_btn_lbumper: std_logic := '0';
  constant S_btn_rbumper: std_logic := '0';
  constant S_btn_ltrigger: std_logic := '0';
  constant S_btn_rtrigger: std_logic := '0';
  constant S_btn_back: std_logic := '0';
  constant S_btn_start: std_logic := '0';
  constant S_btn_lstick: std_logic := '0';
  constant S_btn_rstick: std_logic := '0';
  constant S_btn_fps: std_logic := '0';
  constant S_btn_fps_toggle: std_logic := '0';
  constant S_hat: std_logic_vector(3 downto 0) := (others => '1');
  signal S_hat_udlr: std_logic_vector(3 downto 0); -- decoded
  alias S_hat_up: std_logic is S_hat_udlr(3);
  alias S_hat_down: std_logic is S_hat_udlr(2);
  alias S_hat_left: std_logic is S_hat_udlr(1);
  alias S_hat_right: std_logic is S_hat_udlr(0);
  alias S_mouse_btn_left: std_logic is R_hid_report(0); -- mouse left click
  alias S_mouse_btn_right: std_logic is R_hid_report(1); -- mouse right click
  alias S_mouse_rel_x: std_logic_vector(7 downto 0) is R_hid_report(15 downto 8);
  alias S_mouse_rel_y: std_logic_vector(7 downto 0) is R_hid_report(23 downto 16);
  alias S_mouse_rel_z: std_logic_vector(7 downto 0) is R_hid_report(31 downto 24);
  signal R_rarify_mouse: std_logic_vector(11 downto 0);
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

  -- simple buttons (for mouse all 0)
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


  process(clk)
  begin
      if rising_edge(clk) then
        if R_rarify_mouse(R_rarify_mouse'high) = '0' then
          R_rarify_mouse <= R_rarify_mouse + 1;
        else
          R_rarify_mouse <= (others => '0');
        end if;
      end if;
  end process;

  yes_lmouse: if C_lmouse generate
  B_lmouse: block
    signal R_lmousecx: std_logic_vector(7 downto 0);
    signal R_lmousecy: std_logic_vector(7 downto 0);
    signal R_tlmousecx: std_logic_vector(7 downto 0);
    signal R_tlmousecy: std_logic_vector(7 downto 0);
    signal S_dlmousecx: std_logic_vector(7 downto 0);
    signal S_dlmousecy: std_logic_vector(7 downto 0);
  begin
  S_dlmousecx <= R_tlmousecx - R_lmousecx;
  S_dlmousecy <= R_tlmousecy - R_lmousecy;
  -- mouse counters
  process(clk)
  begin
      if rising_edge(clk) then
        if R_hid_valid = '1' then
          R_tlmousecx <= R_tlmousecx + S_mouse_rel_x;
          R_tlmousecy <= R_tlmousecy + S_mouse_rel_y;
        end if;
        if R_rarify_mouse(R_rarify_mouse'high) = '1' then
          if S_dlmousecx /= x"00" then
            if S_dlmousecx(S_dlmousecx'high) = '1' then
              R_lmousecx <= R_lmousecx - 1;
            else
              R_lmousecx <= R_lmousecx + 1;
            end if;
          end if;
          if S_dlmousecy /= x"00" then
            if S_dlmousecy(S_dlmousecy'high) = '1' then
              R_lmousecy <= R_lmousecy - 1;
            else
              R_lmousecy <= R_lmousecy + 1;
            end if;
          end if;
        end if;
      end if;
  end process;

  decoded.btn_lmouse_left  <= S_mouse_btn_left;
  decoded.btn_lmouse_right <= S_mouse_btn_right;
  -- mouse quadrature encoders
  decoded.lmouseq_x  <= "01" when R_lmousecx(1 downto 0) = "00" else
                        "11" when R_lmousecx(1 downto 0) = "01" else
                        "10" when R_lmousecx(1 downto 0) = "10" else
                        "00"; -- when "11"
  decoded.lmouseq_y  <= "01" when R_lmousecy(1 downto 0) = "00" else
                        "11" when R_lmousecy(1 downto 0) = "01" else
                        "10" when R_lmousecy(1 downto 0) = "10" else
                        "00"; -- when "11"
  end block;
  end generate;

  yes_rmouse: if C_rmouse generate
  B_rmouse: block
    signal R_rmousecx: std_logic_vector(7 downto 0);
    signal R_rmousecy: std_logic_vector(7 downto 0);
    signal R_trmousecx: std_logic_vector(7 downto 0);
    signal R_trmousecy: std_logic_vector(7 downto 0);
    signal S_drmousecx: std_logic_vector(7 downto 0);
    signal S_drmousecy: std_logic_vector(7 downto 0);
  begin
  S_drmousecx <= R_trmousecx - R_rmousecx;
  S_drmousecy <= R_trmousecy - R_rmousecy;
  -- mouse counters
  process(clk)
  begin
      if rising_edge(clk) then
        if R_hid_valid = '1' then
          R_trmousecx <= R_trmousecx + S_mouse_rel_x;
          R_trmousecy <= R_trmousecy + S_mouse_rel_y;
        end if;
        if R_rarify_mouse(R_rarify_mouse'high) = '1' then
          if S_drmousecx /= x"00" then
            if S_drmousecx(S_drmousecx'high) = '1' then
              R_rmousecx <= R_rmousecx - 1;
            else
              R_rmousecx <= R_rmousecx + 1;
            end if;
          end if;
          if S_drmousecy /= x"00" then
            if S_drmousecy(S_drmousecy'high) = '1' then
              R_rmousecy <= R_rmousecy - 1;
            else
              R_rmousecy <= R_rmousecy + 1;
            end if;
          end if;
        end if;
      end if;
  end process;

  decoded.btn_rmouse_left  <= S_mouse_btn_left;
  decoded.btn_rmouse_right <= S_mouse_btn_right;
  -- mouse quadrature encoders
  decoded.rmouseq_x  <= "01" when R_rmousecx(1 downto 0) = "00" else
                        "11" when R_rmousecx(1 downto 0) = "01" else
                        "10" when R_rmousecx(1 downto 0) = "10" else
                        "00"; -- when "11"
  decoded.rmouseq_y  <= "01" when R_rmousecy(1 downto 0) = "00" else
                        "11" when R_rmousecy(1 downto 0) = "01" else
                        "10" when R_rmousecy(1 downto 0) = "10" else
                        "00"; -- when "11"
  end block;
  end generate;
  
end rtl;
