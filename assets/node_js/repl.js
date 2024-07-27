import fsSync from "node:fs"
import fs from "node:fs/promises"
import path from "node:path"
import readline from "node:readline"
import ETF from "./etf"

const fdIn = fsSync.createReadStream(null, { fd: 3 })
const fdOut = fsSync.createWriteStream(null, { fd: 4 })

function main() {
  fdIn.on("end", () => process.exit())
  fdIn.on("readable", read)
}

main()

async function read() {
  let packetBody

  while ((packetBody = readPacket()) !== null) {
    const encodedInst = packetBody
    const buffer = await execCall(encodedInst)
    writePacket(buffer)
  }
}

function readPacket() {
  const packetHeader = fdIn.read(4)
  if (!packetHeader) return null

  const packetBodySize = packetHeader.readUInt32BE(0)
  return fdIn.read(packetBodySize)
}

function writePacket(buffer) {
  const packetBody = buffer
  const packetBodySize = packetBody.length

  const packetHeader = Buffer.alloc(4)
  packetHeader.writeUInt32BE(packetBodySize, 0)

  fdOut.write(packetHeader)
  fdOut.write(packetBody)
}

async function execCall(encodedInst) {
  try {
    const [[modName, fnNames, args], opts] = ETF.unpack(encodedInst)

    const importMod = opts.esm ? importModuleRespectingNodePath : requireModule
    const mod = await importMod(modName)
    const fn = await getFn(mod, fnNames)
    if (!fn) {
      throw new Error(`Could not find function '${fnNames.join(".")}' in module '${modName}'`)
    }
    const returnValue = fn(...args)
    const result = returnValue instanceof Promise ? await returnValue : returnValue

    return ETF.pack(["ok", result])
  } catch ({ message, stack }) {
    return ETF.pack(["error", { message: message, stack: stack }])
  }
}

function requireModule(modulePath) {
  // When not running in production mode, refresh the cache on each call.
  if (process.env.NODE_ENV !== "production") {
    delete require.cache[require.resolve(modulePath)]
  }

  return require(modulePath)
}

const MODULE_SEARCH_PATHS = (process.env.NODE_PATH || "").split(path.delimiter).filter(Boolean)
async function importModuleRespectingNodePath(modulePath) {
  // to be compatible with cjs require, we simulate resolution using NODE_PATH
  for (const searchPath of MODULE_SEARCH_PATHS) {
    // Try to resolve the module in the current path
    const modulePathToTry = path.join(searchPath, modulePath)
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
