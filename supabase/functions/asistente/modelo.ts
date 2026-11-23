// El ÚNICO archivo que conoce al proveedor de IA. Hoy, Gemini (generateContent).
//
// Para cambiar de proveedor (Claude u otro) se reescriben estas tres
// funciones —conversar, mensajeUsuario, resultadosHerramientas— y nada más:
// index.ts solo maneja el historial como algo opaco.
//
// El historial es el arreglo `contents` de Gemini y se devuelve a la app TAL
// CUAL llegó: con los modelos Gemini 3 trae `thoughtSignature`, y si al
// reenviarlo falta, la API responde MISSING_THOUGHT_SIGNATURE.

export interface Herramienta {
  nombre: string;
  descripcion: string;
  parametros: Record<string, unknown>; // JSON Schema de un objeto
}

export interface Llamada {
  id?: string;
  nombre: string;
  argumentos: Record<string, unknown>;
}

// shortcut: Gemini 3.8 Flash del plan gratuito, que usa lo enviado para
// mejorar los productos de Google. Solo datos inventados hasta pasar a pago.
const MODELO = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.8-flash";

// El plan gratuito se satura a menudo ("high demand", 503) o agota la cuota
// por minuto (429). Se reintenta una vez y luego se pasa a un modelo más
// ligero, también gratuito.
const RESPALDO = Deno.env.get("GEMINI_MODEL_RESPALDO") ?? "gemini-3.5-flash-lite";
const REINTENTABLE = new Set([429, 500, 503]);

export class ProveedorNoDisponible extends Error {}

/** Un mensaje del cliente, en el formato del historial. */
export function mensajeUsuario(texto: string): unknown {
  return { role: "user", parts: [{ text: texto }] };
}

// Las únicas partes que produce este archivo. Un historial falsificado no
// puede colar imágenes, archivos ni URLs (inlineData, fileData...).
const PARTES = new Set(["text", "thought", "thoughtSignature", "functionCall", "functionResponse"]);

/** El historial llega de la app, que puede estar manipulada: solo se acepta
 * la forma que este archivo produce. */
export function historialValido(historial: unknown[]): boolean {
  return historial.every((contenido) => {
    if (typeof contenido !== "object" || contenido === null) return false;
    const { role, parts, ...resto } = contenido as Record<string, unknown>;
    return (role === "user" || role === "model") &&
      Object.keys(resto).length === 0 &&
      Array.isArray(parts) &&
      parts.every((p) =>
        typeof p === "object" && p !== null && Object.keys(p).every((k) => PARTES.has(k))
      );
  });
}

/** Los resultados de las herramientas de un turno, en un solo mensaje. */
export function resultadosHerramientas(
  resultados: { llamada: Llamada; resultado: unknown }[],
): unknown {
  return {
    role: "user",
    parts: resultados.map(({ llamada, resultado }) => ({
      functionResponse: {
        ...(llamada.id ? { id: llamada.id } : {}),
        name: llamada.nombre,
        // Gemini exige un objeto como respuesta.
        response: { resultado },
      },
    })),
  };
}

/** Una vuelta con el modelo: devuelve el historial ampliado, el texto y las
 * herramientas que pidió usar. */
export async function conversar(opciones: {
  sistema: string;
  historial: unknown[];
  herramientas?: Herramienta[];
}): Promise<{ historial: unknown[]; texto: string; llamadas: Llamada[] }> {
  const clave = Deno.env.get("GEMINI_API_KEY");
  if (!clave) throw new ProveedorNoDisponible("Falta GEMINI_API_KEY");

  const cuerpo = JSON.stringify({
    systemInstruction: { parts: [{ text: opciones.sistema }] },
    contents: opciones.historial,
    ...(opciones.herramientas?.length
      ? {
        tools: [{
          functionDeclarations: opciones.herramientas.map((h) => ({
            name: h.nombre,
            description: h.descripcion,
            parameters: h.parametros,
          })),
        }],
      }
      : {}),
    // Agendar no exige razonar mucho, y el pensamiento alto tardaba ~50 s
    // por vuelta en el plan gratuito.
    generationConfig: {
      maxOutputTokens: 2048,
      thinkingConfig: { thinkingLevel: "low" },
    },
  });

  const pedir = (modelo: string) =>
    fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${modelo}:generateContent`,
      {
        method: "POST",
        // La clave en la cabecera, no en la URL: así no queda en los registros.
        headers: { "content-type": "application/json", "x-goog-api-key": clave },
        body: cuerpo,
      },
    );

  let respuesta = await pedir(MODELO);
  if (REINTENTABLE.has(respuesta.status)) {
    await new Promise((listo) => setTimeout(listo, 1500));
    respuesta = await pedir(MODELO);
  }
  if (REINTENTABLE.has(respuesta.status)) respuesta = await pedir(RESPALDO);

  if (!respuesta.ok) {
    // 429 = cuota gratuita agotada; 4xx/5xx = algo del proveedor.
    throw new ProveedorNoDisponible(
      `Gemini ${respuesta.status}: ${(await respuesta.text()).slice(0, 300)}`,
    );
  }

  const datos = await respuesta.json();
  const contenido = datos?.candidates?.[0]?.content;
  if (!contenido) {
    throw new ProveedorNoDisponible(
      `Gemini sin respuesta: ${JSON.stringify(datos).slice(0, 300)}`,
    );
  }

  // deno-lint-ignore no-explicit-any
  const partes: any[] = contenido.parts ?? [];
  return {
    // El contenido del modelo va al historial sin tocar (thoughtSignature).
    historial: [...opciones.historial, contenido],
    texto: partes.filter((p) => typeof p.text === "string" && !p.thought)
      .map((p) => p.text).join("").trim(),
    llamadas: partes.filter((p) => p.functionCall).map((p) => ({
      id: p.functionCall.id,
      nombre: p.functionCall.name,
      argumentos: p.functionCall.args ?? {},
    })),
  };
}
