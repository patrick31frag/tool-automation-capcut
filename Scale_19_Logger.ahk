; ==================================================================================================
;  MODULE 19 — Logger
;  Source lines (original scale.ahk): 8771 – 9279
; ==================================================================================================
AL_FindDiamondOutlineBright(scanReg, winRect, &outX, &outY, pad := 0, brightThr := 210) {
    ; Fallback detector for DIAMOND as a thin outline (not a solid blob)
    ; - Counts "bright" pixels (R,G,B >= brightThr)
    ; - Requires low bright ratio (mostly dark background)
    ; - Requires 4 midpoints (top/bottom/left/right) to be bright -> diamond signature
    outX := ""
    outY := ""

    if (!IsObject(scanReg) || !IsObject(winRect))
        return false

    reg := scanReg
    if (pad > 0) {
        try {
            reg := InflateRegion(reg, pad)
        } catch {
        }
    }
    reg := ClipRegionToWin(reg, winRect)

    try {
        ; Diamond is a thin outline -> avoid over-downsampling
        grid := AL_Capture_ReadPixelGrid(reg, 2)
    } catch as e {
        try {
            LogWarn("AL diamond capture fail err=" e.Message, "ALDIA")
        } catch {
        }
        return false
    }

    if (!IsObject(grid) || !grid.Has("rgb"))
        return false

    wCells := grid["wCells"]
    hCells := grid["hCells"]
    stride := grid["stride"]
    rgb := grid["rgb"]

    total := wCells * hCells
    if (total <= 0)
        return false

    brightCount := 0
    minX := 999999
    minY := 999999
    maxX := -1
    maxY := -1

    Loop hCells {
        y := A_Index - 1
        Loop wCells {
            x := A_Index - 1
            idx := y*wCells + x + 1
            col := 0
            try {
                col := rgb[idx]
            } catch {
                col := 0
            }
            isBright := AL__IsBrightRGB(col, brightThr)
            if (isBright)
                brightCount += 1
            if (isBright && x < minX)
                minX := x
            if (isBright && x > maxX)
                maxX := x
            if (isBright && y < minY)
                minY := y
            if (isBright && y > maxY)
                maxY := y
        }
    }

    ratio := brightCount / total

    ; bbox size (cells -> px) for logging/guard
    bboxWc := (maxX >= 0) ? (maxX - minX + 1) : 0
    bboxHc := (maxY >= 0) ? (maxY - minY + 1) : 0
    bboxWp := bboxWc * stride
    bboxHp := bboxHc * stride

    try {
        Log("AL diamond bright=" brightCount " ratio=" Round(ratio, 3) " width=" bboxWp " height=" bboxHp
            " reg=(" reg["L"] "," reg["T"] "," reg["R"] "," reg["B"] ")", "DEBUG", "ALDIA")
    } catch {
    }

    ; Rule: outline should have enough bright pixels, but still mostly dark
    if (brightCount <= 40)
        return false
    if (ratio >= 0.40)
        return false

    ; mild geometry guard: avoid ultra-thin or gigantic blobs
    if (bboxWc < 4 || bboxHc < 4)
        return false

    ar := bboxWp / Max(1, bboxHp)
    if (ar < 0.35 || ar > 2.85)
        return false

    xMid := (minX + maxX) // 2
    yMid := (minY + maxY) // 2

    okTop := AL__HasBrightNear(rgb, wCells, hCells, xMid, minY, brightThr, 1)
    okBot := AL__HasBrightNear(rgb, wCells, hCells, xMid, maxY, brightThr, 1)
    okLeft := AL__HasBrightNear(rgb, wCells, hCells, minX, yMid, brightThr, 1)
    okRight := AL__HasBrightNear(rgb, wCells, hCells, maxX, yMid, brightThr, 1)

    try {
        Log("AL diamond mids top=" (okTop?1:0) " bot=" (okBot?1:0) " left=" (okLeft?1:0) " right=" (okRight?1:0)
            " bboxCells=(" minX "," minY ")-(" maxX "," maxY ")", "DEBUG", "ALDIA")
    } catch {
    }

    if !(okTop && okBot && okLeft && okRight)
        return false

    ; Convert cell-midpoint to screen coords (sample center)
    outX := reg["L"] + Min((reg["R"] - reg["L"]) - 1, xMid*stride + Floor(stride/2))
    outY := reg["T"] + Min((reg["B"] - reg["T"]) - 1, yMid*stride + Floor(stride/2))
    return true
}


; =========================================================
; Region picker (drag with left mouse)
; =========================================================
PickAndSaveRegion(sectionName, title, &ok) {
    global CFG_FILE
    global runnerL, runnerT, runnerR, runnerB
    global scaleRunL, scaleRunT, scaleRunR, scaleRunB

    ok := false
    SetStatus(title "  (Hold Left Mouse, drag, release. ESC=cancel)")

    pick0 := PickRegionDrag()
    if !IsObject(pick0) {
        SetStatus(title " (cancel: nonmap)")
        return
    }

    if (Type(pick0) != "Map") {
        SetStatus(title " (cancel: nonmap)")
        return
    }

    if (!pick0.Has("ok")) {
        SetStatus(title " (cancel: missing-ok)")
        return
    }

    if (!pick0["ok"]) {
        reason := pick0.Has("reason") ? pick0["reason"] : "unknown"
        SetStatus(title " (cancel: " reason ")")
        return
    }

    if (!pick0.Has("L") || !pick0.Has("T") || !pick0.Has("R") || !pick0.Has("B")) {
        SetStatus(title " (cancel: bad-data)")
        return
    }

    L := pick0["L"]
    T := pick0["T"]
    R := pick0["R"]
    B := pick0["B"]
    if (R <= L || B <= T)
        return

    IniWriteSafe(L, CFG_FILE, sectionName, "L")
    IniWriteSafe(T, CFG_FILE, sectionName, "T")
    IniWriteSafe(R, CFG_FILE, sectionName, "R")
    IniWriteSafe(B, CFG_FILE, sectionName, "B")

    if (sectionName = "runner") {
        runnerL := L
        runnerT := T
        runnerR := R
        runnerB := B
    } else {
        scaleRunL := L
        scaleRunT := T
        scaleRunR := R
        scaleRunB := B
    }

    ok := true
}


IsLDown() {
    return GetKeyState("LButton", "P") || GetKeyState("LButton")
}


; Get physical screen cursor position (robust under DPI virtualization).
; Fallbacks to MouseGetPos if API is unavailable.
GetCursorScreen(&x, &y) {
    pt := Buffer(8, 0)
    try {
        if SC_DllCall("user32.dll\GetPhysicalCursorPos", "ptr", pt, "int") {
            x := NumGet(pt, 0, "int")
            y := NumGet(pt, 4, "int")
            return true
        }
    } catch {
    }
    try {
        if SC_DllCall("user32.dll\GetCursorPos", "ptr", pt, "int") {
            x := NumGet(pt, 0, "int")
            y := NumGet(pt, 4, "int")
            return true
        }
    } catch {
    }
    try {
        MouseGetPos(&x, &y)
    } catch {
        x := 0
        y := 0
    }
    return true
}
PickRegionDrag(requireDrag := false) {
    
    global __UI_IS_TESTING
    __ENTRY_Log("PickRegionDrag", "IsTesting=" __UI_IS_TESTING " requireDrag=" (requireDrag ? 1 : 0))
    if (__UI_IS_TESTING) {
        Log("PICK IGNORE: UI test lock active", "DEBUG", "PICK")
        return Map("ok", false, "reason", "testlock")
    }
hwndRoot := 0
    hwndRaw := 0

    global DBG_PICK_WAIT_TOOLTIP
    success := false
    try {
        HideBorder()
        Log("BEGIN PICK", "DEBUG", "PICK")
        res := ""

        ; PRO FIX: Use KeyWait to avoid missing state transitions.
        ; Normalize state: if LButton is already held, wait for release briefly.
        if GetKeyState("LButton", "P") {
            if !KeyWait("LButton", "T1.5") {
                Log("PICK FAIL reason=timeout", "DEBUG", "PICK")
                return Map("ok", false, "reason", "timeout")
            }
            Sleep 30
        }

        if (DBG_PICK_WAIT_TOOLTIP)
            ToolTip("drag with LButton... (ESC=cancel)")

        ; Wait for a NEW press
        Loop {
            if GetKeyState("Escape", "P") {
                Log("PICK FAIL reason=escape", "DEBUG", "PICK")
                return Map("ok", false, "reason", "escape")
            }
            if KeyWait("LButton", "D T0.25") {
                Sleep 15
                break
            }
        }

        if (DBG_PICK_WAIT_TOOLTIP)
            ToolTip()

        Sleep 30
        GetCursorScreen(&x1, &y1)
        ; Capture HWND under initial point (root window) for HWND-mode capture
        try {
            MouseGetPos(, , &hwndRaw)
            if (hwndRaw) {
                hwndRoot := DllCall("user32.dll\GetAncestor", "ptr", hwndRaw, "uint", 2, "ptr")
                if (!hwndRoot)
                    hwndRoot := hwndRaw
            }
        } catch {
            hwndRoot := 0
        }

        if (!IsNum(x1) || !IsNum(y1)) {
            Log("PICK FAIL reason=invalid", "DEBUG", "PICK")
            return Map("ok", false, "reason", "invalid")
        }

        ; Realtime border while dragging (smooth + no focus + click-through)
        x2 := x1
        y2 := y1
        UpdateBorderRect(x1, y1, x2, y2)
        dragged := false
        drawNext := 0
        while GetKeyState("LButton", "P") {
            if GetKeyState("Escape", "P") {
                Log("PICK FAIL reason=escape", "DEBUG", "PICK")
                return Map("ok", false, "reason", "escape")
            }
            GetCursorScreen(&x2, &y2)
            if (!dragged && (Abs(x2 - x1) > 3 || Abs(y2 - y1) > 3))
                dragged := true
            if (A_TickCount >= drawNext) {
                UpdateBorderRect(x1, y1, x2, y2)
                drawNext := A_TickCount + 33
            }
            Sleep 1
        }
        ; final draw
        UpdateBorderRect(x1, y1, x2, y2)
        GetCursorScreen(&x2, &y2)

        if (requireDrag && !dragged) {
            Log("PICK FAIL reason=nodrag", "DEBUG", "PICK")
            return Map("ok", false, "reason", "nodrag")
        }

        ; Never return a Map without L/T/R/B (click-only still yields a region)
        minSz := 5
        if (!IsNum(x2) || !IsNum(y2)) {
            L := x1
            T := y1
            R := x1 + minSz
            B := y1 + minSz
            Log("PICK OK L=" L " T=" T " R=" R " B=" B, "DEBUG", "PICK")
            success := true
            return Map("ok", true, "L", L, "T", T, "R", R, "B", B, "hwnd", hwndRoot)
        }

        L := Min(x1, x2)
        T := Min(y1, y2)
        R := Max(x1, x2)
        B := Max(y1, y2)

        if (Abs(R - L) < minSz)
            R := L + minSz
        if (Abs(B - T) < minSz)
            B := T + minSz

        ; Clamp to screen bounds (CoordMode Screen) WITHOUT collapsing min size.
        sw := A_ScreenWidth
        sh := A_ScreenHeight

        if (R > sw - 1) {
            dx := R - (sw - 1)
            L -= dx
            R := sw - 1
        }

        if (L < 0) {
            dx := -L
            L := 0
            R += dx
        }

        if (B > sh - 1) {
            dy := B - (sh - 1)
            T -= dy
            B := sh - 1
        }

        if (T < 0) {
            dy := -T
            T := 0
            B += dy
        }

        if (R - L < minSz) {
            if (L + minSz <= sw - 1) {
                R := L + minSz
            } else {
                R := sw - 1
                L := Max(0, R - minSz)
            }
        }

        if (B - T < minSz) {
            if (T + minSz <= sh - 1) {
                B := T + minSz
            } else {
                B := sh - 1
                T := Max(0, B - minSz)
            }
        }

        res := Map("ok", true, "L", L, "T", T, "R", R, "B", B, "hwnd", hwndRoot)

        if (Type(res) = "Map") {
            Log("PICK OK L=" L " T=" T " R=" R " B=" B, "DEBUG", "PICK")
            success := true
            return res
        }

        ; ===== ABSOLUTE FALLTHROUGH GUARD =====
        Log("PICK FAIL reason=fallthrough", "DEBUG", "PICK")
        return Map("ok", false, "reason", "fallthrough")
    } catch as e {
        try {
            LogWarn("PickRegionDrag exception err=" e.Message, "PICK")
        } catch {
        }
        return Map("ok", false, "reason", "exception")
    } finally {
        ; Always clear tooltip and hide border overlay.
        ; NOTE: DXGI captures desktop composition, so leaving the overlay visible
        ; can contaminate subsequent captures (black/overlay-only images).
        if (DBG_PICK_WAIT_TOOLTIP) {
            try {
                ToolTip()
            } catch {
            }
        }
        try {
            HideBorder()
        } catch {
        }
        try {
            Log("END PICK ok=" (success ? 1 : 0), "DEBUG", "PICK")
        } catch {
        }
    }
}


ShowBorderInit() {
    global borderG
    if (borderG.Has("top"))
        return
    borderG["top"] := MakeLineGui()
    borderG["left"] := MakeLineGui()
    borderG["right"] := MakeLineGui()
    borderG["bottom"] := MakeLineGui()
}


HideBorder() {
    global borderG, F3_GUI_SHOW_BORDERS, __BORDER_LAST_TICK
    if (F3_GUI_SHOW_BORDERS) {
        try {
            Log("HideBorder skipped: F3_GUI_SHOW_BORDERS=1", "DEBUG", "BORDER")
        } catch {
        }
        return
    }
    if (IsSet(__BORDER_LAST_TICK) && (A_TickCount - __BORDER_LAST_TICK < 150)) {
        try {
            Log("HideBorder skipped: recent draw tickDelta=" (A_TickCount - __BORDER_LAST_TICK), "DEBUG", "BORDER")
        } catch {
        }
        return
    }
    for _, gg in borderG {
        try {
            gg.Hide()
        } catch {
        }
    }
}

Border_ClearLinesForce(reason := "") {
    global borderG, BORDER_SETS, gBorderShowAll
    ; Hide single-set borders (parent/preview)
    try {
        ShowBorderInit()
    } catch {
    }
    if (IsObject(borderG)) {
        for _, gg in borderG {
            try {
                gg.Hide()
            } catch {
            }
        }
    }
    ; Hide all multi-ROI border sets (ALL ROI)
    if (IsObject(BORDER_SETS)) {
        for _, set in BORDER_SETS {
            if (!IsObject(set))
                continue
            for _, gg in set {
                try {
                    gg.Hide()
                } catch {
                }
            }
        }
    }
    ; Hide ROI index labels
    try {
        Border_HideAllLabels()
    } catch {
    }
    ; Keep OrderInput while ALL-ROI mode is ON; destroy only when leaving mode
    ; NOTE: ClearLinesForce chỉ clear vẽ, KHÔNG destroy OrderInput (chỉ destroy khi Toggle OFF thật sự)
    try {
        if (reason != "")
            Log("BORDER ClearLinesForce reason=" reason, "DEBUG", "BORDER")
        else
            Log("BORDER ClearLinesForce", "DEBUG", "BORDER")
    } catch {
    }
}


; ===============================
; ROI index labels (for ALL ROI Show Borders)
; Each ROI gets its own tiny click-through GUI with transparent background.
