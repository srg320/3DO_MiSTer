derive_pll_clocks
derive_clock_uncertainty

set_multicycle_path -to {*Hq2x*} -setup 4
set_multicycle_path -to {*Hq2x*} -hold 3

set_false_path -to [get_registers {emu:emu|P3DO:p3do|MADAM:madam|MATH_M[*]}]
