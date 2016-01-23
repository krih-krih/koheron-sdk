source scripts/bram.tcl
source projects/base/init_bd.tcl
source boards/$board_name/gpio.tcl
source projects/base/config_register.tcl
source projects/base/status_register.tcl
source boards/$board_name/pwm.tcl
source projects/base/address.tcl
source projects/base/xadc.tcl

set board_preset boards/$board_name/config/board_preset.xml

##########################################################
# Define global variables
##########################################################
set ps_name        ps_1

set rst_name       rst_${ps_name}_125M


##########################################################
# Define block names
##########################################################
set xadc_name      xadc_wiz_0
set config_name    cfg
set status_name    sts
set address_name   address
set dac_bram_name  dac_bram
set adc1_bram_name adc1_bram
set avg_name       averaging

##########################################################
# Define parameters
##########################################################
set dac_width       14
set adc_width       14

##########################################################
# Init block design and add DAC BRAM
##########################################################
init_bd $board_preset $dac_bram_name $bram_size

##########################################################
# Add GPIO
##########################################################
add_gpio

##########################################################
# Add ADCs and DACs
##########################################################
source boards/$board_name/adc_dac.tcl
# Rename clocks
set adc_clk adc_dac/adc_clk
set pwm_clk adc_dac/pwm_clk

# Add Configuration register (synchronous with ADC clock)
##########################################################
add_config_register $config_name $adc_clk 16

##########################################################
# Add Status register
##########################################################
add_status_register $status_name $adc_clk 4

##########################################################
# Connect LEDs
##########################################################
cell xilinx.com:ip:xlslice:1.0 led_slice {
  DIN_WIDTH 32
  DIN_FROM  7
  DIN_TO    0
} {
  Din $config_name/Out[expr $led_offset]
}
connect_bd_net [get_bd_ports led_o] [get_bd_pins led_slice/Dout]

##########################################################
# Add XADC
##########################################################
add_xadc $xadc_name

##########################################################
# Add EEPROM
##########################################################

### EEPROM

create_bd_port -dir I eeprom_do
create_bd_port -dir O eeprom_di
create_bd_port -dir O eeprom_sk
create_bd_port -dir O eeprom_cs

create_bd_cell -type ip -vlnv koheron:user:at93c46d_spi:1.0 at93c46d_spi_0
connect_bd_net [get_bd_ports eeprom_do] [get_bd_pins at93c46d_spi_0/dout]
connect_bd_net [get_bd_ports eeprom_cs] [get_bd_pins at93c46d_spi_0/cs]
connect_bd_net [get_bd_ports eeprom_sk] [get_bd_pins at93c46d_spi_0/sclk]
connect_bd_net [get_bd_ports eeprom_di] [get_bd_pins at93c46d_spi_0/din]

connect_pins at93c46d_spi_0/clk $adc_clk

create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 slice_start_eeprom
connect_pins slice_start_eeprom/Dout at93c46d_spi_0/start
connect_pins slice_start_eeprom/Din $config_name/Out8

create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 slice_cmd_eeprom
set_property -dict [list CONFIG.DIN_TO {1} CONFIG.DIN_FROM {8}] [get_bd_cells slice_cmd_eeprom]
connect_pins slice_cmd_eeprom/Dout at93c46d_spi_0/cmd
connect_pins slice_cmd_eeprom/Din $config_name/Out8

create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 slice_data_in_eeprom
set_property -dict [list CONFIG.DIN_TO {16} CONFIG.DIN_FROM {31}] [get_bd_cells slice_data_in_eeprom]
connect_pins slice_data_in_eeprom/Dout at93c46d_spi_0/data_in
connect_pins slice_data_in_eeprom/Din $config_name/Out8

connect_pins at93c46d_spi_0/data_out $status_name/In2

##########################################################
# Add PWM
##########################################################
add_pwm pwm $pwm_clk $pwm0_offset $pwm_width 4
connect_pins pwm/cfg  $config_name/cfg
for {set i 0} {$i < $n_pwm} {incr i} {
  set offset pwm${i}_offset
  connect_pins pwm/pwm$i  $config_name/Out[expr $$offset]
}

##########################################################
# Add address module
##########################################################
add_address_module $address_name $bram_addr_width $adc_clk
connect_pins $address_name/clk  $adc_clk
connect_pins $address_name/cfg  $config_name/Out$addr_offset

##########################################################
# DAC BRAM
##########################################################

# Connect port B of BRAM to ADC clock
connect_pins blk_mem_gen_$dac_bram_name/clkb    $adc_clk
connect_pins blk_mem_gen_$dac_bram_name/addrb   $address_name/addr
# Connect BRAM output to DACs
for {set i 0} {$i < 2} {incr i} {
  set channel [lindex {a b} $i]
  cell xilinx.com:ip:xlslice:1.0 dac_${channel}_slice {
    DIN_WIDTH 32
    DIN_FROM [expr $dac_width-1+16*$i]
    DIN_TO [expr 16*$i]
  } {
    Din blk_mem_gen_$dac_bram_name/doutb
    Dout adc_dac/dac/dac_dat_${channel}_i
  }
}
# Connect remaining ports of BRAM
connect_constant ${dac_bram_name}_dinb 0 32 blk_mem_gen_$dac_bram_name/dinb
connect_constant ${dac_bram_name}_enb  1 1  blk_mem_gen_$dac_bram_name/enb
connect_constant ${dac_bram_name}_web  0 4  blk_mem_gen_$dac_bram_name/web
connect_pins blk_mem_gen_$dac_bram_name/rstb     $rst_name/peripheral_reset

