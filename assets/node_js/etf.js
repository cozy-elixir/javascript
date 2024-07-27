import Wetf from "wetf"

const etfPacker = new Wetf.Packer({
  encoding: {
    // JavaScript string -> Elixir binary
    string: "binary",
    // JavaScript map key -> Elixir binary
    key: "binary",
    // JavaScript array -> Elixir list
    array: "list",
  },
})
const etfUnpacker = new Wetf.Unpacker({
  decoding: {
    // Elixir charlist -> JavaScript array
    string: "array",
    // Elixir binary -> JavaScript string
    binary: "utf8",
    // Elixir empty list -> JavaScript array
    // note: The nil at here means the representation for an empty list.
    nil: "array",
  },
})

// pack data structure into a ETF buffer
function pack(data) {
  const uint8array = etfPacker.pack(data)
  return Buffer.from(uint8array)
}

// unpack data structure from a ETF buffer
function unpack(buffer) {
  const uint8array = Uint8Array.from(buffer)
  return etfUnpacker.unpack(uint8array)
}

export default {
  pack,
  unpack,
}
