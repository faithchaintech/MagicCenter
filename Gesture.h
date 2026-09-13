#pragma once
#include <stdbool.h>
#include <math.h>
typedef struct { bool enabled, dragging; int originalButton; double width; unsigned long clicks; } Gesture;
// Input kind: 0 down, 1 drag, 2 up. Button: 0 left, 1 right.
static bool convert(Gesture *g, int kind, int button, int fingers, double x, double age, bool trackpad) {
    if (g->dragging) {
        if (button != g->originalButton) return false;
        if (kind == 2) g->dragging = false;
        return true;
    }
    if (kind != 0 || !g->enabled || trackpad || fingers != 1 || age < 0 || age > .20 || !isfinite(x)) return false;
    if (fabs(x - .5) > g->width / 2) return false;
    g->dragging = true; g->originalButton = button; g->clicks++;
    return true;
}
