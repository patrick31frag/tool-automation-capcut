; ==================================================================================================
;  MODULE 03 — Pixel
;  Source lines (original scale.ahk): 999 – 1489
; ==================================================================================================
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

SC_RectUnpack(srcRect, &L, &T, &R, &B) {
    ; Accepts:
    ;   - Rect object (properties: L,T,R,B)
    ;   - Map with keys: "L","T","R","B"
    ;   - Array [L,T,R,B] (1-based) or [0..3]
    L := 0, T := 0, R := 0, B := 0

    if (!IsObject(srcRect))
        return false

    ; Rect class instance
    try {
        if (srcRect is Rect) {
            L := srcRect.L, T := srcRect.T, R := srcRect.R, B := srcRect.B
            return true
        }
    } catch {
    }

    ; Map-like keys
    try {
        if (srcRect.Has("L") && srcRect.Has("T") && srcRect.Has("R") && srcRect.Has("B")) {
            L := srcRect["L"], T := srcRect["T"], R := srcRect["R"], B := srcRect["B"]
            return true
        }
    } catch {
    }

    ; Array-like [L,T,R,B]
    try {
        if (srcRect is Array) {
            if (srcRect.Length >= 4) {
                L := srcRect[1], T := srcRect[2], R := srcRect[3], B := srcRect[4]
                return true
            }

            if (srcRect.Has(0) && srcRect.Has(1) && srcRect.Has(2) && srcRect.Has(3)) {
                L := srcRect[0], T := srcRect[1], R := srcRect[2], B := srcRect[3]
                return true
            }
        }
    } catch {
    }

    return false
}

SC_RectUnpack_SAFE(srcRect, &L, &T, &R, &B) {
    ; SAFE unpack:
    ;   - Rect-like objects with .L/.T/.R/.B (including property-getters, no HasOwnProp required)
    ;   - Map with keys: "L","T","R","B"
    ;   - Array [L,T,R,B] (1-based) or [0..3]
    ;   - String "L,T,R,B"
    L := 0, T := 0, R := 0, B := 0

    ; String "L,T,R,B"
    if (Type(srcRect) = "String") {
        parts := StrSplit(Trim(srcRect), ",")
        if (parts.Length = 4) {
            L := Trim(parts[1]) + 0
            T := Trim(parts[2]) + 0
            R := Trim(parts[3]) + 0
            B := Trim(parts[4]) + 0
            return true
        }
        return false
    }

    if (!IsObject(srcRect))
        return false

    ; Rect-like object (works for custom classes too)
    try {
        L := srcRect.L, T := srcRect.T, R := srcRect.R, B := srcRect.B
        return true
    } catch {
    }

    ; Map-like keys
    try {
        if (srcRect.Has("L") && srcRect.Has("T") && srcRect.Has("R") && srcRect.Has("B")) {
            L := srcRect["L"], T := srcRect["T"], R := srcRect["R"], B := srcRect["B"]
            return true
        }
    } catch {
    }

    ; Array-like [L,T,R,B]
    try {
        if (srcRect is Array) {
            if (srcRect.Length >= 4) {
                L := srcRect[1], T := srcRect[2], R := srcRect[3], B := srcRect[4]
                return true
            }

            if (srcRect.Has(0) && srcRect.Has(1) && srcRect.Has(2) && srcRect.Has(3)) {
                L := srcRect[0], T := srcRect[1], R := srcRect[2], B := srcRect[3]
                return true
            }
        }
    } catch {
    }

    return false
}


SC_IsRectLike(r) {
    L := 0, T := 0, R := 0, B := 0
    if (!SC_RectUnpack_SAFE(r, &L, &T, &R, &B))
        return false
    return IsNumber(L) && IsNumber(T) && IsNumber(R) && IsNumber(B) && (R > L) && (B > T)
}

RectAbsToWnd(hwnd, rectAbs) {
    ; Convert SCREEN-rect (abs) -> WINDOWDC-rect (relative to window top-left)
    L := 0, T := 0, R := 0, B := 0
    if (!SC_RectUnpack_SAFE(rectAbs, &L, &T, &R, &B))
        return 0
    rc := Buffer(16, 0)
    if (!DllCall("user32.dll\GetWindowRect", "ptr", hwnd, "ptr", rc, "int"))
        return 0
    wx := NumGet(rc, 0, "int")
    wy := NumGet(rc, 4, "int")
    return __RectClass(L - wx, T - wy, R - wx, B - wy)
}

GDI_BitBlt_FromHWND(hwnd, rectWnd, cap := 0) {
    ; WindowDC BitBlt using WINDOW-relative rect (LTRB)
    try {
        if (IsObject(cap))
            cap["coordBase"] := "WND"
    } catch {
    }
    return AL_GdipBitmapFromHWNDBitBlt(hwnd, rectWnd, cap)
}

GDI_BitBlt_FromScreen(rectAbs, cap := 0) {
    ; ScreenDC BitBlt using ABSOLUTE rect (LTRB)
; ---------------- AI_SAFEZONE100:CAPTURE_MODULE_BEGIN ----------------
; Capture helpers (SCREEN/HWND/DXGI). Keep flow isolated and return early per mode.
; ---------------------------------------------------------------------
    return AL_GdipBitmapFromScreenRect(rectAbs, cap)
}



IsNum(v) {
    s := Trim(v)
    if (s = "")
        return false
    return RegExMatch(s, "^-?\d+(\.\d+)?$")
}


ToIntSafe(v, def := 0) {
    try {
        s := Trim(v)
        if (s = "")
            return def
        return Integer(Number(s))
    } catch {
        return def
    }
}


; Convert "yyyy-MM-dd HH:mm:ss" => numeric key yyyymmddhhmmss. Returns 0 if invalid.
TimeKeySafe(s) {
    s := Trim(s)
    if (s = "")
        return 0
    if !RegExMatch(s, "^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})$", &m)
        return 0
    return Integer(m[1] . m[2] . m[3] . m[4] . m[5] . m[6])
}


ReverseArray(arr) {
    i := 1
    j := arr.Length
    while (i < j) {
        tmp := arr[i]
        arr[i] := arr[j]
        arr[j] := tmp
        i += 1
        j -= 1
    }
}

; -------- Stable Array Sort (for AHK v2 builds without built-in array sort) --------
; Comparator contract: cmpFn(a,b) > 0 => a comes after b ; < 0 => a comes before b ; 0 => equal.
AL_ArraySort(arr, cmpFn) {
    if !IsObject(arr)
        return false
    try {
        len := arr.Length
    } catch {
        return false
    }

    if (len <= 1)
        return true

    if !IsObject(cmpFn)
        cmpFn := (a, b) => (a > b) ? 1 : (a < b) ? -1 : 0

    tmp := []
    tmp.Length := len
    AL__MergeSort(arr, tmp, 1, len, cmpFn)
    return true
}

AL__MergeSort(arr, tmp, left, right, cmpFn) {
    if (left >= right)
        return

    mid := Floor((left + right) / 2)
    AL__MergeSort(arr, tmp, left, mid, cmpFn)
    AL__MergeSort(arr, tmp, mid + 1, right, cmpFn)

    i := left
    j := mid + 1
    k := left

    while (i <= mid && j <= right) {
        if (cmpFn(arr[i], arr[j]) <= 0) {
            tmp[k] := arr[i]
            i += 1
        } else {
            tmp[k] := arr[j]
            j += 1
        }
        k += 1
    }

    while (i <= mid) {
        tmp[k] := arr[i]
        i += 1
        k += 1
    }

    while (j <= right) {
        tmp[k] := arr[j]
        j += 1
        k += 1
    }

    idx := left
    while (idx <= right) {
        arr[idx] := tmp[idx]
        idx += 1
    }
}


; -------- INI fault surfacing (WRITE only, once) --------
NotifyIniWriteFaultOnce(file, section, key) {
    global iniFaultNotified
    if (iniFaultNotified)
        return
    iniFaultNotified := true
    try {
        MsgBox "INI WRITE FAILED!`n`nFile: " file "`nSection: [" section "]`nKey: " key "`n`nClose any editor/permission lock, then try again.", "ScaleCycle", "Iconx"
    } catch {
    }
    ; (Layer7) Core must not depend on UI. Status surfacing handled by UI/Behavior.
Log("INI WRITE FAILED file=" file " section=" section " key=" key, "WARN", "INI")
}


EnsureIniFile() {
    global CFG_FILE, iniFaulted
    try {
        if !FileExist(CFG_FILE) {
            FileAppend("", CFG_FILE, "UTF-8")
        }
    } catch {
        iniFaulted := true
    }
}


IniReadSafe(file, section, key, default := "") {
    global iniFaulted
    try {
        return IniRead(file, section, key, default)
    } catch {
        iniFaulted := true
        return default
    }
}


IniWriteSafe(value, file, section, key) {
    global iniFaulted
    try {
        IniWrite(value, file, section, key)
        return true
    } catch {
        iniFaulted := true
        NotifyIniWriteFaultOnce(file, section, key)
        return false
    }
}


; ============================================================

; =========================
; LOGIC / BEHAVIOR / UI (original functions)
; =========================
InitDpiGuard() {
    global DPI_AWARE, SYS_DPI, SCALE_PCT
    try {
        SC_DllCall("user32.dll\SetProcessDpiAwarenessContext", "ptr", -4, "int")
    } catch {
    }
    try {
        SC_DllCall("Shcore\SetProcessDpiAwareness", "int", 2, "int")
    } catch {
    }
    try {
        SC_DllCall("user32.dll\SetProcessDPIAware", "int")
    } catch {
    }

    try {
        ctx := SC_DllCall("user32.dll\GetThreadDpiAwarenessContext", "ptr")
        aw  := SC_DllCall("user32.dll\GetAwarenessFromDpiAwarenessContext", "ptr", ctx, "int")
        DPI_AWARE := (aw != 0)
    } catch {
        DPI_AWARE := true
    }

    try {
        SYS_DPI := SC_DllCall("user32.dll\GetDpiForSystem", "uint")
    } catch {
        SYS_DPI := A_ScreenDPI
    }

    if (SYS_DPI <= 0)
        SYS_DPI := 96
    SCALE_PCT := Round(SYS_DPI * 100 / 96)
}


GetDpiInfo() {
    global DPI_AWARE, SYS_DPI, SCALE_PCT
    return (DPI_AWARE ? "Aware" : "UNaware") " | System DPI=" SYS_DPI " (" SCALE_PCT "%)"
}


; AutoLearn UI Element - 5 Layers (AHK v2, no-ML)
; ============================================================
; This section contains only the 5 layers + minimal types + helpers.
; To hook this into your existing tool, replace the indicated stubs:
;   - AL_PickRegionDrag()      (Layer 1)
;   - AL_Capture_RectToBMP()   (Layer 1/4/5)
;   - AL_Capture_ReadPixelGrid() (Layer 2/3/4/5)
;   - AL_ClickCenterRect()     (Layer 5 - click test)
; and (optionally) persist settings to your INI store.
;
; I/O design:
;   Layer1 -> ParentContext
;   Layer2 -> Candidates[]
;   Layer3 -> Filtered[]
;   Layer4 -> ElementModel
;   Layer5 -> BehaviorSignature
;
; Suggested usage:
;   parent := AL_L1_ManualParentPick(store)
;   cands  := AL_L2_Segment(parent, opts)
;   filt   := AL_L3_Filter(parent, cands, opts)
;   model  := AL_L4_Extract(parent, filt, store, opts)
;   beh    := AL_L5_LearnBehavior(parent, model, store, opts)
;
; ============================================================

; ----------------------------
; Types
; ----------------------------
class Rect {
    __New(L := 0, T := 0, R := 0, B := 0) {
        this.L := L
        this.T := T
        this.R := R
        this.B := B
    }
    W => (this.R - this.L)
    H => (this.B - this.T)
    CenterX => (this.L + this.W//2)
    CenterY => (this.T + this.H//2)
    ToString() => Format("L{} T{} R{} B{} ({}x{})", this.L, this.T, this.R, this.B, this.W, this.H)
}
__RectClass := Rect  ; stable handle to Rect class (avoid accidental shadowing)



class ParentContext {
    __New(rectScreen, bmpPath := "", meta := 0) {
        this.rect := rectScreen          ; Rect screen coords
        this.bmpPath := bmpPath          ; optional: screenshot path
        this.meta := IsObject(meta) ? meta : Map()
    }
}


class Candidate {
    __New(rectRel, score := 0.0, stats := 0) {
        this.rectRel := rectRel          ; Rect relative to parent
        this.score := score
        this.stats := IsObject(stats) ? stats : Map()
    }
}


class ElementModel {
    __New(id, normRectRel, templatePath := "", anchors := 0, meta := 0) {
        this.id := id
        this.normRect := normRectRel     ; Rect relative to parent (expected size)
        this.templatePath := templatePath
        this.anchors := IsObject(anchors) ? anchors : []
        this.meta := IsObject(meta) ? meta : Map()
    }
}


class BehaviorSignature {
    __New(deltaPctMin := 0.03, borderDeltaMin := 0.015, lumaShiftDir := "any", settleDelayMs := 120, valid := true, meta := 0) {
        this.deltaPctMin := deltaPctMin          ; min % pixels changed in ROI
        this.borderDeltaMin := borderDeltaMin    ; min % changed mainly in border ring
        this.lumaShiftDir := lumaShiftDir        ; "up" | "down" | "any"
        this.settleDelayMs := settleDelayMs
        this.valid := valid
        this.meta := IsObject(meta) ? meta : Map()
    }
}



; --- GDI+ lib compat layer (AHKv2) ---
; Some common libs expose Gdip_Startup()/Gdip_Shutdown(). Provide wrappers for compatibility.



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
