// Lógica pura del asistente: sin red ni Deno, para probarla con `node --test`.
// Repite las reglas que la app aplica en Dart (rejilla de 45 minutos, reloj
// de Bogotá, celular colombiano). La base vuelve a validar todo al reservar.

/** Bogotá es UTC-5 fijo: no tiene horario de verano. */
const DESFASE_BOGOTA_MS = 5 * 60 * 60 * 1000;

/** La rejilla de la agenda, igual que `slotStep` en la app. */
export const PASO_MINUTOS = 45;

export interface Franja {
  abre: string; // "08:00" o "08:00:00"
  cierra: string;
}

export interface Ocupado {
  empieza: string; // instante ISO, como lo devuelve horarios_ocupados
  termina: string;
}

/** "08:30" -> 510. */
function aMinutos(hora: string): number {
  const [h, m] = hora.split(":").map(Number);
  return h * 60 + m;
}

/** 510 -> "08:30". */
export function aHora(minutos: number): string {
  const h = Math.floor(minutos / 60).toString().padStart(2, "0");
  const m = (minutos % 60).toString().padStart(2, "0");
  return `${h}:${m}`;
}

/** Un día ("2026-12-01") y una hora de Bogotá, como instante UTC. */
export function instanteBogota(fecha: string, minutos: number): Date {
  const [a, mes, d] = fecha.split("-").map(Number);
  return new Date(Date.UTC(a, mes - 1, d, 0, minutos) + DESFASE_BOGOTA_MS);
}

/** El día de hoy en Bogotá, "2026-11-23". */
export function hoyBogota(ahora: Date): string {
  return new Date(ahora.getTime() - DESFASE_BOGOTA_MS).toISOString().slice(0, 10);
}

/** Un instante ISO como fecha y hora de Bogotá: ["2026-12-01", "09:30"]. */
export function enBogota(iso: string): [string, string] {
  const pared = new Date(new Date(iso).getTime() - DESFASE_BOGOTA_MS);
  return [
    pared.toISOString().slice(0, 10),
    aHora(pared.getUTCHours() * 60 + pared.getUTCMinutes()),
  ];
}

/** "09:30" -> 570, o null si no es una hora válida. */
export function minutosDeHora(hora: string): number | null {
  const m = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(hora);
  return m ? Number(m[1]) * 60 + Number(m[2]) : null;
}

/** Hasta cuántos días adelante se agenda. La base exige lo mismo. */
export const MAX_DIAS_AGENDA = 90;

/** "2026-11-24" + 7 días -> "2026-12-01". */
export function sumarDias(fecha: string, dias: number): string {
  const [a, m, d] = fecha.split("-").map(Number);
  return new Date(Date.UTC(a, m - 1, d + dias)).toISOString().slice(0, 10);
}

const NOMBRES_DIA = ["", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"];
const NOMBRES_MES = [
  "enero",
  "febrero",
  "marzo",
  "abril",
  "mayo",
  "junio",
  "julio",
  "agosto",
  "septiembre",
  "octubre",
  "noviembre",
  "diciembre",
];

/** "2026-11-24" -> "martes 24 de noviembre". Sin año a propósito: el modelo
 * reescribía los años de las fechas ISO al redactar el resumen. */
export function fechaLegible(fecha: string): string {
  const [, m, d] = fecha.split("-").map(Number);
  return `${NOMBRES_DIA[diaSemana(fecha)]} ${d} de ${NOMBRES_MES[m - 1]}`;
}

/** Lunes = 1 ... domingo = 7, como `isodow` en Postgres. */
export function diaSemana(fecha: string): number {
  const dia = new Date(`${fecha}T12:00:00Z`).getUTCDay();
  return dia === 0 ? 7 : dia;
}

/**
 * Las horas en que puede empezar una cita de [minutos] ese día: en la
 * rejilla de cada franja, terminando antes del cierre, sin pisar ninguna
 * cita ocupada y nunca antes de [ahora].
 */
export function comienzosLibres(opciones: {
  fecha: string;
  minutos: number;
  franjas: Franja[];
  ocupados: Ocupado[];
  ahora: Date;
}): string[] {
  const { fecha, minutos, franjas, ocupados, ahora } = opciones;
  const tomados = ocupados.map((o) => [
    new Date(o.empieza).getTime(),
    new Date(o.termina).getTime(),
  ]);

  const libres: string[] = [];
  for (const franja of franjas) {
    const cierra = aMinutos(franja.cierra);
    for (
      let inicio = aMinutos(franja.abre);
      inicio + minutos <= cierra;
      inicio += PASO_MINUTOS
    ) {
      const desde = instanteBogota(fecha, inicio).getTime();
      const hasta = desde + minutos * 60 * 1000;
      if (desde < ahora.getTime()) continue;
      const pisa = tomados.some(([e, t]) => desde < t && e < hasta);
      if (!pisa) libres.push(aHora(inicio));
    }
  }
  return libres;
}

/**
 * Un celular colombiano en E.164 (+573001112233), o null. Las mismas formas
 * que acepta `normalizarTelefono` en la app; los fijos no valen.
 */
export function normalizarCelular(entrada: string): string | null {
  const digitos = entrada.replace(/[^0-9]/g, "");
  if (digitos.length === 10 && digitos.startsWith("3")) return `+57${digitos}`;
  if (digitos.length === 12 && digitos.startsWith("573")) return `+${digitos}`;
  if (digitos.length === 14 && digitos.startsWith("00573")) {
    return `+${digitos.slice(2)}`;
  }
  return null;
}

/** Un texto que escribió un cliente, listo para ir dentro de los datos de un
 * prompt: en una sola línea, sin los separadores ni las etiquetas que usan
 * los datos, y acotado. */
export function textoSeguro(texto: string, max: number): string {
  return texto.replace(/[\p{Cc}|<>]/gu, " ").replace(/\s+/g, " ").trim().slice(0, max);
}
