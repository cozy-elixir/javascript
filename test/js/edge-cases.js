const { v4: uuid } = require("uuid")

function writeToStdout(x) {
  console.log("calling console.log")
  process.stdout.write("calling process.stdout.write")
  return x
}

function throwError() {
  throw new TypeError("oops")
}

module.exports = {
  uuid,
  writeToStdout,
  throwError,
}
