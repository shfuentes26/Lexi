# Personal English Dictionary — MVP 1.0

Aplicación iOS nativa, **SwiftUI + SwiftData + MVVM**, sin servicios externos.

## Abrir

1. Descomprime el ZIP en tu Mac.
2. Abre `PersonalEnglishDictionary.xcodeproj` con Xcode 16 o posterior.
3. Selecciona un iPhone con iOS 18+ (para Translation se recomienda dispositivo físico).
4. En **Signing & Capabilities**, selecciona tu **Team** y modifica el Bundle Identifier si hace falta.
5. Pulsa **Run**.

## Arquitectura

- `Models/`: entidades SwiftData `Word`, `Meaning`, `WordExample`, `LearningProgress`.
- `ViewModels/`: `DictionaryViewModel`, `WordEditorViewModel`, `PracticeViewModel` con Observation (`@Observable`).
- `Views/`: cinco tabs más pantalla de detalle y componentes reutilizables.
- `Services/`: voz nativa AVSpeechSynthesizer y repetición espaciada estilo SM-2.

## Traducción

Se usa exclusivamente **Translation** de Apple vía `.translationTask`, bajo demanda. Los modelos de idiomas pueden requerir descarga autorizada por iOS. Traducción de palabras y ejemplos editable; si falla se permite introducción manual.

**Limitación acordada:** el framework Apple Translation *traduce*, pero **no crea por sí mismo ejemplos naturales**. Sin servicio externo de IA, los ejemplos se escriben manualmente y se pueden traducir con Apple. No se ha añadido ninguna API externa ni claves.

## MVP implementado

- Alta, edición y eliminación de palabras; detección de duplicados por palabra/idioma.
- Múltiples significados y ejemplos por significado.
- Traducción Apple inglés↔español iniciada por botón.
- Listado alfabético, filtros, búsqueda por palabra o traducción, favoritos.
- Pronunciación US/UK con voces del sistema y frases de ejemplo.
- Flashcards, cuatro evaluaciones y próximas fechas de repaso persistidas.
- Persistencia local, modo claro/oscuro del sistema, interfaz iOS nativa.

## Verificación

La estructura del proyecto y la sintaxis básica han sido revisadas, pero **no es posible compilar/probar iOS aquí**, porque este entorno no incluye Xcode, SDK iOS ni simulador. Haz el primer build en tu Mac; si sale un error de compilación, compártemelo para ajustarlo.

No se incluyen tests de integración ni assets de App Store; no se afirma que el proyecto haya sido validado sobre hardware real.
