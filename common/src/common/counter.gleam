// IMPORTS ---------------------------------------------------------------------

import decipher
import gleam/dict.{type Dict}
import gleam/dynamic.{type Decoder}
import gleam/int
import gleam/json
import gleam/result
import lustre.{type App}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import lustre/ui

//

pub const name = "counter-component"

pub fn app() -> App(Nil, Model, Msg) {
  lustre.component(init, update, view, on_attribute_change())
}

// MODEL -----------------------------------------------------------------------

pub type Model =
  Int

pub fn init(_) -> #(Model, Effect(Msg)) {
  let model = 0
  let effect = effect.none()

  #(model, effect)
}

// UPDATE ----------------------------------------------------------------------

pub type Msg {
  Incr
  Decr
  Reset(Int)
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Incr -> {
      let model = model + 1
      let effect = event.emit("incr", json.int(model))

      #(model, effect)
    }

    Decr -> {
      let model = model - 1
      let effect = event.emit("decr", json.int(model))

      #(model, effect)
    }

    Reset(count) -> #(count, effect.none())
  }
}

pub fn on_attribute_change() -> Dict(String, Decoder(Msg)) {
  dict.from_list([
    #("count", fn(attribute) {
      attribute
      |> dynamic.any([dynamic.int, decipher.int_string])
      |> result.map(Reset)
    }),
  ])
}

// VIEW ------------------------------------------------------------------------

pub fn view(model: Model) -> Element(Msg) {
  let count = int.to_string(model)

  ui.stack([], [
    ui.button([event.on_click(Incr)], [html.text("+")]),
    ui.centre([], html.span([], [html.text(count)])),
    ui.button([event.on_click(Decr)], [html.text("-")]),
  ])
}
