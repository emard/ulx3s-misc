#vivado=/opt/Xilinx/Vivado/2015.3/bin/vivado
project=blinky
xc3sprog_interface = ft4232h_fast
#xc3sprog_interface = ft4232h
# name of resulting bitstream file (*.bit)
bitfile=$(project).runs/impl_1/blinky.bit

junk=*~
junk+=.Xil vivado.log vivado.jou ip_upgrade.log
junk+=$(project).ip_user_files
junk+=$(project).sim
junk+=$(project).cache

junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.upgrade_log
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.v
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.vhdl
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.dcp
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.xml
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.xdc
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.veo
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.vho
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.tcl
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.ncf
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.log
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/doc
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/sim
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/synth
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/clk_wiz_v5_3_1

include vivado.mk
