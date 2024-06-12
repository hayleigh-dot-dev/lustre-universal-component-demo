FROM ghcr.io/gleam-lang/gleam:v1.2.1-erlang-alpine

# Add project code
COPY ./common /build/common
COPY ./server /build/server


# Compile the project
RUN cd /build/server \
  && gleam export erlang-shipment \
  && mv build/erlang-shipment /app \
  && rm -r /build

# Run the server
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
