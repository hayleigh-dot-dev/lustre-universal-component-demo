// IMPORTS ---------------------------------------------------------------------

import common/counter
import lustre

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let selector = "#app"
  let assert Ok(_) = lustre.start(counter.app(), selector, Nil)

  Nil
}
