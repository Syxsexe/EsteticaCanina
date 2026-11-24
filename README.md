# Perro Look

**Perro Look** es una aplicación multiplataforma desarrollada con Flutter para la reserva de citas de una estética canina en Pasto, Colombia.

Permite a los clientes elegir servicios, consultar horarios disponibles y reservar una cita en tres pasos. También incluye un panel de administración para gestionar la agenda, clientes, mascotas, servicios, estados de las citas y resúmenes del negocio. El backend es Supabase y la interfaz está completamente en español.

> Nombre de zona horaria: la aplicación usa `America/Bogota` (`UTC-5`) porque así se define el huso horario de Colombia en IANA y en Supabase. El salón está ubicado en Pasto, no en Bogotá.

## Funcionalidades

### Para clientes

- Catálogo de servicios activos con precio y duración.
- Reserva en tres pasos:
  1. selección de servicios;
  2. selección de día y hora; 
  3. identificación por nombre, celular y mascota.
- Consulta de horarios disponibles sin exponer citas ajenas.
- Validación de celular colombiano.
- Protección contra reservas simultáneas y solapamientos.
- Chat opcional con un asistente de IA que puede consultar servicios, disponibilidad y crear reservas.
- Datos de muestra integrados para ejecutar la app sin credenciales.

### Para la administración

- Inicio de sesión con correo y contraseña.
- Agenda del día y navegación por fechas.
- Creación y edición de citas.
- Cambio de estado de las citas: reservada, cumplida o no asistió.
- Cancelación de citas sin borrarlas del historial.
- Cierre de días completos.
- Consulta de citas pasadas e próximas.
- Directorio de clientes y mascotas.
- Edición de datos de clientes y registro de mascotas.
- Notas privadas por mascota.
- Observaciones privadas por cliente.
- Fotos privadas de mascotas en almacenamiento de Supabase.
- Resumen de ingresos, servicios más solicitados, clientes nuevos y asistencia.
- Eliminación de clientes mediante anonimización, conservando el historial contable.
- Acceso protegido por la tabla `admins` y la función `es_admin()`.

## Tecnologías

- **Flutter / Dart**
- **Supabase**: PostgreSQL, Auth, Storage y Edge Functions
- **PostgreSQL**: funciones RPC, RLS y restricciones GiST
- **Deno / TypeScript**: asistente con Gemini
- Sin paquete de gestión de estado: la app usa principalmente `StatefulWidget` e inyección por constructor.
- Sin generación de código ni pipeline de CI incluido.

Dependencias principales:

- `supabase_flutter`
- `image_picker`
- `flutter_image_compress`
- `url_launcher`
- `flutter_launcher_icons`
- `flutter_native_splash`

## Requisitos

- Flutter/Dart compatibles con el SDK indicado en `pubspec.yaml` (`dart ^3.13.4`).
- Chrome, Edge o un dispositivo Android/iOS compatible para ejecutar la app.
- Un proyecto de Supabase si se desea usar datos reales.
- Windows con PowerShell o Windows/Git Bash. Los scripts incluidos simplifican el arranque.

En Windows, Device Guard puede bloquear `dart.exe` o `flutter` con el mensaje `dart.exe ha sido bloqueado`. Si ocurre, la aplicación no debe modificarse para sortearlo: hay que autorizar las herramientas en el entorno de Windows o usar un entorno con permisos adecuados.

## Inicio rápido

### 1. Obtener dependencias

```powershell
flutter pub get
```

### 2. Configurar Supabase

Copia la plantilla:

```powershell
Copy-Item env/example.json env/dev.json
```

Edita `env/dev.json` y completa los datos obtenidos desde **Supabase → Settings → API**:

```json
{
  "SUPABASE_URL": "https://TU-REF.supabase.co",
  "SUPABASE_ANON_KEY": "tu-anon-key"
}
```

La clave `anon` es pública por diseño y debe estar protegida por RLS. Nunca agregues ni empaquetes la clave `service_role` en la aplicación Flutter.

### 3. Ejecutar

Desde PowerShell:

```powershell
.\run.ps1                 # Chrome, puerto 5000
.\run.ps1 windows          # escritorio Windows
.\run.ps1 chrome 8080      # Chrome en otro puerto
```

Desde Git Bash:

```bash
./run.sh                   # Chrome, puerto 5000
./run.sh windows           # escritorio Windows
./run.sh chrome 8080       # Chrome en otro puerto
```

VS Code ya incluye configuraciones en `.vscode/launch.json`, ambas con `--dart-define-from-file=env/dev.json`.

El arranque directo con `flutter run` no pasa las variables de configuración y, por tanto, puede mostrar datos de muestra aunque exista un proyecto Supabase disponible. Usa los scripts o el archivo de lanzamiento de VS Code.

### Modo sin credenciales

Si `env/dev.json` no existe o no contiene claves reales, la app utiliza implementaciones `Sample*` con datos locales. Es el modo previsto para pruebas y ejecución visual sin backend.

Si hay claves configuradas y Supabase no puede responder, la app muestra un error y permite reintentar. No cambia silenciosamente a datos de muestra: ofrecer horarios inventados podría provocar reservas fuera de una agenda real.

## Comandos útiles

```powershell
flutter pub get
flutter analyze
flutter test
flutter test test/salon_time_test.dart
flutter test --plain-name "texto o parte del nombre"
```

Icono de lanzamiento:

```powershell
dart run flutter_launcher_icons
```

Splash nativo:

```powershell
dart run flutter_native_splash:create
```

## Arquitectura Flutter

```text
lib/
├── main.dart                 Punto de arranque
├── app.dart                  Bootstrap e inicialización
├── core/
│   ├── config/               Configuración compile-time
│   ├── navigation/           Transiciones
│   ├── theme/                Tema visual
│   └── time/                 Conversión de hora de Bogotá
└── features/
    ├── booking/              Reserva en tres pasos
    ├── admin/                Autenticación y panel administrativo
    ├── assistant/            Chat con la Edge Function
    ├── home/                 Pantalla principal
    └── splash/               Pantalla de arranque
```

`AppBootstrap` tiene un plazo máximo de cinco segundos. `main.dart` → `app.dart` → `SplashScreen` → `HomeScreen`.

Cada área de datos sigue, cuando corresponde, el patrón:

1. interfaz abstracta;
2. implementación `Sample*`;
3. implementación `Supabase*`;
4. función `default*Repository()` que elige datos locales o remotos según `AppConfig.hasSupabase`.

La aplicación no usa un paquete de gestión de estado. Las pantallas mantienen su estado con `StatefulWidget`, y los repositorios se pueden inyectar desde los constructores.

## Zona horaria y citas

Toda la frontera horaria vive en `lib/core/time/salon_time.dart`.

La app nunca usa `toLocal()` ni la zona horaria del dispositivo para calcular una cita. Debe usar las funciones previstas por el proyecto, entre ellas:

- `enHoraEstetica`;
- `desdeHoraEstetica`;
- `hoyEnLaEstetica`.

Esto fija los horarios al calendario real de la estética con `America/Bogota`, independientemente de si el usuario abre la app en Bogotá, Pasto, Estados Unidos u otro país.

## Backend Supabase

La configuración de la base de datos está en `supabase/`:

```text
supabase/
├── migrations/              Esquema y migraciones SQL numeradas
├── functions/asistente/     Edge Function del chat y resumen con IA
├── seed.sql                 Datos iniciales de servicios y horario
├── reset.sql                Reinicio completo del entorno de prueba
└── README.md                Detalle operativo del backend
```

Las migraciones se aplican desde el editor SQL de Supabase en orden lexicográfico, seguidas de `seed.sql`. Supabase CLI y Docker no son requisitos para instalar o ejecutar la aplicación.

Si una migración falla a medias, `reset.sql` permite limpiar el proyecto vacío o de prueba antes de volver a aplicar las migraciones desde el principio.

## Reservas seguras

Las citas no se insertan directamente desde Flutter.

La reserva normal utiliza la función PostgreSQL:

```text
reservar_cita_por_celular(nombre, celular, mascota, empieza, servicios[])
```

Esta RPC:

- encuentra o crea el perfil usando el celular;
- permite perfiles sin una cuenta de `auth.users`;
- encuentra o crea la mascota;
- no reemplaza el nombre existente de un cliente;
- recalcula precio y duración desde la tabla `servicios`;
- crea la cita dentro de una transacción;
- registra un solapamiento como `23P01`, traducido por Dart a `SlotTakenException`.

Las citas están protegidas con una restricción de exclusión GiST. Validar en Flutter mejora la experiencia, pero la restricción de PostgreSQL es la protección definitiva frente a dos personas que reservan el mismo horario al mismo tiempo.

Las funciones internas de creación y edición no deben ser invocables por `anon` o `authenticated`. Toda función pública nueva debe revisar explícitamente sus permisos para ambos roles, porque Supabase concede `EXECUTE` por separado.

## Administración y RLS

El acceso administrativo se determina en la base de datos:

- existe una fila en `admins` para la cuenta dueña;
- `es_admin()` comprueba el usuario autenticado;
- las políticas RLS exigen `es_admin()` para operaciones privadas.

El cliente no decide por sí mismo si un usuario tiene privilegios. No se debe confiar en ocultar controles o pantallas en Flutter como mecanismo de autorización.

Los datos privados incluyen observaciones, notas de mascotas, directorio administrativo, fotos de mascotas y estadísticas completas. No hay políticas públicas para que los clientes lean esos datos.

## Asistente con IA

La Edge Function `supabase/functions/asistente/` tiene dos modos:

- `modo: "cliente"`: disponible sin sesión y con herramientas limitadas a consultar servicios y horarios y reservar.
- `modo: "resumen"`: exige JWT y requiere que `es_admin()` devuelva verdadero; los demás usuarios reciben `403`.

La función usa Gemini mediante `generateContent`. El proveedor está aislado en `modelo.ts`:

- `conversar`;
- `mensajeUsuario`;
- `resultadosHerramientas`.

Para cambiar de proveedor hay que adaptar esas funciones sin trasladar decisiones de negocio a la IA. Las reservas siguen pasando por `reservar_cita_por_celular`; la IA no calcula precios, duraciones ni solapamientos.

La app conserva e intercambia el historial de chat sin modificarlo. El backend valida únicamente roles y partes admitidos y limita su tamaño.

### Configurar Gemini

1. Crear una clave en Google AI Studio.
2. En Supabase, abrir **Edge Functions → Secrets**.
3. Crear `GEMINI_API_KEY`.
4. Opcionalmente configurar `GEMINI_MODEL`.
5. Desplegar `asistente` sin verificación JWT, porque el modo cliente no usa sesión.

```bash
npx supabase login
npx supabase link --project-ref <tu-ref>
npx supabase functions deploy asistente --no-verify-jwt
```

Si la clave o la función no están disponibles, el asistente informa que no está disponible y deja disponible la reserva normal.

> En el plan gratuito de Gemini, Google puede usar los datos enviados para mejorar sus productos. Mientras se use ese plan, la prueba debe hacerse con datos ficticios. Para datos reales de clientes se necesita un plan de pago o un proveedor que cumpla las obligaciones de privacidad aplicables.

## Fotos de mascotas

Las fotos se guardan en el bucket privado `fotos-mascotas`.

- Solo se aceptan archivos `image/webp`.
- Tamaño máximo: 2 MB.
- La app convierte la imagen a WebP y la reduce a 1280 píxeles por lado.
- Solo las administradoras pueden ver, subir, reemplazar o borrar fotos.
- Las rutas contienen el ID de la mascota y una marca única para evitar cachés de una foto reemplazada.

## Aplicar las migraciones

Desde el SQL Editor de Supabase:

1. ejecutar los archivos de `supabase/migrations/` en orden lexicográfico;
2. ejecutar `supabase/seed.sql`;
3. probar primero con datos inventados;
4. si hace falta repetir la instalación, ejecutar `supabase/reset.sql` y comenzar de nuevo.

Las migraciones más recientes incorporan:

- clientes identificados por celular;
- resumen mensual de clientes nuevos;
- anonimización de clientes;
- fotos privadas de mascotas;
- límite de agenda a 90 días;
- permisos internos de funciones administrativas.

## Seguridad y datos personales

- RLS protege los datos publicados desde el cliente.
- La clave `anon` no es un secreto.
- `service_role` debe permanecer fuera de Flutter y de cualquier configuración versionada.
- Los nombres, celulares y mascotas deben considerarse datos personales.
- No deben enviarse datos reales al plan gratuito de Gemini.
- Las cuentas sin sesión pueden reservar por celular, pero esa identificación no sustituye una confirmación por SMS.
- La eliminación de un cliente anonimiza su perfil: no borra automáticamente el historial necesario para conservar citas y estadísticas pasadas.

## Solución de problemas

### La app arranca con datos de muestra

Revisa que:

- exista `env/dev.json`;
- contenga `SUPABASE_URL` y `SUPABASE_ANON_KEY`;
- hayas usado `run.ps1`, `run.sh` o una configuración de VS Code con el archivo de variables;
- `AppConfig` conserve `const` al leer `String.fromEnvironment`.

### Flutter o Dart están bloqueados

En Windows puede aparecer `dart.exe ha sido bloqueado`. Autoriza Flutter/Dart en las políticas del equipo o usa un entorno permitido. No reemplaces la aplicación Flutter por una alternativa para evitar la política del sistema.

### Supabase muestra errores 23P01

El horario ya fue ocupado por otra operación. La app debe mostrar que el turno ya no está disponible y permitir seleccionar otro.

### Una función devuelve permiso denegado

Comprueba que:

- esté ejecutándose con la sesión correcta;
- la cuenta esté registrada en `admins` si es una operación administrativa;
- hayas aplicado todas las migraciones;
- los permisos de `EXECUTE` se hayan concedido o revocado explícitamente.

## Licencia

Este repositorio no declara una licencia pública. Consulta a su propietario antes de reutilizar, distribuir o publicar el código o sus activos.
