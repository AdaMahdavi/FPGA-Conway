#*****************************************************************************************
# Vivado (TM) v2024.2 (64-bit)
#
# build.tcl: Tcl script for re-creating project 'conway_gol'
#
# Usage:
#   vivado -mode batch -source scripts/build.tcl
#   or from Vivado Tcl console: source scripts/build.tcl
#
#*****************************************************************************************

# Set the reference directory to the repo root (one level up from scripts/)
set origin_dir [file normalize [file dirname [info script]]/..]

# Use origin directory path location variable, if specified in the tcl shell
if { [info exists ::origin_dir_loc] } {
  set origin_dir $::origin_dir_loc
}

# Set the project name
set _xil_proj_name_ "conway_gol"

if { [info exists ::user_project_name] } {
  set _xil_proj_name_ $::user_project_name
}

variable script_file
set script_file "build.tcl"

proc print_help {} {
  variable script_file
  puts "\nDescription:"
  puts "Recreate the FPGA-Conway Vivado project from this script.\n"
  puts "Syntax:"
  puts "$script_file"
  puts "$script_file -tclargs \[--origin_dir <path>\]"
  puts "$script_file -tclargs \[--project_name <name>\]"
  puts "$script_file -tclargs \[--help\]\n"
  exit 0
}

if { $::argc > 0 } {
  for {set i 0} {$i < $::argc} {incr i} {
    set option [string trim [lindex $::argv $i]]
    switch -regexp -- $option {
      "--origin_dir"   { incr i; set origin_dir [lindex $::argv $i] }
      "--project_name" { incr i; set _xil_proj_name_ [lindex $::argv $i] }
      "--help"         { print_help }
      default {
        if { [regexp {^-} $option] } {
          puts "ERROR: Unknown option '$option' specified, please type '$script_file -tclargs --help' for usage info.\n"
          return 1
        }
      }
    }
  }
}

# Create project
create_project ${_xil_proj_name_} ./${_xil_proj_name_} -part xc7a35tcpg236-3

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Set project properties
set obj [current_project]
set_property -name "default_lib"                    -value "xil_defaultlib"  -objects $obj
set_property -name "enable_vhdl_2008"               -value "1"               -objects $obj
set_property -name "ip_cache_permissions"           -value "read write"      -objects $obj
set_property -name "mem.enable_memory_map_generation" -value "1"             -objects $obj
set_property -name "part"                           -value "xc7a35tcpg236-3" -objects $obj
set_property -name "revised_directory_structure"    -value "1"               -objects $obj
set_property -name "sim.ip.auto_export_scripts"     -value "1"               -objects $obj
set_property -name "simulator_language"             -value "Mixed"           -objects $obj
set_property -name "source_mgmt_mode"               -value "DisplayOnly"     -objects $obj
set_property -name "xpm_libraries"                  -value "XPM_CDC XPM_MEMORY" -objects $obj

# -------------------------------------------------------------------------
# Create 'sources_1' fileset
# -------------------------------------------------------------------------
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

set obj [get_filesets sources_1]

# --- VGA Controller sources ---
set files [list \
  [file normalize "$origin_dir/srcs/VGA_controller/control_VGA.v"]        \
  [file normalize "$origin_dir/srcs/VGA_controller/horizontal_counter.v"] \
  [file normalize "$origin_dir/srcs/VGA_controller/hsync_generator.v"]    \
  [file normalize "$origin_dir/srcs/VGA_controller/vertical_counter.v"]   \
  [file normalize "$origin_dir/srcs/VGA_controller/vsync_generator.v"]    \
  [file normalize "$origin_dir/srcs/VGA_controller/xypixel_generator.v"]  \
]
add_files -norecurse -fileset $obj $files

# --- Conway Game of Life sources ---
set files [list \
  [file normalize "$origin_dir/srcs/Conway_gol/conway_logic.sv"]       \
  [file normalize "$origin_dir/srcs/Conway_gol/conway_top_wrapper.sv"] \
  [file normalize "$origin_dir/srcs/Conway_gol/conway_vga.sv"]         \
  [file normalize "$origin_dir/srcs/Conway_gol/copy_bram.sv"]          \
  [file normalize "$origin_dir/srcs/Conway_gol/dualp_bram.sv"]         \
]
add_files -norecurse -fileset $obj $files

# --- Pattern / COE init files ---
set files [list \
  [file normalize "$origin_dir/patterns/3_engine_gun_1024x512.coe"]             \
  [file normalize "$origin_dir/patterns/anector_spaceship_1024x512.coe"]        \
  [file normalize "$origin_dir/patterns/elbow_ladder.coe"]                      \
  [file normalize "$origin_dir/patterns/gilder_loop_1024x512.coe"]              \
  [file normalize "$origin_dir/patterns/gosper_gun.coe"]                        \
  [file normalize "$origin_dir/patterns/herschel_climber_1024x512.coe"]         \
  [file normalize "$origin_dir/patterns/herschel_p61_1024x512.coe"]             \
  [file normalize "$origin_dir/patterns/high_period_1024x512.coe"]              \
  [file normalize "$origin_dir/patterns/interview_demo.coe"]                    \
  [file normalize "$origin_dir/patterns/noisy_map_1024x512.coe"]                \
  [file normalize "$origin_dir/patterns/oscillators_7n8_1024x512.coe"]          \
  [file normalize "$origin_dir/patterns/pentadecathlon_grid.coe"]               \
  [file normalize "$origin_dir/patterns/pufferfish_breeder.coe"]                \
  [file normalize "$origin_dir/patterns/puffer_engine_1024x512.coe"]            \
  [file normalize "$origin_dir/patterns/pushalong_1024x512.coe"]                \
  [file normalize "$origin_dir/patterns/queen_bee_turn.coe"]                    \
  [file normalize "$origin_dir/patterns/reactions_1024x512.coe"]                \
]
add_files -norecurse -fileset $obj $files

# --- Set file types ---
set sv_files [list \
  "conway_logic.sv" "conway_top_wrapper.sv" "conway_vga.sv" "copy_bram.sv" "dualp_bram.sv" \
]
foreach f $sv_files {
  set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$f"]]
  set_property -name "file_type" -value "SystemVerilog" -objects $file_obj
}



# --- Add IP cores ---
set clk_xci [file normalize "$origin_dir/srcs/IP/clk_wiz_0/clk_wiz_0.xci"]
set bram_xci [file normalize "$origin_dir/srcs/IP/blk_mem_gen_0/blk_mem_gen_0.xci"]

puts "INFO: Adding IP $clk_xci"
puts "INFO: Adding IP $bram_xci"

add_files -fileset sources_1 [list $clk_xci $bram_xci]

puts "INFO: Files after add_files:"
puts [get_files *.xci]

upgrade_ip [get_ips *]
generate_target all [get_ips *]
export_ip_user_files -of_objects [get_ips *] -no_script -sync -force



# --- Set top module ---
set obj [get_filesets sources_1]
set_property -name "top_auto_set" -value "0"                  -objects $obj
set_property -name "top"          -value "conway_top_wrapper" -objects $obj

# -------------------------------------------------------------------------
# Create 'constrs_1' fileset
# -------------------------------------------------------------------------
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

set obj [get_filesets constrs_1]
set xdc_file [file normalize "$origin_dir/constrs/const.xdc"]
add_files -norecurse -fileset $obj [list $xdc_file]
set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*const.xdc"]]
set_property -name "file_type" -value "XDC" -objects $file_obj

set obj [get_filesets constrs_1]
set_property -name "target_constrs_file" -value $xdc_file -objects $obj
set_property -name "target_part"         -value "xc7a35tcpg236-3" -objects $obj

# -------------------------------------------------------------------------
# Create 'sim_1' fileset
# -------------------------------------------------------------------------
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}

set obj [get_filesets sim_1]
set files [list \
  [file normalize "$origin_dir/sim/bram_vga_tb.v"]      \
  [file normalize "$origin_dir/sim/control_conway_tb.sv"] \
  [file normalize "$origin_dir/sim/dp_bram_tb.v"]     \
  [file normalize "$origin_dir/sim/top_conway_tb.v"]  \
  [file normalize "$origin_dir/sim/vga_tb.v"]         \
]
add_files -norecurse -fileset $obj $files

set file_obj [get_files -of_objects [get_filesets sim_1] [list "*control_conway_tb.sv"]]
set_property -name "file_type" -value "SystemVerilog" -objects $file_obj

set obj [get_filesets sources_1]
set_property -name "top_auto_set" -value "0"                  -objects $obj
set_property -name "top"          -value "conway_top_wrapper" -objects $obj
set_property -name "top_lib"      -value "xil_defaultlib"     -objects $obj

# -------------------------------------------------------------------------
# Synthesis run
# -------------------------------------------------------------------------
if {[string equal [get_runs -quiet synth_1] ""]} {
  create_run -name synth_1 -part xc7a35tcpg236-3 \
    -flow {Vivado Synthesis 2024} \
    -strategy "Vivado Synthesis Defaults" \
    -report_strategy {No Reports} \
    -constrset constrs_1
} else {
  set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
  set_property flow     "Vivado Synthesis 2024"     [get_runs synth_1]
}
set obj [get_runs synth_1]
set_property -name "part"     -value "xc7a35tcpg236-3"          -objects $obj
set_property -name "strategy" -value "Vivado Synthesis Defaults" -objects $obj

current_run -synthesis [get_runs synth_1]

# -------------------------------------------------------------------------
# Implementation run
# -------------------------------------------------------------------------
if {[string equal [get_runs -quiet impl_1] ""]} {
  create_run -name impl_1 -part xc7a35tcpg236-3 \
    -flow {Vivado Implementation 2024} \
    -strategy "Vivado Implementation Defaults" \
    -report_strategy {No Reports} \
    -constrset constrs_1 \
    -parent_run synth_1
} else {
  set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]
  set_property flow     "Vivado Implementation 2024"     [get_runs impl_1]
}
set obj [get_runs impl_1]
set_property -name "part"     -value "xc7a35tcpg236-3"               -objects $obj
set_property -name "strategy" -value "Vivado Implementation Defaults" -objects $obj
set_property -name "steps.write_bitstream.args.readback_file" -value "0" -objects $obj
set_property -name "steps.write_bitstream.args.verbose"       -value "0" -objects $obj

current_run -implementation [get_runs impl_1]

puts "INFO: Project created: ${_xil_proj_name_}"
puts "INFO: To build, run synthesis and implementation from the Vivado GUI or:"
puts "INFO:   launch_runs synth_1 -jobs 4"
puts "INFO:   wait_on_run synth_1"
puts "INFO:   launch_runs impl_1 -to_step write_bitstream -jobs 4"
puts "INFO:   wait_on_run impl_1"
