# Lustre universal component demo

In Lustre, applications are built around the MVU architecture with a model
representing program state, a view function to render that state, and an update
function to handle events and update that state.

These three building blocks are encapsulated by the `App` type. Lustre's secret
weapon is that the same app can be run multiple ways without changing the core app
code.

This project showcases how that works. The `common/` directory contains a Lustre
application for a simple counter example. **All** the Lustre application logic
lives here, and is agnostic to the platform it runs on. This counter application
is exported as a custom element using Lustre's dev tools and saved as
`server/priv/static/counter.mjs` by running:
```
gleam clean && gleam run -m lustre/dev build component common/counter --outdir=../server/priv/static
```

The `client/` directory takes that counter application and runs it as a typical
client-side web application. The code in this directory is only responsible for
the boilerplate necessary to run the app in the browser.

The `server/` directory takes that same counter application and runs it as a
server component. The code in this directory is only responsible for setting up
the server and acting as a bridge between the server component's client runtime
and the BEAM actor running the counter app.
