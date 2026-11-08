pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs.modules.settings

Singleton {
    id: root

    readonly property var roles: ["panel.open", "panel.close", "panel.slide", "dock.preview", "dock.hover", "bar.slide", "workspace.switch", "notification.card", "button.press", "fade"]
    readonly property string scheme: SettingsConfig.general.motionScheme ?? "expressive"
    readonly property var roleOverrides: SettingsConfig.general.motionRoles ?? ({})

    function styleFor(role: string): string {
        const override = root.roleOverrides[role];
        const style = typeof override === "string" ? override : override?.style;
        const selected = style ?? root.scheme;
        return ["expressive", "snappy", "gentle", "instant"].includes(selected) ? selected : "expressive";
    }

    function isEnabled(role: string): bool {
        return root.styleFor(role) !== "instant";
    }

    function durationFor(role: string, defaultSpeed: string): int {
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
        return M3Motion.spatialCurve(defaultSpeed);
    }

    function easingTypeFor(role: string): int {
        const style = root.styleFor(role);
        if (style === "snappy")
            return Easing.OutCubic;
        if (style === "gentle")
            return Easing.InOutSine;
        if (style === "instant")
            return Easing.Linear;
        return Easing.BezierSpline;
    }

    function springParamsFor(role: string): var {
        const style = root.styleFor(role);
        if (style === "snappy")
            return M3Motion.spring.responsive;
        if (style === "gentle")
            return M3Motion.spring.gentle;
        return M3Motion.spring.expressive;
    }
}
