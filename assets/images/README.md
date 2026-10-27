# Imágenes

`logo.png` es el logotipo de Perro Look. La carpeta entera está declarada en
`pubspec.yaml`, así que para cambiarlo basta con reemplazar el archivo y
correr `flutter pub get`: `BrandLogo` lo toma sin que haya que tocar código.
Si falta, `BrandLogo` dibuja el lockup tipográfico y la app funciona igual.

## Cómo está preparado el archivo actual

Partía de un original de 1525x1536 y 714 KB, con un margen blanco grande y
desigual (140 px a la izquierda, 73 a la derecha) que dejaba la marca
descentrada y pequeña dentro de su recuadro. Se le hizo:

1. **Recorte** a la caja de contenido real, 1313x1337.
2. **Recentrado** en un lienzo cuadrado, ocupando el 92 % para dejar un
   respiro uniforme.
3. **Reescalado** a 512x512 con Lanczos. El tamaño máximo al que se dibuja
   son 132 px lógicos (el splash), así que 512 cubre pantallas de 3x.
4. **Paleta de 64 colores** sin tramado. El resultado son 69 KB, un 90 %
   menos que el original, sin degradación visible: la marca usa pocos
   colores planos.

El peso importa porque en web el archivo se descarga en el primer arranque y
`AppBootstrap` lo precarga antes de abrir el Home.

## Si lo reemplazas

- **Cuadrado**, o casi. `BrandLogo` reserva un hueco cuadrado y lo centra.
- **Sin margen propio**: el recuadro ya pone el suyo. Un logotipo con aire
  incorporado se ve pequeño dentro del badge.
- **512x512 basta.** Más resolución solo es peso.
- Puede llevar **fondo blanco o transparencia**; el recuadro es blanco, así
  que las dos cosas se ven igual.

El original sin tocar sigue en `Downloads/logo.jpeg`.
