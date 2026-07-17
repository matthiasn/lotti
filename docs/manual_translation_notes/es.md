# Notas de revisión de la traducción española

Este documento recoge decisiones y dudas que aparecieron al revisar la
localización de la aplicación. Es informativo: ayuda a una futura revisión
nativa y no sustituye las pruebas de cada pantalla con la interfaz real.

## Decisiones de esta pasada

- La aplicación se dirige a la persona usuaria de manera informal: **tú**,
  **tu**, **elige**, **añade** e **inténtalo**.
- **IA** se usa para la inteligencia artificial. Los nombres comerciales como
  **Mistral AI**, **Nebius AI Studio** y **OpenAI** se conservan tal cual.
- Los ciclos en que trabaja un agente se denominan **activaciones**. Así se
  evita mezclar «wake» en inglés, *despertar* como traducción literal y
  *activación*.
- **Valores medibles** distingue las definiciones numéricas que se configuran
  de las **mediciones** que se registran.

## Pendiente de una revisión nativa con la aplicación

| Área | Término o texto | Por qué conviene revisarlo |
| --- | --- | --- |
| Personalidades de agentes | `Alma`, `Conversación individual sobre el alma` | *Alma* conserva la metáfora del producto, pero puede sonar demasiado literal en una interfaz en español. Conviene decidir si se mantiene como nombre del concepto o si debe presentarse siempre como una personalidad de agente. |
| Valores numéricos | `Valores medibles` | Es más natural que el sustantivo aislado *medible*, pero una persona usuaria puede preferir *métricas* o *variables*. La decisión debe comprobarse junto a las pantallas de gráficos y registro de mediciones. |
| Daily OS | `check-in por voz`, `prompt` | Son préstamos habituales en productos de productividad y de IA. Hay que verificar en contexto si el producto prefiere conservarlos o usar expresiones como *registro por voz* e *instrucción*. |
| Reparación de sincronización | `relleno`, `registro de secuencia`, `marca de agua`, `irresoluble` | Son términos técnicos de recuperación de datos. La localización actual es comprensible, pero necesita una revisión especializada junto con los flujos de sincronización para garantizar que no sugiera una acción riesgosa distinta. |
| Etiquetas de instrumentación | `FTUE`, identificadores de modelos y proveedores | Las abreviaturas y los nombres de productos se han conservado cuando forman parte de una integración o de diagnósticos. Deben revisarse visualmente para confirmar qué partes llegan realmente a usuarios finales. |
