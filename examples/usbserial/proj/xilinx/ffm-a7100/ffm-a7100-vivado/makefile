#vivado=/opt/Xilinx/Vivado/2015.3/bin/vivado
project=usbserial_ffm_a7100_v3r0_ffc_ca7_v2r0
xc3sprog_interface = ft4232h_fast
#xc3sprog_interface = ft4232h
# name of resulting bitstream file (*.bit)
bitfile=$(project).runs/impl_1/usbserial_ffm_a7100.bit

junk=*~
junk+=.Xil vivado.log vivado.jou ip_upgrade.log
junk+=$(project).ip_user_files
junk+=$(project).sim
junk+=$(project).cache

#junk+=$(project).srcs/sources_1/ip/clk_d100_108_216_541MHz/*.upgrade_log
#junk+=$(project).srcs/sources_1/ip/clk_d100_108_216_541MHz/*.v
#junk+=$(project).srcs/sources_1/ip/clk_d100_108_216_541MHz/*.vh
#junk+=$(project).srcs/sources_1/ip/clk_d100_108_216_541MHz/*.vhdl
#junk+=$(project).srcs/sources_1/ip/clk_d100_108_216_541MHz/*.dcp
#junk+=$(project).srcs/sources_1/ip/clk_d100_108_216_541MHz/*.xml
#junk+=$(project).srcs/sources_1/ip/clk_d100_108_216_541MHz/*.xdc
#junk+=$(project).srcs/sources_1/ip/clk_d100_108_216_541MHz/*.veo
#junk+=$(project).srcs/sources_1/ip/clk_d100_108_216_541MHz/*.vho
#junk+=$(project).srcs/sources_1/ip/clk_d100_108_216_541MHz/*.tcl
#junk+=$(project).srcs/sources_1/ip/clk_d100_108_216_541MHz/*.ncf
#junk+=$(project).srcs/sources_1/ip/clk_d100_108_216_541MHz/*.log
#junk+=$(project).srcs/sources_1/ip/clk_d100_108_216_541MHz/.Xil
#junk+=$(project).srcs/sources_1/ip/clk_d100_108_216_541MHz/doc
#junk+=$(project).srcs/sources_1/ip/clk_d100_108_216_541MHz/sim
#junk+=$(project).srcs/sources_1/ip/clk_d100_108_216_541MHz/synth
#junk+=$(project).srcs/sources_1/ip/clk_d100_108_216_541MHz/clk_wiz_v5_3_1

include ../../include/vivado.mk
