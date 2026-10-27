# Backend en Supabase

Esquema, políticas y funciones de Perro Look. Nada de esto está conectado
todavía a la app Flutter: son las piezas de base de datos, listas para
aplicar.

```
migrations/20261027120000_esquema.sql     tablas y restricciones
migrations/20261027120100_rls.sql         quién puede ver y escribir qué
migrations/20261027120200_funciones.sql   las tres llamadas de la app
seed.sql                                  catálogo y horario de atención
```

> **Este SQL no se ha ejecutado nunca.** En la máquina donde se escribió no
> hay `psql`, ni Docker, ni la CLI de Supabase, así que está revisado pero no
> probado. Aplícalo primero en un proyecto de prueba, no en el bueno.

## Cómo aplicarlo

**Sin instalar nada**, que es lo que aplica aquí: entra al panel de
Supabase → *SQL Editor*, y pega los cuatro archivos **en el orden de
arriba**, uno por uno. Si alguno falla, el mensaje de Postgres dice la línea.

**Con la CLI** (necesita Docker, hoy no instalado):

```
supabase link --project-ref <tu-ref>
supabase db push
```

## Las tres llamadas que hace la app

| Función | Quién | Para qué |
|---|---|---|
| `horarios_ocupados(desde, hasta)` | cualquiera | pintar el paso 2 |
| `reservar_cita(mascota, empieza, servicios[])` | con sesión | crear la cita |
| `mi_fidelidad()` | con sesión | la tarjeta de visitas |

`horarios_ocupados` devuelve **solo dos columnas de tiempo**. Es la pieza
que permite enseñar que el miércoles a las 10:00 no hay sitio sin revelar de
quién es la cita.

`reservar_cita` calcula precio y duración leyendo la tabla `servicios`:
nunca se fía del total que mande el teléfono.

## Configurar OTP por teléfono

En el panel: *Authentication → Sign In / Providers → Phone*.

**Hace falta un proveedor de SMS.** Supabase no manda mensajes por su
cuenta; se conecta a Twilio, Twilio Verify, MessageBird, Vonage o TextLocal,
y pagas por mensaje a ese proveedor. Para Colombia, mirar **Twilio Verify
con canal de WhatsApp**: el público de la estética ya reserva por WhatsApp
—el póster pone el 315 214 1355— y sale más barato que el SMS.

Tres cosas que conviene dejar puestas desde el principio:

1. **Números de prueba.** En *Phone → Test OTP* se registran pares de número
   y código fijo. Con eso se desarrolla y se corren pruebas **sin gastar un
   solo mensaje**. Sin esto, cada recarga de la app cuesta dinero.
2. **Formato E.164.** Los números van como `+573152141355`, con prefijo de
   país y sin espacios. La app tendrá que normalizar lo que escriba el
   cliente.
3. **Límites de envío.** Supabase limita los OTP por hora y por número.
   Están para evitar que alguien te vacíe el saldo de Twilio mandando
   códigos; no los subas sin pensarlo.

### Cuándo pedir la cuenta

El catálogo y el horario son públicos a propósito (ver las políticas en
`rls.sql`). Con OTP cada registro cuesta un mensaje, así que **la sesión se
pide al confirmar la reserva, no al abrir la app**: mirar servicios y
horarios libres no debería costarte un SMS por curioso.

## Decisiones que conviene entender antes de tocar nada

**Las citas no se insertan directamente.** No hay política de `insert` sobre
`citas`; todo pasa por `reservar_cita`. Así las validaciones —la mascota es
tuya, hay exactamente un servicio principal, la cita cabe en el horario, el
día no está cerrado— no se pueden rodear.

**El solapamiento lo impide Postgres, no la app.** La restricción
`sin_solapes` usa un índice GiST sobre el rango de la cita. La comprobación
que hace Dart es para que la pantalla se vea bien; la que cuenta es esta,
porque dos clientes con la pantalla abierta ven el mismo hueco libre.

**Las visitas no se guardan, se cuentan.** `mi_fidelidad()` cuenta las citas
cumplidas en vez de leer un contador. Un contador se desincroniza con cada
cancelación o corrección manual.

**Los precios se congelan al reservar.** `citas.total_cop` y
`cita_servicios.precio_cop` guardan lo que costaba ese día. Cambiar el
catálogo no reescribe el historial.

**Un día sin filas en `horario_atencion` es un día cerrado.** Por eso el
seed solo inserta de lunes a viernes. Es la misma convención que en Dart,
donde un `DaySchedule` sin franjas está cerrado.

## Lo que falta

- **Canjear un referido.** La tabla `referidos` existe pero no tiene
  política de `insert`: hace falta una función que valide el código, igual
  que `reservar_cita`.
- **El panel de la estilista.** Marcar citas como cumplidas o no asistidas,
  y cerrar días. Hoy eso solo se puede hacer desde el panel de Supabase.
- **Recordatorio de la tarde anterior**, que el póster promete. Sería una
  función programada (pg_cron) más un envío por WhatsApp.
