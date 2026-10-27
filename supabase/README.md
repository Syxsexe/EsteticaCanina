# Backend en Supabase

Esquema, políticas y funciones de Perro Look. Nada de esto está conectado
todavía a la app Flutter: son las piezas de base de datos, listas para
aplicar.

```
migrations/20261027120000_esquema.sql     tablas y restricciones
migrations/20261027120100_rls.sql         quién puede ver y escribir qué
migrations/20261027120200_funciones.sql   las tres llamadas de la app
seed.sql                                  catálogo y horario de atención
reset.sql                                 borra todo, para reintentar
```

> **Este SQL está probado solo en parte.** En la máquina donde se escribió
> no hay `psql`, ni Docker, ni la CLI de Supabase, así que se valida
> ejecutándolo en el panel. Si una migración falla a medias, corre
> `reset.sql` y reintenta desde la primera.

### Errores ya encontrados y corregidos

**`42P17: generation expression is not immutable`**, al crear `citas`.
`citas.termina` era una columna generada a partir de
`empieza + make_interval(...)`, y en Postgres `timestamptz + interval` es
STABLE, no IMMUTABLE: en cuanto el intervalo puede llevar días o meses el
resultado depende de la zona horaria de la sesión, y el operador se marca
por su peor caso aunque solo se le pasen minutos. Ahora lo calcula el
disparador `citas_calcular_fin`, que no tiene esa exigencia.

## Cómo aplicarlo

**Sin instalar nada**, que es lo que aplica aquí: entra al panel de
Supabase → *SQL Editor*, y pega los cuatro archivos **en el orden de
arriba**, uno por uno. Si alguno falla, el mensaje de Postgres dice la línea.

Si algo falla, pega `reset.sql` y vuelve a empezar por el primero. Es
seguro correrlo sobre un proyecto vacío o a medio crear.

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

## Dónde van las claves del proyecto

En `env/dev.json`, que está en `.gitignore`. La plantilla versionada es
`env/example.json`: cópiala, rellena los dos valores desde
*Settings → API* del panel y listo.

```
.un.ps1              # Chrome en el 5000
.un.ps1 windows      # escritorio
./run.sh                # lo mismo desde Git Bash
```

Los scripts existen porque **Flutter no admite argumentos por defecto a
nivel de proyecto**: no hay `.flutterrc` ni campo en `pubspec.yaml`, así que
un `flutter run -d chrome` pelado no puede saber de `env/dev.json`. Sin el
script habría que acordarse del flag en cada arranque:

```
flutter run -d chrome --dart-define-from-file=env/dev.json
```

Y olvidarlo no da un error, sino algo peor: la app arranca con la agenda de
muestra y parece funcionar. Por eso el script avisa si el archivo falta o
está vacío.

En VS Code no hace falta nada: `.vscode/launch.json` ya trae dos
configuraciones con el flag puesto.

**Sin claves la app funciona igual**, con la agenda de muestra. Eso mantiene
los tests sin red y deja clonar el repo y ejecutar la app sin pedirle
credenciales a nadie.

Pero cuidado con la simetría: **con** claves y la base caída, la app NO cae
a la agenda de muestra, sino que muestra un error con *Reintentar*. Es
deliberado. Enseñarle horarios inventados a alguien que va a reservar es
peor que no enseñarle nada: reservaría una hora que no existe.

Esa es también la razón de no clavar la URL y la key como `defaultValue` en
`AppConfig` para ahorrarse el flag. En cuanto `hasSupabase` es cierto
siempre, lo es también en los tests, donde `Supabase.instance` no está
inicializado; y el parche natural —un `try/catch` que caiga a datos de
muestra— es exactamente el comportamiento peligroso de arriba.

### Esto no es un secreto, y conviene saberlo

La **anon key está pensada para vivir dentro del cliente**. Cualquiera puede
leerla abriendo las DevTools, y en web va en claro dentro de
`main.dart.js`. Lo que protege los datos es el RLS, no que la clave esté
escondida.

Por eso tampoco se usó un `.env` con `flutter_dotenv`: en Flutter ese
archivo hay que declararlo como *asset*, o sea que **se empaqueta dentro de
la app igualmente**, y encima añade una dependencia y una carga asíncrona
que puede fallar. No es más seguro; solo lo parece.

Se saca del repo para que cada quien apunte a su propio proyecto, no para
ocultarlo.

La **`service_role` key es otra cosa**: esa se salta todas las políticas y
no debe tocar el cliente nunca. Su sitio son las Edge Functions, donde
Supabase la inyecta sola.

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
