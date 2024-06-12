import common/counter
import gleam/bytes_builder
import gleam/erlang
import gleam/erlang/process.{type Selector, type Subject}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import lustre
import lustre/attribute
import lustre/element.{element}
import lustre/element/html.{html}
import lustre/server_component
import lustre/ui
import lustre/ui/util/cn
import mist.{
  type Connection, type ResponseData, type WebsocketConnection,
  type WebsocketMessage,
}

pub fn main() {
  let assert Ok(_) =
    fn(req: Request(Connection)) -> Response(ResponseData) {
      case request.path_segments(req) {
        // Set up the websocket connection to the client. This is how we send
        // DOM updates to the browser and receive events from the client.
        ["counter"] ->
          mist.websocket(
            request: req,
            on_init: socket_init,
            on_close: socket_close,
            handler: socket_update,
          )

        ["lustre-server-component.mjs"] -> {
          let assert Ok(priv) = erlang.priv_directory("lustre")
          let path = priv <> "/static/lustre-server-component.mjs"
          let assert Ok(script) = mist.send_file(path, offset: 0, limit: None)

          response.new(200)
          |> response.prepend_header("content-type", "application/javascript")
          |> response.set_body(script)
        }

        ["lustre-ui.css"] -> {
          let assert Ok(priv) = erlang.priv_directory("lustre_ui")
          let path = priv <> "/static/lustre-ui.css"
          let assert Ok(css) = mist.send_file(path, offset: 0, limit: None)

          response.new(200)
          |> response.prepend_header("content-type", "text/css")
          |> response.set_body(css)
        }

        ["app.mjs"] -> {
          let assert Ok(priv) = erlang.priv_directory("app")
          let path = priv <> "/static/app.mjs"
          let assert Ok(script) = mist.send_file(path, offset: 0, limit: None)

          response.new(200)
          |> response.prepend_header("content-type", "application/javascript")
          |> response.set_body(script)
        }

        ["counter.mjs"] -> {
          let assert Ok(priv) = erlang.priv_directory("app")
          let path = priv <> "/static/counter.mjs"
          let assert Ok(script) = mist.send_file(path, offset: 0, limit: None)

          response.new(200)
          |> response.prepend_header("content-type", "application/javascript")
          |> response.set_body(script)
        }

        // For all other requests we'll just serve some HTML that renders the
        // server component.
        _ ->
          response.new(200)
          |> response.prepend_header("content-type", "text/html")
          |> response.set_body(
            html([], [
              html.head([], [
                html.link([
                  attribute.rel("stylesheet"),
                  attribute.href("/lustre-ui.css"),
                ]),
                html.script(
                  [attribute.type_("module"), attribute.src("/app.mjs")],
                  "",
                ),
                html.script(
                  [attribute.type_("module"), attribute.src("/counter.mjs")],
                  "",
                ),
                html.script(
                  [
                    attribute.type_("module"),
                    attribute.src("/lustre-server-component.mjs"),
                  ],
                  "",
                ),
              ]),
              html.body([], [
                ui.stack(
                  [attribute.style([#("width", "60ch"), #("margin", "auto")])],
                  [
                    html.h1([cn.text_2xl()], [html.text("Universal components")]),
                    html.p([], [
                      html.text("In Lustre, applications are built around the "),
                      html.text("MVU architecture with a model representing "),
                      html.text("program state, a view function to render "),
                      html.text("that state, and an update function to handle "),
                      html.text("events and update that state."),
                    ]),
                    html.p([], [
                      html.text("These three building blocks are encapsulated "),
                      html.text("by the `App` type. Lustre's secret weapon is "),
                      html.text("that the same app can be run multiple ways "),
                      html.text("without changing the core app code."),
                    ]),
                    html.p([], [
                      html.text("Below, we have a counter app rendered three "),
                      html.text("different ways. Once as a traditional client "),
                      html.text("side app - suitable as a SPA. Then that "),
                      html.text("counter has been bundled as a Custom Element "),
                      html.text("and rendered as a <counter-component>. And "),
                      html.text("finally as a server component. Here all of "),
                      html.text("component's logic and rendering happens on "),
                      html.text("the server and a tiny (<6kb!) runtime "),
                      html.text("patches the DOM in the browser."),
                    ]),
                    html.p([], [
                      html.text("For the two component versions of the app, "),
                      html.text("try opening your browser's dev tools and "),
                      html.text("setting the `count` attribute for each "),
                      html.text("component. You can also attach event "),
                      html.text("listeners and listen for 'incr' and 'decr' "),
                      html.text("events."),
                    ]),
                  ],
                ),
                ui.box([cn.mt_lg()], [
                  ui.sequence([], [
                    ui.stack([], [
                      html.h2([], [html.text("SPA:")]),
                      html.div([attribute.id("app")], []),
                    ]),
                    ui.stack([], [
                      html.h2([], [html.text("Custom Element:")]),
                      element("counter-component", [], []),
                    ]),
                    ui.stack([], [
                      html.h2([], [html.text("Server Component:")]),
                      server_component.component([
                        server_component.route("/counter"),
                      ]),
                    ]),
                  ]),
                ]),
              ]),
            ])
            |> element.to_document_string_builder
            |> bytes_builder.from_string_builder
            |> mist.Bytes,
          )
      }
    }
    |> mist.new
    |> mist.port(3000)
    |> mist.start_http

  process.sleep_forever()
}

//

type Counter =
  Subject(lustre.Action(counter.Msg, lustre.ServerComponent))

fn socket_init(
  _conn: WebsocketConnection,
) -> #(Counter, Option(Selector(lustre.Patch(counter.Msg)))) {
  let self = process.new_subject()
  let selector = process.selecting(process.new_selector(), self, fn(a) { a })
  let assert Ok(counter) = lustre.start_actor(counter.app(), Nil)

  process.send(counter, server_component.subscribe("ws", process.send(self, _)))
  #(counter, Some(selector))
}

fn socket_update(
  counter: Counter,
  conn: WebsocketConnection,
  msg: WebsocketMessage(lustre.Patch(counter.Msg)),
) {
  case msg {
    mist.Text(json) -> {
      // we attempt to decode the incoming text as an action to send to our
      // server component runtime.
      let action = json.decode(json, server_component.decode_action)

      case action {
        Ok(action) -> process.send(counter, action)
        Error(_) -> Nil
      }

      actor.continue(counter)
    }

    mist.Binary(_) -> actor.continue(counter)
    mist.Custom(patch) -> {
      let assert Ok(_) =
        patch
        |> server_component.encode_patch
        |> json.to_string
        |> mist.send_text_frame(conn, _)

      actor.continue(counter)
    }
    mist.Closed | mist.Shutdown -> actor.Stop(process.Normal)
  }
}

fn socket_close(counter: Counter) {
  process.send(counter, lustre.shutdown())
}
