// t1emu is in maintainance mode, don't bother to fix it
#![allow(unsafe_op_in_unsafe_fn)]

pub mod dpi;
pub mod drive;

// keep in sync with TestBench.verbatimModule
// the value is measured in simulation time unit
pub const CYCLE_PERIOD: u64 = 20000;

/// get cycle
pub fn get_t() -> u64 {
  svdpi::get_time() / CYCLE_PERIOD
}
