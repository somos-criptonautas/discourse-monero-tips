# discourse-monero-tips

[![Linting and Tests](https://github.com/somos-criptonautas/discourse-monero-tips/actions/workflows/plugin-linting-and-tests.yml/badge.svg)](https://github.com/somos-criptonautas/discourse-monero-tips/actions/workflows/plugin-linting-and-tests.yml)

[ENGLISH](README.md) | **ESPAÑOL**

Mantenido por Criptonautas. Sin afiliación ni respaldo de Discourse (Civilized Discourse Construction Kit, Inc.).

**Monero Tips**: propinas en Monero entre miembros. Cada quien publica la dirección de su propio monedero y la propina va directo de un monedero al otro. El foro nunca guarda fondos, nunca guarda claves y —en esta versión— nunca confirma que la propina llegó.

## Cómo funciona

1. Un miembro pega su dirección de Monero en **Preferencias → Perfil**.
2. La dirección se valida y se guarda como campo público de usuario.
3. Aparece un icono de propina en la esquina inferior izquierda de cada publicación suya y en su perfil.
4. Quien lo toque obtiene la dirección, un código QR y un enlace `monero:` que abre su propio monedero.

Los admins pueden cargar la dirección de otra cuenta desde las preferencias de ese usuario, por ejemplo `system`, que es quien publica los temas incrustados. Cada cambio queda en el registro de acciones del staff como `monero_address_change`, y el miembro recibe un mensaje avisándole. Los moderadores no pueden.

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
| `monero_tips_icon` | El icono de la propina, elegido desde un desplegable. Por defecto `ph-dt-xmr`, un glifo de Monero que trae el plugin, así que se ve para todos sin necesitar un set de iconos propio |
| `monero_tips_verified_enabled` | Permite activar propinas verificadas. Necesita un wallet RPC, ver abajo |
| `monero_wallet_rpc_url` | El endpoint del wallet RPC |
| `monero_tips_restore_height` | Desde dónde escanean los monederos nuevos |
| `monero_tips_min_confirmations` | Confirmaciones para que cuente una propina. Por defecto 10 |
| `monero_tips_min_amount` | Umbral de polvo en XMR |
| `monero_tips_points_per_xmr` | Puntos de gamificación para quien envía. 0 lo apaga |

## Qué no hace, hasta que actives las propinas verificadas

**No verifica nada.** Los montos en Monero están cifrados, así que una dirección sola no le dice a nadie si hubo un pago: ni al foro, ni a quien da la propina, ni a quien la recibe. Por eso acá no hay contadores, ni totales, ni tabla de posiciones, ni insignias: cada una de esas cosas sería un número que este plugin no puede sostener.

Una dirección mal copiada no puede perder la plata de nadie. Las direcciones de Monero llevan un checksum y el monedero de quien envía se niega a gastar hacia una dirección rota, así que un error de tipeo no envía: falla. Acá solo se valida el formato, y por eso el campo es tuyo para revisarlo bien.

## Monero Tips verificadas

Apagadas hasta que haya un wallet RPC de Monero accesible, y aun así cada miembro decide. Nada de esto es custodial: el foro solo llega a tener claves **de vista**, que no pueden gastar.

### Qué necesita el foro

Un `monero-wallet-rpc` que no tenga más que monederos de solo lectura, apuntado a un nodo: el mismo que ya corre un BTCPay Server con Monero activado.

```yaml
monero-tips-wallet-rpc:
  image: sethsimmons/simple-monero-wallet-rpc:latest
  command: >
    --wallet-dir /wallet
    --daemon-address monerod:18081
    --trusted-daemon
    --rpc-bind-port 18083
    --rpc-bind-ip 0.0.0.0
    --confirm-external-bind
    --rpc-login monero-tips:CAMBIAME
  volumes:
    - monero-tips-wallets:/wallet
```

**No puede quedar accesible desde fuera de tu red.** El RPC tiene un solo monedero abierto para todos sus clientes, así que cualquier cosa que lo alcance sin el login podría cambiar de monedero mientras el foro crea una dirección de propina y mandar las propinas a otro lado. Dejalo en la red interna con Discourse y el nodo, nunca publicado al host. El login es HTTP digest, que oculta la contraseña pero no el tráfico, claves de vista incluidas; si el RPC está en otro lugar que una red a la que solo llega Discourse, servilo por HTTPS con un certificado en el que Discourse confíe y usá una URL `https://`.

Después poné `monero_wallet_rpc_url` en `http://monero-tips-wallet-rpc:18083/json_rpc`, `monero_wallet_rpc_username` y `monero_wallet_rpc_password` en las dos mitades de `--rpc-login`, `monero_tips_restore_height` cerca de la altura actual para que los monederos nuevos no reescaneen toda la cadena, y activá `monero_tips_verified_enabled`.

### Qué hace un miembro

Pega su **clave de vista privada** en Preferencias → Perfil, después de leer qué implica. El plugin arma un monedero de solo lectura con su dirección y esa clave, y desde ahí cada miembro que abra su ventana de propina recibe una subdirección creada para ese par. Eso es lo que permite atribuir la propina: las transferencias de Monero no dicen quién envía, pero sí a qué subdirección llegaron. Solo se registran los pagos a esas subdirecciones; lo demás que llegue al monedero, no. Nadie recibe una subdirección de su propio monedero.

Puede desactivarlo cuando quiera: la clave se olvida y el escaneo se detiene. Las propinas ya registradas quedan, y las insignias ya otorgadas no se quitan.

### Qué le cuesta

Una clave de vista revela **todos** los pagos entrantes de ese monedero, para siempre, a quien la tenga, y no se puede rotar sin mudarse de monedero. Nunca puede gastar. La interfaz dice esto arriba del campo, antes de que se pueda pegar la clave: si traducís o reestilizás este plugin, dejalo así.

### Insignias y puntos

Vienen dos insignias como semillas, definidas como consultas SQL sobre la tabla del plugin, así que el otorgador de insignias de Discourse hace el trabajo y podés renombrarlas, cambiarles el estilo o desactivarlas desde la interfaz normal de insignias:

| Insignia | Para quién |
|---|---|
| Monero Tipper | quien haya hecho llegar una propina confirmada a otro miembro |
| Tipped in Monero | quien haya recibido una propina confirmada de otro miembro |

Las fechas de otorgamiento se redondean al día, para que la página de una insignia no empareje al segundo a quien envía con quien recibe.

`monero_tips_points_per_xmr` además le da puntos de gamificación a quien envía, por XMR, si está instalado `discourse-gamification`. Una propina cuenta como confirmada a partir de `monero_tips_min_confirmations` (10 por defecto), y todo lo que esté por debajo de `monero_tips_min_amount` se ignora como polvo.

### Workflows

Con Discourse Workflows activado, el disparador **Propina en Monero confirmada** se ejecuta una vez por propina, cuando llega a `monero_tips_min_confirmations`. Trae la propina (`txid`, `amount` en XMR, `confirmations`, `received_at`, `attributed`), el `payee` y el `tipper`, que es nulo cuando esa cuenta ya no existe. Su opción **Solo propinas atribuidas** las ignora. Otros plugins también pueden escuchar el evento `:monero_tip_confirmed` directamente.

### Qué sigue sin poder verificarse

Una propina pagada a la dirección pública de un miembro, y no a una subdirección creada para quien envía, no se registra: el foro no puede distinguirla de cualquier otro pago. Las propinas a miembros que nunca lo activaron no se ven en absoluto, y la ventana lo dice.

La atribución es tan honesta como quien recibe. Su monedero puede pagarle a cualquiera de sus subdirecciones, así que puede acreditar una propina a un miembro que nunca pagó, y un miembro podría activar la dirección y la clave de vista de un monedero ajeno. Tomá las insignias, los totales y `monero_tips_points_per_xmr` como lo que dice quien recibe, no como prueba.

## Desarrollo

```bash
pnpm install && pnpm lint
```

Specs: `bundle exec rspec plugins/discourse-monero-tips/spec`. Frontend: `/qunit?filter=Monero`.

## Licencia

MIT. Ver [LICENSE](LICENSE).

El texto de este README bajo [CC BY-NC-SA 4.0](CC-BY-NC-SA-4.0.txt).
