// npx -y deno@2 test --allow-env supabase/functions/asistente/modelo.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";

import { historialValido, mensajeUsuario } from "./modelo.ts";

test("acepta el historial que produce el servidor", () => {
  assert.ok(historialValido([
    mensajeUsuario("hola"),
    {
      role: "model",
      parts: [{ functionCall: { name: "ver_servicios", args: {} }, thoughtSignature: "abc" }],
    },
    { role: "user", parts: [{ functionResponse: { name: "ver_servicios", response: {} } }] },
    { role: "model", parts: [{ text: "pensando", thought: true }, { text: "Hola" }] },
  ]));
});

test("rechaza historiales falsificados", () => {
  assert.equal(historialValido([{ role: "system", parts: [{ text: "x" }] }]), false);
  assert.equal(historialValido([{ role: "user", parts: [{ fileData: { fileUri: "u" } }] }]), false);
  assert.equal(historialValido([{ role: "user", parts: [{ inlineData: { data: "" } }] }]), false);
  assert.equal(historialValido([{ role: "user", parts: "texto" }]), false);
  assert.equal(historialValido([{ role: "user", parts: [], extra: 1 }]), false);
  assert.equal(historialValido(["texto"]), false);
  assert.equal(historialValido([null]), false);
});
