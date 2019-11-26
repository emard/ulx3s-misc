-- (c) EMARD
-- License=BSD

library ieee;
use ieee.std_logic_1164.all;

package report_decoded_pack is
type T_report_decoded is
record
  lstick_x, lstick_y, rstick_x, rstick_y: std_logic_vector(7 downto 0); -- up/left=0 idle=128 down/right=255
  lmouseq_x, lmouseq_y, rmouseq_x, rmouseq_y: std_logic_vector(1 downto 0); -- stick to quadrature encoder output
  analog_ltrigger, analog_rtrigger: std_logic_vector(7 downto 0);
  hat_up, hat_down, hat_left, hat_right: std_logic;
  lstick_up, lstick_down, lstick_left, lstick_right: std_logic;
  rstick_up, rstick_down, rstick_left, rstick_right: std_logic;
  btn_a, btn_b, btn_x, btn_y: std_logic;
  btn_lbumper, btn_rbumper: std_logic;
  btn_ltrigger, btn_rtrigger: std_logic;
  btn_back, btn_start: std_logic;
  btn_lstick, btn_rstick: std_logic;
  btn_fps, btn_fps_toggle: std_logic;
  btn_lmouse_left, btn_lmouse_right: std_logic;
  btn_rmouse_left, btn_rmouse_right: std_logic;
end record;
end;
