const fs = require("node:fs/promises")
const path = require("path")
const readline = require("readline")

const NODE_PATHS = (process.env.NODE_PATH || "").split(path.delimiter).filter(Boolean)
const PROTOCOL_PREFIX = process.env.PROTOCOL_PREFIX
const WRITE_CHUNK_SIZE = parseInt(process.env.WRITE_CHUNK_SIZE, 10)

function main() {
  process.stdin.on("end", () => process.exit())

  const readLineInterface = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false,
  })

  readLineInterface.on("line", onInput)
}

main()

async function onInput(encodedInst) {
  const buffer = Buffer.from(`${await execEncodedInst(encodedInst)}\n`)

  // The function being called might have written something to STDOUT without
  // starting a new line. This will interfere the message sent to Elixir.
  //
  // To avoid impact it might bring, we:
  //
  //   * add a newline here for creating a new message context.
  //   * write the buffer after a predefined prefix, so the port knows where the
  //     boundaries of the message body are.
  //
  process.stdout.write("\n")
  process.stdout.write(PROTOCOL_PREFIX)
  for (let i = 0; i < buffer.length; i += WRITE_CHUNK_SIZE) {
    const chunk = buffer.slice(i, i + WRITE_CHUNK_SIZE)
    process.stdout.write(chunk)
  }
}

async function execEncodedInst(encodedInst) {
  try {
    const [[modName, fnNames, args], opts] = JSON.parse(encodedInst)
    const importMod = opts.esm ? importModuleRespectingNodePath : requireModule
    const mod = await importMod(modName)
    const fn = await getFn(mod, fnNames)
    if (!fn) {
      throw new Error(`Could not find function '${fnNames.join(".")}' in module '${modName}'`)
    }
    const returnValue = fn(...args)
    const result = returnValue instanceof Promise ? await returnValue : returnValue
    return JSON.stringify(["ok", result])
  } catch ({ message, stack }) {
    return JSON.stringify(["error", { message: message, stack: stack }])
  }
}

function requireModule(modulePath) {
  // When not running in production mode, refresh the cache on each call.
  if (process.env.NODE_ENV !== "production") {
    delete require.cache[require.resolve(modulePath)]
  }

  return require(modulePath)
}

async function importModuleRespectingNodePath(modulePath) {
  // to be compatible with cjs require, we simulate resolution using NODE_PATH
  for (const nodePath of NODE_PATHS) {
    // Try to resolve the module in the current path
    const modulePathToTry = path.join(nodePath, modulePath)
    if (fileExists(modulePathToTry)) {
      // imports are cached. To bust that cache, add unique query string to module name
      // eg NodeJS.call({"esm-module.mjs?q=#{System.unique_integer()}", :fn})
      // it will leak memory, so I'm not doing it by default!
      // see more: https://ar.al/2021/02/22/cache-busting-in-node.js-dynamic-esm-imports/#cache-invalidation-in-esm-with-dynamic-imports
      return await import(modulePathToTry)
    }
  }

  throw new Error(
    `Could not find module '${modulePath}'. Hint: File extensions are required in ESM. Tried ${NODE_PATHS.join(", ")}`,
  )
}

function getFn(parent, [name, ...names]) {
  if (name === undefined) {
    return parent
  }
  return getFn(parent[name], names)
}

async function fileExists(file) {
  return await fs
    .access(file, fs.constants.R_OK)
    .then(() => true)
    .catch(() => false)
}
