# Backend en Supabase

Esquema, políticas y funciones de Perro Look. Nada de esto está conectado
todavía a la app Flutter: son las piezas de base de datos, listas para
aplicar.

```
migrations/20261027120000_esquema.sql     tablas y restricciones
migrations/20261027120100_rls.sql         quién puede ver y escribir qué
migrations/20261027120200_funciones.sql   las tres llamadas de la app
migrations/20261103130000_rol_admin.sql   tabla `admins` y `es_admin()`
migrations/20261116120000_panel_admin.sql observaciones y citas del panel
migrations/20261123120000_gestion_clientes.sql  clientes, mascotas y notas internas
migrations/20261123130000_cerrar_crear_cita_para.sql  cierra la función interna de reserva
migrations/20261124120000_clientes_por_celular.sql    clientes sin cuenta y reserva por celular
migrations/20261125120000_clientes_nuevos_por_mes.sql clientes nuevos de un mes dado (Resumen por mes)
migrations/20261126120000_eliminar_cliente.sql       eliminar (anonimizar) un cliente desde el panel
migrations/20261127120000_foto_mascota.sql           foto de la mascota: columna, bucket y políticas
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
Supabase → *SQL Editor*, y pega las migraciones **en el orden de
arriba**, una por una, y después `seed.sql`. Si alguno falla, el mensaje de Postgres dice la línea.

Si algo falla, pega `reset.sql` y vuelve a empezar por el primero. Es
seguro correrlo sobre un proyecto vacío o a medio crear.

**Con la CLI** (necesita Docker, hoy no instalado):

```
supabase link --project-ref <tu-ref>
supabase db push
```

## Las funciones que hace la app

| Función | Quién | Para qué |
|---|---|---|
| `horarios_ocupados(desde, hasta)` | cualquiera | pintar el paso 2 |
| `reservar_cita_por_celular(nombre, celular, mascota, empieza, servicios[])` | cualquiera | la reserva de la app (paso 3) y el "Cliente nuevo" del panel |
| `reservar_cita(mascota, empieza, servicios[])` | con sesión | reserva de una cuenta; la app ya no la usa |
| `reservar_cita_admin(cliente, mascota, empieza, servicios[])` | administradora | crear una cita para un cliente |
| `editar_cita_admin(cita, empieza, mascota, servicios[], estado, notas)` | administradora | corregir una cita |
| `directorio_clientes()` | administradora | la pestaña Clientes |
| `clientes_nuevos_mes()` | administradora | el contador del resumen, mes en curso |
| `clientes_nuevos_en(mes)` | administradora | el contador de un mes pasado en el resumen |
| `eliminar_cliente_admin(cliente)` | administradora | "Eliminar cliente" en el detalle |
| `mi_fidelidad()` | con sesión | la tarjeta de visitas |

`horarios_ocupados` devuelve **solo dos columnas de tiempo**. Es la pieza
que permite enseñar que el miércoles a las 10:00 no hay sitio sin revelar de
quién es la cita.

`reservar_cita` y `reservar_cita_admin` comparten la validación de
`crear_cita_para` y calculan precio y duración leyendo la tabla `servicios`:
nunca se fían del total que mande el teléfono.

`crear_cita_para` es interna y **nadie la puede llamar directamente**. Ojo
con esto en Supabase: cada función nueva de `public` recibe `execute` para
`anon` y `authenticated` por separado, y un `revoke ... from public` no se
lo quita. Por eso `20261123130000_cerrar_crear_cita_para.sql` lo revoca de
forma explícita. Sin ese paso, cualquiera podía reservar a nombre de otro
cliente saltándose `es_admin()`. Las reservas siguen funcionando porque
`reservar_cita` y `reservar_cita_admin` son `security definer`.

Comprobación con la anon key: `POST /rest/v1/rpc/crear_cita_para` debe
responder `permission denied for function crear_cita_para`. `editar_cita_admin` recalcula
lo mismo y reemplaza los servicios de la cita.

`clientes_nuevos_en(p_mes date)` cuenta lo mismo que `clientes_nuevos_mes`
para el mes que se le pase, cortando en hora de Bogotá. Lleva otro nombre y no
es una sobrecarga, porque PostgREST resuelve mal las sobrecargas. Tiene el
`execute` revocado a `anon`: con la anon key responde `permission denied`.

`directorio_clientes` y `clientes_nuevos_mes` corren con `security definer`
para devolver los perfiles sin abrir `admins`, que sigue sin políticas. Las
dos excluyen a las cuentas administradoras de la lista de clientes.

## Observaciones privadas

La tabla `public.observaciones` guarda notas de la estética sobre un tutor.
Tiene RLS y cuatro políticas que exigen `es_admin()`; **no hay política para
clientes**, así que un tutor no puede leerlas ni escribirlas desde la app de
reservas. El autor se guarda en `autor_id` y se fija a la cuenta que las
crea.

## Clientes por celular

Desde `20261124120000_clientes_por_celular.sql` **el cliente es su celular**,
no la sesión del equipo. El paso 3 de la reserva pide el nombre del dueño, el
celular y el nombre de la mascota, y llama a `reservar_cita_por_celular`. Esta
función:

1. valida el celular (`+573` y 9 dígitos), el nombre y la mascota. Cualquiera
   puede llamarla, así que no se fía de la app;
2. busca el perfil con ese celular, sin contar a las administradoras. Si no
   existe, crea un **cliente sin cuenta**. Si existe, **no le cambia el
   nombre**, para que nadie pueda renombrar a un cliente sabiendo su celular;
3. busca la mascota de ese cliente por nombre, sin mirar mayúsculas ni
   espacios. Si no existe, la registra;
4. crea la cita con `crear_cita_para`.

Todo ocurre en una transacción: si el horario se ocupó, no queda ni el cliente
ni la mascota.

Para que exista un cliente sin cuenta, `perfiles.id` **dejó de ser clave
foránea a `auth.users`** y tiene `default gen_random_uuid()`. El trigger que
crea el perfil de una cuenta sigue igual. Efectos que conviene conocer:

- **Borrar una cuenta ya no borra su perfil.** Queda como cliente sin cuenta,
  con su historial.
- **Celulares repetidos.** Las cuentas anónimas de antes pudieron dejar el
  mismo celular en varios perfiles. La función usa el más antiguo. Por eso
  `telefono` tiene índice, pero no es único.
- **Cambiar el celular de un cliente desde el panel.** A partir de ahí, el
  cliente tiene que reservar con el celular nuevo; con el antiguo se crearía
  otro cliente.
- **Quien sepa un celular puede reservar a nombre de esa persona.** No puede
  ver ni cambiar sus datos. Confirmar por SMS queda pendiente.

**Orden de publicación:** primero la migración y después la app con el paso 3.
Una app vieja sigue reservando con su sesión anónima. Una app nueva contra una
base vieja falla, porque la función no existe.

Comprobación con la anon key:

- `POST /rest/v1/rpc/reservar_cita_por_celular` con `p_telefono: "123"`
  responde `Escribe un celular colombiano`.
- `POST /rest/v1/rpc/crear_cita_para` sigue en `permission denied`.

Volver atrás solo es posible si no se crearon clientes sin cuenta: hay que
borrarlos o asignarlos a una cuenta antes de recrear `perfiles_id_fkey`.

## Foto de la mascota

`20261127120000_foto_mascota.sql` añade `mascotas.foto_path` y el bucket
**privado** `fotos-mascotas`, que **solo acepta `image/webp`** y como máximo
2 MB. La app reduce la foto a 1280 px por lado y la convierte a WebP antes de
subirla. Si alguien se salta la app con otro formato, Storage lo rechaza.

Las cuatro políticas sobre `storage.objects` (ver, subir, cambiar y borrar)
exigen `es_admin()`. Ni los clientes ni `anon` pueden leer las fotos. La ruta
`<mascota_id>/<marca>.webp` cambia con cada foto nueva, así que nunca se sirve
una vieja desde caché.

Supabase no deja borrar objetos de Storage con SQL, así que las fotos las
borra la app con la API de Storage:

- al cambiar la foto, borra la anterior;
- al quitarla, borra la actual;
- al eliminar un cliente, borra las de sus mascotas, después de
  `eliminar_cliente_admin`.

Si uno de esos borrados falla, queda un archivo huérfano, invisible para
todos salvo la admin, que se puede borrar a mano en *Storage*.

`reset.sql` quita las políticas, pero **no** el bucket: no se puede borrar
con objetos dentro. Para empezar de cero, vacíalo antes en *Storage →
fotos-mascotas*.

Comprobación con la anon key: subir a `fotos-mascotas` es rechazado y
listarlo no devuelve nada.

## Eliminar un cliente

"Eliminar cliente" llama a `eliminar_cliente_admin`, que **anonimiza** al
cliente: el perfil no se borra, porque sus citas lo referencian y los
ingresos de meses pasados dependen de ellas. En una transacción:

1. Rechaza a quien no sea admin, a una cuenta de `admins` y a un cliente que
   no exista o ya esté eliminado.
2. Cancela sus citas futuras reservadas, con lo que su horario queda libre.
3. Borra la nota de la estilista de todas sus citas.
4. Borra sus observaciones y sus mascotas. Sus notas internas caen en cascada
   y las citas se quedan sin mascota.
5. Vacía `nombre` y `telefono` y marca `perfiles.eliminado_en`.

Después, `directorio_clientes` ya no lo lista, y sus citas pasadas salen como
"Cliente eliminado" en Agenda, Historial y Resumen. Ingresos, % de no
asistencia, top de servicios y clientes nuevos no cambian. Si la persona
vuelve a reservar con su celular, entra como cliente nueva. **No se puede
deshacer**, y la cuenta de `auth.users` que tuviera no se toca.

Comprobación con la anon key: `POST /rest/v1/rpc/eliminar_cliente_admin`
responde `permission denied`.

## Gestión de clientes y notas internas de mascota

La migración `20261123120000_gestion_clientes.sql` deja que la estética
corrija el nombre y el teléfono de un cliente registrado, y que
registre y edite sus mascotas. Son tres políticas nuevas que exigen
`es_admin()`: `update` sobre `perfiles` y `insert`/`update` sobre `mascotas`.
**No hay `delete`** ni sobre perfiles ni sobre mascotas: una mascota borrada
dejaría sus citas pasadas sin perro. Los clientes nuevos no se crean con estas
políticas, sino con `reservar_cita_por_celular` (ver "Clientes por celular").

La nota interna de cada mascota vive en `public.notas_mascota`, una fila por
mascota con `texto`, `autor_id` y `actualizada_en`. Tiene RLS y políticas de
`select`, `insert` y `update` que exigen `es_admin()`; **no hay política para
clientes**, así que el tutor no la ve. No puede ser una columna de
`mascotas`: el tutor ve sus mascotas con todas las columnas y la RLS es por
fila, no por columna.

> **Antes de aplicarla en un proyecto con datos, respalda `mascotas`.** La
> migración copia el texto de `mascotas.notas` a `notas_mascota` y después
> **borra la columna `mascotas.notas`**. Desde el SQL Editor:
>
> ```sql
> create table public.respaldo_mascotas as select * from public.mascotas;
> ```
>
> Cuando compruebes que las notas están en `notas_mascota`, borra el respaldo
> con `drop table public.respaldo_mascotas;`.

Para comprobarla, con la sesión de una cuenta de **cliente**:

- `select * from notas_mascota` devuelve cero filas.
- un `insert` en `notas_mascota` se rechaza.
- un `update` sobre el perfil de otro cliente no cambia ninguna fila.

Y con la cuenta **administradora**, los tres pasos funcionan.

Para volver atrás, solo si todavía no hay notas nuevas que perder: recrea
`mascotas.notas`, copia `notas_mascota.texto` de vuelta, borra
`notas_mascota` y las tres políticas nuevas.

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
.
un.ps1              # Chrome en el 5000
.
un.ps1 windows      # escritorio
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

## Darle acceso de administradora a la dueña

La cuenta de la estética es `juanfe20132@gmail.com`. La contraseña se elige
al crearla en el panel y **nunca se escribe en este repo**; tampoco viaja en
el cliente.

El rol vive en la tabla `admins`, que **tiene RLS activo y ninguna política**:
desde la app no se lee ni se escribe. Se administra solo desde el panel, que
es donde debe estar la decisión de quién manda.

**1. Crear la cuenta.** En *Authentication → Users → Add user*, con correo y
contraseña.

Para la dueña, correo y contraseña es lo correcto aunque para los clientes
no lo sea: ella entra a diario desde su propio dispositivo, así que no la
olvida, y no cuesta ningún SMS.

**2. Nombrarla administradora**, en el SQL Editor:

```sql
insert into public.admins (id, anotacion)
select id, 'dueña de la estética'
from auth.users
where email = 'el-correo-que-pusiste@ejemplo.com'
on conflict (id) do nothing;

-- Comprobar
select a.id, u.email, a.anotacion
from public.admins a join auth.users u on u.id = a.id;
```

**3. Quitarle el acceso**, si hiciera falta:

```sql
delete from public.admins
where id = (select id from auth.users where email = '...');
```

Nada más. Las políticas de administración consultan `es_admin()`, así que
el acceso se enciende y se apaga con esa fila.

### Qué puede hacer, y qué no

| | Cliente | Estética |
|---|---|---|
| Catálogo y horario | ve los activos | ve y **edita** todo |
| Horas ocupadas | solo hora de inicio y fin | la cita entera |
| Citas | solo las suyas | **todas** |
| Marcar cumplida / no asistió | no | **sí** |
| Crear y corregir citas | solo las suyas al reservar | **las de cualquier cliente** |
| Observaciones privadas | no las ve | **las crea, edita y borra** |
| Perfiles y mascotas | los suyos | **ve todos, edita y registra**; elimina clientes anonimizándolos |
| Notas internas de mascota | no las ve | **las lee y las escribe** |
| Fotos de mascotas | no las ve | **las sube, cambia y borra** |
| Cerrar días | no | **sí** |

Sigue sin poder **borrar** citas: no hay política de `delete`. Una cita
equivocada se cancela, no se hace desaparecer — el historial de un negocio
no debería tener agujeros.

## Lo que falta

- **Canjear un referido.** La tabla `referidos` existe pero no tiene
  política de `insert`: hace falta una función que valide el código, igual
  que `reservar_cita`.
- **Recordatorio de la tarde anterior**, que el póster promete. Sería una
  función programada (pg_cron) más un envío por WhatsApp.
