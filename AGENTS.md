# Nebula Contributor & Agent Guidelines

Guidelines for automated coding agents and contributors working on the Nebula desktop shell.

---

## Documentation Order

When inspecting APIs, verifying properties, or designing QML components, use documentation in this strict order:

1. **Quickshell types and properties**: [https://quickshell.org/docs/v0.3.0/types/](https://quickshell.org/docs/v0.3.0/types/)
   - Quickshell Wayland / Hyprland integration (`WlrLayershell`, `PanelWindow`, `Scope`, `Variants`)
   - Quickshell I/O (`FileView`, `Process`, `IpcHandler`, `JsonAdapter`)
   - Services (`Quickshell.screens`, `Quickshell.env`, `Quickshell.shellPath`)
2. **Core QML features**: [https://doc.qt.io/qt-6/qtqml-index.html](https://doc.qt.io/qt-6/qtqml-index.html)
   - Property bindings, behaviors, animations, state machines, component lifecycles
3. **Qt Quick visual elements**: [https://doc.qt.io/qt-6/qtquick-index.html](https://doc.qt.io/qt-6/qtquick-index.html)
   - Geometry, Layouts (`RowLayout`, `ColumnLayout`), `Flickable`, `ListView`, `MultiEffect`
4. **Qt Quick Controls & Styling**: [https://doc.qt.io/qt-6/qtquickcontrols-styles.html](https://doc.qt.io/qt-6/qtquickcontrols-styles.html)
   - Standard controls (`AbstractButton`, `Button`, `ItemDelegate`, `ScrollView`, `ScrollBar`)
   - Proper separation of `contentItem` and `background`
5. **Qt Quick Shapes (GPU Vectors)**: [https://doc.qt.io/qt-6/qml-qtquick-shapes-shape.html](https://doc.qt.io/qt-6/qml-qtquick-shapes-shape.html)
   - Vector rendering (`Shape`, `ShapePath`, `PathSvg`, `preferredRendererType: Shape.CurveRenderer`)

---

## Working Rules

### 1. Verify, Never Guess
- **Do not guess Quickshell or Qt APIs.** If anything is unclear, ambiguous, or uncertain, verify it against the documentation listed above before writing code.
- Check signal signatures, property types, and deprecation notices (e.g. `implicitWidth` / `implicitHeight` over `width` / `height` on window roots).

### 2. Architecture Over Crutches
- **No brittle workarounds or magic numbers.** Never use hardcoded pixel offsets (`-34`, `+60`, `0.22`), arbitrary `Timer` delays to race asynchronous state, or fake hover hacks.
- Identify the root cause and perform a proper architectural refactor.

### 3. Proper Control Semantics & Accessibility
- Do not build interactive buttons as bare `Rectangle + MouseArea` with manual `containsMouse` color switching unless an explicit custom gesture canvas is required.
- Use standard `QtQuick.Controls` components (`Button`, `ItemDelegate`) or adhere to control contracts with distinct `hovered`, `pressed`, `down`, `checked`, and `focused` states.
- Ensure all interactive elements support keyboard accessibility (`activeFocus`, `Tab` traversal, `Space`/`Enter` activation).

### 4. Scrollbar & Content Space Reservation
- `ScrollBar.vertical` in Qt Quick attaches as an overlay on top of `Flickable` content.
- Never let content take 100% width when a scrollbar is active (`width: flick.width` causes scrollbars to overlap right-aligned icons, toggles, and text).
- Always reserve dedicated gutter space for the scrollbar when scrolling is active:
  ```qml
  width: flick.width - (scrollBar.size < 1.0 ? scrollBar.width : 0)
  ```

### 5. Vector Graphics Over Icon Fonts
- Render icons as hardware-accelerated vector shapes (`QtQuick.Shapes` with `Shape.CurveRenderer` and `PathSvg`, or `Kirigami.Icon`) rather than font ligatures.
- Icon fonts suffer from FOUC (flashing raw text words like "add" or "settings" during load), missing glyph mismatches, and baseline/optical alignment shifts.
- Keep icon sizing strictly optical: `width == height == iconSize`.

### 6. Dynamic Multi-Monitor Geometry
- Never hardcode screen resolutions (e.g. `1920x1080`).
- Always query `Quickshell.screens` or the attached window's `screen` property.
- Calculate safe work areas dynamically by respecting real bar/dock insets (`GlobalStates.editTopInset`, `GlobalStates.editBottomInset`) so components never overlap or clip beneath bars.

### 7. Keyboard Navigation & Dismissal
- Every modal window, drawer, panel, and popup must handle `Key_Escape` cleanly to close or cancel.
- Escape must bubble up or dismiss the overlay rather than being silently swallowed by inert child items.
- Ensure clicks outside modal cards dismiss the overlay without triggering underlying desktop elements.
