; ==================================================================================================
; RECT MODULE
; --------------------------------------------------------------------------------------------------
; Rect class, SC_RectUnpack, SC_RectUnpack_SAFE, SC_IsRectLike, clamp helpers, geometry utilities
; ==================================================================================================

; -------- Rect class --------
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


; -------- Rect unpack helpers --------
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

; -------- Helper functions --------
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

AL_ArrGet(arr, idx, default := 0) {
    if !IsObject(arr)
        return default
    if (idx < 1)
        return default

    len := 0
    try {
        len := arr.Length
    } catch {
        len := 0
    }

    if (len > 0 && idx > len)
        return default

    v := default
    try {
        v := arr[idx]
    } catch {
        v := default
    }
    return v
}


; ============================================================
; Helpers (geometry, anchors, diff)
; ============================================================
AL_RelToScreen(parentRect, relRect) {
    ; Khuyên nhủ (tránh crop bị cụt mép):
    ; rectRel thường theo kiểu inclusive (R/B là pixel cuối). Khi đổi sang screenRect để capture/crop,
    ; cộng +1 cho R/B để bao trọn icon, rồi tiếp tục áp pad + clamp ở bước capture.
    return Rect(parentRect.L + relRect.L
              , parentRect.T + relRect.T
              , parentRect.L + relRect.R + 1
              , parentRect.T + relRect.B + 1)
}

AL_ExpandRect(r, pad) {
    return Rect(r.L - pad, r.T - pad, r.R + pad, r.B + pad)
}

AL_Clamp(x, lo, hi) {
    if (x < lo)
        return lo
    if (x > hi)
        return hi
    return x
}


AL_IoU(r1, r2) {
    L := Max(r1.L, r2.L)
    T := Max(r1.T, r2.T)
    R := Min(r1.R, r2.R)
    B := Min(r1.B, r2.B)
    iw := R - L
    ih := B - T
    if (iw <= 0 || ih <= 0)
        return 0.0
    inter := iw * ih
    a1 := Max(0, (r1.R - r1.L)) * Max(0, (r1.B - r1.T))
    a2 := Max(0, (r2.R - r2.L)) * Max(0, (r2.B - r2.T))
    uni := a1 + a2 - inter
    return (uni > 0) ? (inter / uni) : 0.0
}

AL_RectInside(a, b, containThr := 0.92, areaFracMax := 0.45) {
    try {
        ; intersection
        l := (a.L > b.L) ? a.L : b.L
        t := (a.T > b.T) ? a.T : b.T
        r := (a.R < b.R) ? a.R : b.R
        btm := (a.B < b.B) ? a.B : b.B
        w := r - l
        h := btm - t
        if (w <= 0 || h <= 0)
            return false
        inter := w * h
        aw := a.R - a.L
        ah := a.B - a.T
        if (aw <= 0 || ah <= 0)
            return false
        aArea := aw * ah
        contain := inter / aArea
        if (contain < containThr)
            return false

        bw := b.R - b.L
        bh := b.B - b.T
        if (bw <= 0 || bh <= 0)
            return true
        bArea := bw * bh
        areaFrac := aArea / bArea
        return (areaFrac <= areaFracMax)
    } catch {
        return false
    }
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
    return AL_GdipBitmapFromScreenRect(rectAbs, cap)
}
