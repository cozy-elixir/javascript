import esbuild from "esbuild"

const args = process.argv.slice(2)
const watch = args.includes("--watch")
const deploy = args.includes("--deploy")

const target = "es2021"

async function main() {
  const context = await esbuild.context({
    entryPoints: ["./node_js/repl.js"],
    outdir: "../priv/runtime/node_js",
    bundle: true,
    platform: "node",
    target: target,
    format: "cjs",
    sourcemap: true,
  })

  if (watch) {
    await [context.watch()]

    process.stdin.on("close", () => {
      process.exit(0)
    })

    process.stdin.resume()
  } else {
    await [context.rebuild()]
    process.exit(0)
  }
}

main()
