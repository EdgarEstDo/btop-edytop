# edytop — btop con panel de GPU Intel (`xe`)

`edytop` es un **fork de [btop](https://github.com/aristocratos/btop)** que añade soporte para GPUs
Intel que usan el **driver de kernel `xe`** (Arc Battlemage/B-series, Lunar Lake y superiores) y un
lanzador propio para ver **CPU, memoria, red, disco y GPU en una sola pantalla**, sin abrir otra
terminal con `nvtop` al lado.

btop ya sabe dibujar paneles de GPU (cajas `gpu0`…`gpu5`, gráficas braille, VRAM, temperatura,
potencia, ventiladores y tabla de procesos GPU), pero su backend para Intel es el de `intel_gpu_top`,
que **solo entiende el driver antiguo `i915`**. En un equipo con `xe` no detecta la GPU:

```
$ intel_gpu_top -l
Detected Xe device which is not supported by intel_gpu_top.
Please use 'gputop' tool instead.
```

Este fork aporta el **recolector de datos para `xe`**; la interfaz es la de btop, sin cambios.

---

## Qué añade

* **Backend `xe`** en `src/linux/btop_collect.cpp` (+ definiciones UAPI mínimas en `src/linux/xe_drm.h`).
* **Detección multi-GPU** con enrutado i915/xe por instancia (no rompe el camino antiguo).
* **Uso de GPU** desde `fdinfo` (`drm-cycles-*` / `drm-total-cycles-*`), con respaldo en
  `gtidle` (sysfs) y, si hay privilegios, en los eventos **PMU** del driver
  (`engine-active-ticks` / `engine-total-ticks`).
* **VRAM**: total por ioctl `DRM_XE_DEVICE_QUERY`, usada agregando el `drm-total-vram0` de `fdinfo`.
* **Frecuencia** del GT desde sysfs / PMU, **temperatura**, **potencia** (por delta del contador
  `energy1_input` de `hwmon`) y **ventiladores**.
* **Tabla de procesos GPU** (PID, memoria, uso por motor) reutilizando la vista que ya existe en btop.
* **Lanzador `edytop`** con configuración propia (no toca la de `btop`).

## Requisitos

* Linux con kernel que exponga el driver `xe` (el `xe` también puede forzarse en GPUs Arc A-series).
* Toolchain de C++23 (`g++`/`clang++`, `make`) y `git`.
* Opcional para diagnóstico: `intel-gpu-tools` (`gputop`, que sí soporta `xe`).
* Para el camino PMU: privilegios de perf (`CAP_PERFMON`). El resto de métricas funciona sin root.

## Compilar y usar

```bash
git clone https://github.com/EdgarEstDo/btop-edytop.git
cd btop-edytop
git checkout edytop-xe

./edytop/rebuild.sh            # make -j  → bin/btop
install -Dm755 edytop/edytop ~/.local/bin/edytop
edytop
```

`edytop` crea su configuración en `~/.config/edytop/btop/btop.conf` a partir de
`edytop/edytop.conf.example` (misma config que btop, aislada). Puedes apuntar a otro binario o
directorio con las variables `EDYTOP_HOME` y `EDYTOP_BIN`.

## Configuración recomendada

| Clave en `btop.conf` | Valor | Por qué |
|---|---|---|
| `shown_boxes` | `"cpu mem net proc gpu0"` | añade la caja de GPU al layout |
| `show_gpu_info` | `"On"` | uso/temperatura de la GPU dentro de la caja de CPU |
| `graph_symbol_gpu` | `"braille"` (o `default`) | gráfica de uso |
| `disks_filter` | `"/home"` | muestra solo el disco de trabajo |
| `show_swap` | `true` | el swap se ve en la caja de memoria |

## Fuentes de datos (driver `xe`)

| Métrica | Origen | ¿Root? |
|---|---|---|
| Uso % | `fdinfo` (`drm-cycles-*`) → `gtidle` → PMU `xe_<bdf>` | solo PMU |
| VRAM total / usada | ioctl `DRM_XE_DEVICE_QUERY` / suma de `drm-total-vram0` | usada: no |
| Frecuencia GT | `tile0/gt0/freq0/*`, PMU `gt-actual-frequency` | no |
| Temperatura | `hwmon` (`temp*_input`, etiquetas `pkg`, `vram`, `mctrl`, `pcie`) | no |
| Potencia | delta de `hwmon/energy1_input` (µJ) | no |
| Ventiladores | `hwmon/fan*_input` | no |
| Procesos GPU | `/proc/<pid>/fdinfo/*` (`drm-driver: xe`) | procesos de otros usuarios |

**Limitaciones conocidas:** el driver `xe` no expone el *memory clock* de la VRAM, así que esa
métrica no se puede mostrar; el panel PMU requiere privilegios; en equipos con varias GPUs (p. ej.
integrada + dedicada) cada una se expone por separado.

### Precisión del dato de uso %

Por defecto el uso se calcula **sin privilegios** (deltas de `fdinfo` y, como respaldo, `gtidle`),
que es la misma familia de datos que usan `gputop` y `nvtop`. Medido con carga real en una Arc B580
frente a `gputop`: la diferencia ronda los **5 puntos porcentuales** en carga alta (~94 % vs ~99 %) y
el perfil de carga se reproduce fielmente, así que es suficiente para monitorizar de un vistazo.

Para quien quiera el dato exacto por motor, el driver expone su PMU (`engine-active-ticks` /
`engine-total-ticks`). Basta con conceder `CAP_PERFMON` al binario **una sola vez**:

```bash
sudo install -o root -g root -m755 bin/btop /usr/local/bin/btop-xe
sudo setcap cap_perfmon+ep /usr/local/bin/btop-xe
EDYTOP_BIN=/usr/local/bin/btop-xe edytop
```

(matiz: si el sistema de ficheros está montado con `nosuid`, las capacidades no se aplican y habría
que usar `sudo`). Sin ese permiso btop sigue funcionando igual, solo que con la fuente sin
privilegios.

## Estado y relación con upstream

* Base: **btop v1.4.7** + [PR #1457](https://github.com/aristocratos/btop/pull/1457)
  («Add Intel Xe GPU driver support»), **abierto y pendiente de merge** en el momento de escribir esto.
* Existen también el PR [#1771](https://github.com/aristocratos/btop/pull/1771) (backend Level Zero,
  experimental) y el issue [#1407](https://github.com/aristocratos/btop/issues/1407).
* Mientras el soporte no esté en una release oficial, este fork mantiene la rama `edytop-xe` con el
  parche aplicado. `edytop/rebuild.sh` incluye un modo para rebasar sobre `upstream/main`
  (`UPDATE_UPSTREAM=1`), y lo ideal es que el cambio acabe en upstream.

## Créditos y licencia

* btop: © Aristocratos y colaboradores — **Apache License 2.0** (ver `LICENSE`).
* Backend `xe`: cortesía del autor del PR #1457 (deveworld).
* Referencias de implementación: `intel-gpu-tools` (`gputop`, MIT) y `nvtop`.
