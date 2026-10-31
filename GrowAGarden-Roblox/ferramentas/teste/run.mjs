// Executa o jogo dentro do simulador: carrega API, mock, scripts do jogo e o cenario de teste.
import { LuauState } from 'luau-web'
import fs from 'fs'
import path from 'path'

const SRC = process.argv[2]
const SCENARIO = process.argv[3] || 'scenario.luau'
const here = path.dirname(new URL(import.meta.url).pathname)

const files = {
  'Shared/Config': 'ReplicatedStorage/Shared/Config.luau',
  'Shared/Formulas': 'ReplicatedStorage/Shared/Formulas.luau',
  'Server/init': 'ServerScriptService/GardenServer/init.server.luau',
  'Client/init': 'StarterPlayerScripts/GardenClient/init.client.luau',
}
for (const f of fs.readdirSync(path.join(SRC, 'ServerScriptService/GardenServer')))
  if (f.endsWith('.luau') && !f.startsWith('init')) files['Server/' + f.replace('.luau', '')] = 'ServerScriptService/GardenServer/' + f
for (const f of fs.readdirSync(path.join(SRC, 'StarterPlayerScripts/GardenClient')))
  if (f.endsWith('.luau') && !f.startsWith('init')) files['Client/' + f.replace('.luau', '')] = 'StarterPlayerScripts/GardenClient/' + f

const s = await LuauState.createAsync({})
const run = async (code, name) => {
  const fn = s.loadstring(code, name, false)
  if (typeof fn === 'string') { console.log('ERRO DE COMPILACAO', fn); process.exit(1) }
  await fn()
}
await run(fs.readFileSync(path.join(here, 'api_data.luau'), 'utf8'), 'api_data')
await run(fs.readFileSync(path.join(here, 'mock.luau'), 'utf8'), 'mock')
let wrapped = 'local m = {}\n'
for (const [key, rel] of Object.entries(files)) {
  let src = fs.readFileSync(path.join(SRC, rel), 'utf8')
  src = src.replace(/(?<![\w_])typeof\(/g, '__typeof(')
  await run(`__MODULES = __MODULES or {}; __MODULES[${JSON.stringify(key)}] = function(script) ${src}\nend`, rel)
}
if (process.env.DUMP) await run('__DUMP = true', 'dump')
await run(fs.readFileSync(path.join(here, SCENARIO), 'utf8'), SCENARIO)
