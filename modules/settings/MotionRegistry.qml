pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs.modules.settings

Singleton {
    id: root

    readonly property var roles: ["panel.open", "panel.close", "panel.slide", "dock.preview", "dock.hover", "bar.slide", "workspace.switch", "workspace.pill", "notification.panel", "notification.card", "notification.group", "button.press", "fade", "color.fade", "launcher.open", "launcher.close", "notification.popup", "surface.reveal", "bar.block"]
    readonly property string scheme: SettingsConfig.general.motionScheme ?? "expressive"
    readonly property var roleOverrides: SettingsConfig.general.motionRoles ?? ({})

    function styleFor(role: string): string {
        const override = root.roleOverrides[role];
        const style = typeof override === "string" ? override : override?.style;
        const selected = style ?? root.scheme;
        return ["expressive", "snappy", "gentle", "spring", "bouncy", "elastic", "bounce", "anticipate", "smooth", "linear", "custom", "instant"].includes(selected) ? selected : "expressive";
    }

    function isEnabled(role: string): bool {
        return root.styleFor(role) !== "instant";
    }

    function durationFor(role: string, defaultSpeed: string): int {
        const override = root.roleOverrides[role];
        if (override?.duration !== undefined && override?.duration !== null)
            return override.duration;
        const style = root.styleFor(role);
        if (style === "instant")
            return 0;
        if (style === "snappy")
            return M3Motion.effectsDuration(defaultSpeed);
        if (style === "gentle") {
            if (defaultSpeed === "fast")
                return M3Motion.effects.slowDuration;
            if (defaultSpeed === "slow")
                return M3Motion.spatial.moveDuration;
            return M3Motion.container.duration;
        }
        return M3Motion.spatialDuration(defaultSpeed);
    }

    function curveFor(role: string, defaultSpeed: string): var {
        const curve = root.roleOverrides[role]?.curve;
        if (curve !== undefined && curve !== null)
            return curve.length === 4 ? curve.concat([1, 1]) : curve;
        return M3Motion.spatialCurve(defaultSpeed);
    }

    function easingTypeFor(role: string): int {
        const style = root.styleFor(role);
        if (style === "snappy")
            return Easing.OutCubic;
        if (style === "gentle")
            return Easing.InOutSine;
        if (style === "spring" || style === "bouncy")
            return Easing.OutBack;
        if (style === "elastic")
            return Easing.OutElastic;
        if (style === "bounce")
            return Easing.OutBounce;
        if (style === "anticipate")
            return Easing.InOutBack;
        if (style === "smooth")
            return Easing.OutExpo;
        if (style === "linear" || style === "instant")
            return Easing.Linear;
        return Easing.BezierSpline;
    }

    function overshootFor(role: string): real {
        const override = root.roleOverrides[role];
        if (override?.overshoot !== undefined && override?.overshoot !== null)
            return override.overshoot;
        const style = root.styleFor(role);
        if (style === "bouncy" || style === "spring")
            return 1.7;
        return style === "anticipate" ? 1.4 : 1.0;
    }

    function amplitudeFor(role: string): real {
        return root.roleOverrides[role]?.amplitude ?? 1.0;
    }

    function periodFor(role: string): real {
        return root.roleOverrides[role]?.period ?? (root.styleFor(role) === "elastic" ? 0.35 : 0.3);
    }

    function springParamsFor(role: string): var {
        const style = root.styleFor(role);
        const defaults = style === "snappy" ? M3Motion.spring.responsive : style === "gentle" ? M3Motion.spring.gentle : M3Motion.spring.expressive;
        const override = root.roleOverrides[role];
        return {
            spring: override?.spring ?? defaults.spring,
            damping: override?.damping ?? defaults.damping,
            mass: override?.mass ?? defaults.mass ?? 1.0
        };
    }
}
