; ==================================================================================================
; DLL WRAPPER MODULE
; --------------------------------------------------------------------------------------------------
; SC_DllCall, CAP_SM, safe WinAPI wrappers, sentinel validators
; ==================================================================================================

; -------- Safe wrapper for DllCall (no throw, logs once per call) --------
SC_DllCall(fn, params*) {
    try {
        return DllCall(fn, params*)
    } catch as e {
        ; best effort logging (never throw)
        try {
            Log("DllCall FAIL: " fn " | err=" e.Message, "ERROR", "DLL")
        } catch {
        }
        return 0
    }
}


; -------- Sentinel validators --------
SC_IsMap(x) {
    return IsObject(x) && (x is Map)
}

SC_IsArray(x) {
    return IsObject(x) && (x is Array)
}

SC_TryGet(m, k, def := "") {
    if (!IsObject(m))
        return def
    try {
        if (m.Has(k))
            return m[k]
    } catch {
    }
    return def
}

; =========================================================
; CAPTURE DEBUG MASTER HELPERS (CAP | ...)
; =========================================================
CAP_SM(n) {
    ; Safe GetSystemMetrics
    try {
        return DllCall("user32.dll\GetSystemMetrics", "int", n, "int")
    } catch {
        return 0
    }
}

CAP_GetVirtualDesktop(&vx, &vy, &vw, &vh) {
    ; Virtual screen may start at negative coords in multi-monitor setups.
    vx := CAP_SM(76) ; SM_XVIRTUALSCREEN
    vy := CAP_SM(77) ; SM_YVIRTUALSCREEN
    vw := CAP_SM(78) ; SM_CXVIRTUALSCREEN
    vh := CAP_SM(79) ; SM_CYVIRTUALSCREEN
    if (vw <= 0)
        vw := A_ScreenWidth
    if (vh <= 0)
        vh := A_ScreenHeight
}

CAP_GetSystemDPI() {
    global SYS_DPI
    if (IsSet(SYS_DPI) && SYS_DPI > 0)
        return SYS_DPI
    try {
        return DllCall("user32.dll\GetDpiForSystem", "uint")
    } catch {
        return (A_ScreenDPI > 0 ? A_ScreenDPI : 96)
    }
}

CAP_GetWindowDPI(hwnd, sysDpi := 96) {
    if (!hwnd)
        return sysDpi
    try {
        dpi := DllCall("user32.dll\GetDpiForWindow", "ptr", hwnd, "uint")
        return (dpi > 0 ? dpi : sysDpi)
    } catch {
        return sysDpi
    }
}

CAP_GetMonitorIndexForPoint(x, y, &total) {
    total := 0
    idx := 0
    try {
        ; Prefer built-ins (Win 10/11)
        total := MonitorGetCount()
        if (total <= 0)
            total := CAP_SM(80) ; SM_CMONITORS
        Loop total {
            i := A_Index
            MonitorGet(i, &l, &t, &r, &b)
            if (x >= l && x < r && y >= t && y < b)
                return i
        }
        return 0
    } catch {
        total := CAP_SM(80)
        return 0
    }
}

CAP_Log(msg, level := "DEBUG") {
    ; Centralized capture log line
    try {
        Log(msg, level, "CAP")
    } catch {
    }
}

CAP_KV(stage, capId, kv, level := "DEBUG") {
    ; stage="START"/"DPI"/"VALID"/... kv already formatted "a=b c=d ..."
    CAP_Log(Format("CAP | {} id={} {}", stage, capId, kv), level)
}

CAP_IsWindowVisible(hwnd) {
    try {
        return DllCall("user32.dll\IsWindowVisible", "ptr", hwnd, "int")
    } catch {
        return 0
    }
}

; =========================
; IDOL CAP LAYER (no refactor)
; Target detect + best HWND for PrintWindow (Browser/Electron).
; =========================
CAP_DetectTargetType(hwnd) {
    ; Returns: "BROWSER" | "GAME" | "APP"
    cls := ""
    exe := ""
    try {
        cls := WinGetClass("ahk_id " hwnd)
    } catch {
        cls := ""
    }
    try {
        exe := StrLower(WinGetProcessName("ahk_id " hwnd))
    } catch {
        exe := ""
    }

    if (cls = "")
        return "APP"

    ; Browsers / Chromium / Electron shells
    if (InStr(cls, "Chrome_WidgetWin") || cls = "MozillaWindowClass"
        || InStr(exe, "chrome") || InStr(exe, "firefox") || InStr(exe, "msedge")
        || InStr(exe, "opera") || InStr(exe, "brave") || InStr(exe, "electron")) {
        return "BROWSER"
    }

    ; Game classes / DirectX
    if (InStr(cls, "UnityWndClass") || InStr(cls, "UnrealWindow")
        || InStr(cls, "SDL_app") || InStr(cls, "GLFW")) {
        return "GAME"
    }

    return "APP"
}

CAP_GetBestPrintWindowHwnd(hwnd) {
    ; For Chromium/Electron, find the child "Chrome_RenderWidgetHostHWND" or "Chrome_WidgetWin_1"
    ; that actually holds the content rendering layer.
    cls := ""
    try {
        cls := WinGetClass("ahk_id " hwnd)
    } catch {
        return hwnd
    }

    ; If it's already a Chromium child, return it
    if (InStr(cls, "Chrome_RenderWidgetHostHWND"))
        return hwnd

    ; Try to find child window with rendering surface
    childHwnd := 0
    try {
        childHwnd := ControlGetHwnd("Chrome_RenderWidgetHostHWND1", "ahk_id " hwnd)
    } catch {
    }
    if (childHwnd)
        return childHwnd

    ; Fallback to the main window
    return hwnd
}
