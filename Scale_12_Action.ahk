; ==================================================================================================
;  MODULE 12 — Action
;  Source lines (original scale.ahk): 5388 – 5873
; ==================================================================================================


MakeCachedRegion(last, fullRegion, box) {
    cx := last["x"]
    cy := last["y"]
    if (!IsNum(cx) || !IsNum(cy))
        return fullRegion

    cx := Integer(Number(cx))
    cy := Integer(Number(cy))
    L := fullRegion["L"]
    T := fullRegion["T"]
    R := fullRegion["R"]
    B := fullRegion["B"]

    l2 := Max(L, cx - box)
    t2 := Max(T, cy - box)
    r2 := Min(R, cx + box)
    b2 := Min(B, cy + box)

    if (r2 <= l2 || b2 <= t2)
        return fullRegion

    return Map("L", l2, "T", t2, "R", r2, "B", b2)
}

; -------------------------
; LOGIC / WORKFLOW / UI
; -------------------------




; =========================================================
; ScaleCycle - AHK v2 ONLY (NO v1)
;
; FIXES ADDED (the missing items you asked for):
;  - State-aware preflight (optional target exe/title)
;  - Cache invalidation on window move/resize/hwnd change
;  - Jittered retry (random sleep) to avoid animation frame lock
;  - L-anchor pack (H/V sets) + cluster, with majority thresholds
;  - Optional relative offset scaling by window size (simple normalize)
;  - Clip search regions to active window (hierarchy-ish coarse gate)
;
; Existing:
;  - Priority: pick match that appears first (top-most then left-most)
;  - F2 Scan toggles beside Diamond/Scale to set [runner]/[scale_runner]
;  - Cache region (small) -> full region fallback
;
; Hotkeys:
;   F1 = Toggle RUN/STOP
;   F2 = Scan Region (if enabled) OR Run once
; =========================================================

; ================= PATCH NOTES =================
; - Removed legacy AL_GdipGetEncoderClsid() implementation.
; - Added dynamic ImageCodecInfo-based encoder lookup (GDI+ safe).
; - Updated ShortName() to use StrSplit(p, "\") for correct basename handling.
; - Fixed mojibake string: "RUNNING (mojibake)" -> "RUNNING...".
; - Removed all Vietnamese text from this script.
; ==============================================


; =========================
; CORE (LOW-LEVEL) - MUST STAY ABOVE ALL LOGIC/UI
; =========================
; =========================================================
; ImageSearch helper
; =========================================================
ImageSearchOne(img, L, T, R, B, &x, &y) {
    global tolerance
    x := ""
    y := ""
    tol := ToIntSafe(tolerance, 40)
    if (tol < 0)
        tol := 0

    loop 2 {
        curTol := tol + (A_Index - 1) * 10
        opt := "*" curTol " " img
        try {
            ImageSearch(&x, &y, L, T, R, B, opt)
            if IsNum(x) && IsNum(y) {
                x := Integer(Number(x))
                y := Integer(Number(y))
                return true
            }
        } catch {
        }
    }
    x := ""
    y := ""
    return false
}


; =========================================================
; Mouse helpers
; =========================================================
MoveCursor(x, y) {
    xi := Integer(Number(x))
    yi := Integer(Number(y))
    SC_DllCall("user32.dll\SetCursorPos", "int", xi, "int", yi)
}


MouseClickLeft(count := 1) {
    global __DBG_CLICKPOLICY, __UI_IS_TESTING
    if (__DBG_CLICKPOLICY) {
        try {
            mx := 0
            my := 0
            MouseGetPos(&mx, &my)
            __DECIDE_Log("MouseClickLeft", "count=" count " isTesting=" __UI_IS_TESTING " mouse=" mx "," my)
        } catch {
        }
    }

    global __DBG_CLICKPOLICY, __UI_IS_TESTING
    if (__DBG_CLICKPOLICY) {
        try {
            MouseGetPos(&mx, &my)
            Log("CLICK_SEND | count=" count " x=" mx " y=" my " isTesting=" __UI_IS_TESTING, "DEBUG", "CLICK")
        } catch {
        }
    }
    ; Use Send-based click (mouse_event is deprecated but still supported).
    if (count <= 1) {
        Send "{Click}"
    } else {
        Send "{Click " count "}"
    }
    Sleep(25)
}


LearnAnchorPack(x, y, &packOut) {
    packOut := MakeEmptyAnchorPack()

    ; Cluster (anti-alias tolerant)
    pts := [[2,2], [10,2], [2,10], [10,10], [6,6]]
    for _, p in pts {
        dx := p[1]
        dy := p[2]
        col := ""
        try {
            col := PixelGetColor(x + dx, y + dy, "RGB")
        } catch {
            continue
        }
        packOut["cluster"].Push(Map("dx", dx, "dy", dy, "col", col))
    }

    ; L-anchors:
    ; Horizontal line sample (more sensitive to Y)
    hpts := [[4,2], [10,2], [16,2]]
    for _, p in hpts {
        dx := p[1]
        dy := p[2]
        col := ""
        try {
            col := PixelGetColor(x + dx, y + dy, "RGB")
        } catch {
            continue
        }
        packOut["h"].Push(Map("dx", dx, "dy", dy, "col", col))
    }

    ; Vertical line sample (more sensitive to X)
    vpts := [[2,4], [2,10], [2,16]]
    for _, p in vpts {
        dx := p[1]
        dy := p[2]
        col := ""
        try {
            col := PixelGetColor(x + dx, y + dy, "RGB")
        } catch {
            continue
        }
        packOut["v"].Push(Map("dx", dx, "dy", dy, "col", col))
    }
}


VerifyAnchorPack(x, y, pack, thr, needCluster, needH, needV) {
    ; Cluster majority
    if (pack["cluster"].Length > 0) {
        if (CountAnchorHits(x, y, pack["cluster"], thr) < needCluster)
            return false
    }
    ; H / V majority (L lock)
    if (pack["h"].Length > 0) {
        if (CountAnchorHits(x, y, pack["h"], thr) < needH)
            return false
    }

    if (pack["v"].Length > 0) {
        if (CountAnchorHits(x, y, pack["v"], thr) < needV)
            return false
    }
    return true
}


RefineByLAxes(&x, &y, pack, thr) {
    ; refine X using vertical anchors (lock X)
    if (pack["v"].Length > 0) {
        best := -1
        bestX := x
        for ox in [-3,-2,-1,0,1,2,3] {
            h := CountAnchorHits(x + ox, y, pack["v"], thr)
            if (h > best) {
                best := h
                bestX := x + ox
            }
        }
        x := bestX
    }
    ; refine Y using horizontal anchors (lock Y)
    if (pack["h"].Length > 0) {
        best := -1
        bestY := y
        for oy in [-3,-2,-1,0,1,2,3] {
            h := CountAnchorHits(x, y + oy, pack["h"], thr)
            if (h > best) {
                best := h
                bestY := y + oy
            }
        }
        y := bestY
    }
}


ColorNear(c1, c0, thr) {
    r1 := (c1 >> 16) & 255
    g1 := (c1 >> 8) & 255
    b1 := c1 & 255
    r0 := (c0 >> 16) & 255
    g0 := (c0 >> 8) & 255
    b0 := c0 & 255
    return (Abs(r1 - r0) <= thr && Abs(g1 - g0) <= thr && Abs(b1 - b0) <= thr)
}


; =========================================================
; INI - Image lists
; =========================================================
LoadImageListsFromIni() {
    global DIA_LIST, SCA_LIST, CFG_FILE, diaSel, scaSel
    DIA_LIST := []
    SCA_LIST := []

    diaCnt := ToIntSafe(IniReadSafe(CFG_FILE, "diamond_images", "count", "0"), 0)
    diaSel := ToIntSafe(IniReadSafe(CFG_FILE, "diamond_images", "selected", "1"), 1)
    if (diaCnt < 0)
        diaCnt := 0
    loop diaCnt {
        i := A_Index
        sec := "diamond_" i
        p := Trim(IniReadSafe(CFG_FILE, sec, "path", ""))
        if (p != "")
            DIA_LIST.Push(p)
    }

    if (diaSel < 1 || diaSel > DIA_LIST.Length)
        diaSel := 1

    scaCnt := ToIntSafe(IniReadSafe(CFG_FILE, "scale_images", "count", "0"), 0)
    scaSel := ToIntSafe(IniReadSafe(CFG_FILE, "scale_images", "selected", "1"), 1)
    if (scaCnt < 0)
        scaCnt := 0
    loop scaCnt {
        i := A_Index
        sec := "scale_" i
        p := Trim(IniReadSafe(CFG_FILE, sec, "path", ""))
        if (p != "")
            SCA_LIST.Push(p)
    }

    if (scaSel < 1 || scaSel > SCA_LIST.Length)
        scaSel := 1
}


; =========================================================
; INI: scans
; =========================================================
LoadScansFromIni() {
    global SCANS, CFG_FILE, maxScanKeep
    SCANS := []
    cnt := ToIntSafe(IniReadSafe(CFG_FILE, "scans", "count", "0"), 0)
    if (cnt < 0)
        cnt := 0
    loop cnt {
        i := A_Index
        sec := "scan_" i
        dL := IniReadSafe(CFG_FILE, sec, "diamondL", "")
        sL := IniReadSafe(CFG_FILE, sec, "scaleL", "")
        if (Trim(dL) = "" && Trim(sL) = "")
            continue
        rec := Map()
        rec["diaL"] := dL
        rec["diaT"] := IniReadSafe(CFG_FILE, sec, "diamondT", "")
        rec["diaR"] := IniReadSafe(CFG_FILE, sec, "diamondR", "")
        rec["diaB"] := IniReadSafe(CFG_FILE, sec, "diamondB", "")
        rec["scaL"] := sL
        rec["scaT"] := IniReadSafe(CFG_FILE, sec, "scaleT", "")
        rec["scaR"] := IniReadSafe(CFG_FILE, sec, "scaleR", "")
        rec["scaB"] := IniReadSafe(CFG_FILE, sec, "scaleB", "")
        rec["time"] := IniReadSafe(CFG_FILE, sec, "time", "")
        SCANS.Push(rec)
    }
    ; Cap scans loaded from INI
    if (maxScanKeep < 1)
        maxScanKeep := 1
    while (SCANS.Length > maxScanKeep)
        SCANS.Pop()
}



SaveScansToIni() {
    global SCANS, CFG_FILE
    IniWriteSafe(SCANS.Length, CFG_FILE, "scans", "count")

    prev := ToIntSafe(IniReadSafe(CFG_FILE, "scans", "max", "0"), 0)
    if (prev < SCANS.Length)
        prev := SCANS.Length
    IniWriteSafe(prev, CFG_FILE, "scans", "max")

    loop prev {
        i := A_Index
        sec := "scan_" i
        if (i <= SCANS.Length) {
            rec := SCANS[i]
            IniWriteSafe(rec["diaL"], CFG_FILE, sec, "diamondL")
            IniWriteSafe(rec["diaT"], CFG_FILE, sec, "diamondT")
            IniWriteSafe(rec["diaR"], CFG_FILE, sec, "diamondR")
            IniWriteSafe(rec["diaB"], CFG_FILE, sec, "diamondB")
            IniWriteSafe(rec["scaL"], CFG_FILE, sec, "scaleL")
            IniWriteSafe(rec["scaT"], CFG_FILE, sec, "scaleT")
            IniWriteSafe(rec["scaR"], CFG_FILE, sec, "scaleR")
            IniWriteSafe(rec["scaB"], CFG_FILE, sec, "scaleB")
            IniWriteSafe(rec["time"], CFG_FILE, sec, "time")
        } else {
            IniWriteSafe("", CFG_FILE, sec, "diamondL")
            IniWriteSafe("", CFG_FILE, sec, "diamondT")
            IniWriteSafe("", CFG_FILE, sec, "diamondR")
            IniWriteSafe("", CFG_FILE, sec, "diamondB")
            IniWriteSafe("", CFG_FILE, sec, "scaleL")
            IniWriteSafe("", CFG_FILE, sec, "scaleT")
            IniWriteSafe("", CFG_FILE, sec, "scaleR")
            IniWriteSafe("", CFG_FILE, sec, "scaleB")
            IniWriteSafe("", CFG_FILE, sec, "time")
        }
    }
}


SetModeCombos() {
    global cbDiaMode, cbScaMode, diamondClickMode, scaleClickMode
    try {
        cbDiaMode.Choose(diamondClickMode = 2 ? 2 : 1)
    } catch {
    }
    try {
        cbScaMode.Choose(scaleClickMode = 2 ? 2 : 1)
    } catch {
    }
}


SyncScanChecks() {
    global chkDiaScan, chkScaScan, f2ScanDia, f2ScanSca
    chkDiaScan.Value := f2ScanDia ? 1 : 0
    chkScaScan.Value := f2ScanSca ? 1 : 0
}


DiaOnChange(*) {
    global cbDia, diaSel, DIA_LIST
    v := SafeCtrlValue(cbDia)
    if (v >= 1 && v <= DIA_LIST.Length) {
        diaSel := v
        SaveImageListsToIni()
        SetStatus("Diamond selected #" diaSel)
    }
}


ScaOnChange(*) {
    global cbSca, scaSel, SCA_LIST
    v := SafeCtrlValue(cbSca)
    if (v >= 1 && v <= SCA_LIST.Length) {
        scaSel := v
        SaveImageListsToIni()
        SetStatus("Scale selected #" scaSel)
    }
}


DiaModeOnChange(*) {
    global cbDiaMode, diamondClickMode, CFG_FILE
    v := SafeCtrlValue(cbDiaMode)
    diamondClickMode := (v = 2) ? 2 : 1
    IniWriteSafe(diamondClickMode, CFG_FILE, "clickmodes", "diamond")
    SetStatus("Diamond mode: " (diamondClickMode=2 ? "Double" : "Click"))
}


ScaModeOnChange(*) {
    global cbScaMode, scaleClickMode, CFG_FILE
    v := SafeCtrlValue(cbScaMode)
    scaleClickMode := (v = 2) ? 2 : 1
    IniWriteSafe(scaleClickMode, CFG_FILE, "clickmodes", "scale")
    SetStatus("Scale mode: " (scaleClickMode=2 ? "Double" : "Click"))
}

; =========================================================
; F3 ROI ORDERING (GUI) + CLICK SEQUENCE
; =========================================================
SetF3OrderCombo() {
    global cbF3Order, F3_SORT_MODE
    try {
        ; Map sort mode -> ComboBox index
        idx := 1
        switch F3_SORT_MODE {
            case "LTR":   idx := 1
            case "RTL":   idx := 2
            case "TTB":   idx := 3
            case "BTT":   idx := 4
            case "SCORE": idx := 5
            case "AREA":  idx := 6
        }
        cbF3Order.Choose(idx)
    } catch {
    }
}

F3OrderOnChange(*) {
    global cbF3Order, F3_SORT_MODE, CFG_FILE
    v := SafeCtrlValue(cbF3Order)
    mode := "LTR"
    switch v {
        case 1: mode := "LTR"
        case 2: mode := "RTL"
        case 3: mode := "TTB"
        case 4: mode := "BTT"
        case 5: mode := "SCORE"
        case 6: mode := "AREA"
        default: mode := "LTR"
    }

    F3_SORT_MODE := mode
    try {
; ---------------- AI_SAFEZONE100:ROI_UI_MODULE_BEGIN -----------------
; ROI list / F3 GUI / overlay ordering. Keep state checks before actions.
; ---------------------------------------------------------------------
        IniWriteSafe(F3_SORT_MODE, CFG_FILE, "f3roi", "sort")
    } catch {
    }

    F3__ResortExisting()
    SetStatus("F3 ROI order: " F3_SORT_MODE)
}

F3RoiOnChange(*) {
    global cbF3Rois, F3_ROI_SELECTED, F3_ROI_LIST, cbF3RoiMode
    idx := SafeCtrlValue(cbF3Rois)
    if (idx < 1)
        idx := 1
    if (IsObject(F3_ROI_LIST) && idx > F3_ROI_LIST.Length)
        idx := F3_ROI_LIST.Length
    if (idx < 1)
        idx := 1
    F3_ROI_SELECTED := idx

    try {
        if (IsObject(F3_ROI_LIST) && F3_ROI_LIST.Length >= idx) {
            cbF3RoiMode.Choose(F3_ROI_LIST[idx]["mode"] = 2 ? 2 : 1)
        }
    } catch {
    }
}

