# discourse-monero-tips

[![Linting and Tests](https://github.com/somos-criptonautas/discourse-monero-tips/actions/workflows/plugin-linting-and-tests.yml/badge.svg)](https://github.com/somos-criptonautas/discourse-monero-tips/actions/workflows/plugin-linting-and-tests.yml)

[ENGLISH](README.md) | **ESPAÑOL**

Propinas en Monero entre miembros. Cada quien publica la dirección de su propio monedero y la propina va directo de un monedero al otro. El foro nunca guarda fondos, nunca guarda claves y —en esta versión— nunca confirma que la propina llegó.

## Cómo funciona

1. Un miembro pega su dirección de Monero en **Preferencias → Perfil**.
2. La dirección se valida y se guarda como campo público de usuario.
3. Aparece un icono de propina junto a su nombre en cada publicación y en su perfil.
4. Quien lo toque obtiene la dirección, un código QR y un enlace `monero:` que abre su propio monedero.

Ese es todo el flujo. No hay pago, ni callback, ni webhook, porque nada pasa por Discourse.

## Instalación

Agregá esto a `containers/app.yml` y reconstruí:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/somos-criptonautas/discourse-monero-tips.git
```

Después activá `monero_tips_enabled`.

## Ajustes

| Ajuste | Para qué |
|---|---|
| `monero_tips_enabled` | Apagado por defecto |
| `monero_tips_icon` | El icono de la propina. Por defecto `ph-dt-xmr`, que viene de nuestro set Phosphor duotone; cambialo por uno que tenga tu propio set (`coins` y `hand-holding-dollar` vienen con Discourse) |

## Qué no hace

**No verifica nada.** Los montos en Monero están cifrados, así que una dirección sola no le dice a nadie si hubo un pago: ni al foro, ni a quien da la propina, ni a quien la recibe. Por eso acá no hay contadores, ni totales, ni tabla de posiciones, ni insignias: cada una de esas cosas sería un número que este plugin no puede sostener.

Una dirección mal copiada no puede perder la plata de nadie. Las direcciones de Monero llevan un checksum y el monedero de quien envía se niega a gastar hacia una dirección rota, así que un error de tipeo no envía: falla. Acá solo se valida el formato, y por eso el campo es tuyo para revisarlo bien.

## Propinas verificadas, más adelante

Se puede verificar sin que el foro toque los fondos, y hace falta un nodo de Monero: justo lo que ya tiene un foro que corra BTCPay con Monero activado. Hay dos caminos, y pueden convivir:

- **Prueba por propina.** Quien envía pega el id de la transacción y su clave; el foro lo verifica contra el nodo (`check_tx_key`). No se guarda ningún secreto y, como esa clave solo la tiene quien envió, la prueba también establece quién fue.
- **Clave de vista.** Un miembro que lo elija entrega su clave de vista privada una vez y las propinas que reciba se detectan solas. Una clave de vista no puede gastar, así que sigue sin haber custodia, pero es un secreto permanente que revela todos los pagos entrantes de ese monedero y no se puede rotar sin mudarse de monedero. A quien entregue una hay que decírselo claro, en la interfaz, en el momento de pegarla.

Las insignias y los puntos irían sobre cualquiera de los dos caminos, porque ambos producen una propina de la que el foro sí puede responder.

## Desarrollo

```bash
pnpm install && pnpm lint
```

Specs: `bundle exec rspec plugins/discourse-monero-tips/spec`. Frontend: `/qunit?filter=Monero`.

## Licencia

GPL-3.0. Ver [LICENSE](LICENSE).

El texto de este README bajo [CC BY-NC-SA 4.0](CC-BY-NC-SA-4.0.txt).
