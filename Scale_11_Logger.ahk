; ==================================================================================================
;  MODULE 11 — Logger
;  Source lines (original scale.ahk): 4903 – 5387
; ==================================================================================================

    ; --- AHK v2 SYNTAX NOTES (giúp tránh lỗi cú pháp khi file dài) ---
    ; 1) Else-chain: ưu tiên viết `} else if (...) {` / `} else {` cùng 1 dòng để tránh "Unexpected Else" do auto-format.
    ; 2) Map không có thuộc tính .L/.T: phải dùng m["L"], m["T"], m["R"], m["B"].
    ; 3) Tham số tuỳ chọn: dùng IsSet(x2) / IsSet(y2) trước khi đọc.
    ; 4) try/catch: luôn dùng block-form `try { ... } catch { ... }`.
    ; 5) Vẽ border: skip nếu w/h < 2 để tránh vẽ 1 điểm (w=0 h=0) khi đang drag.
    ; ---------------------------------------------------------------

UpdateBorderRect(x1, y1, x2, y2) {
    global borderG, __BORDER_LAST_TICK, F3_GUI_SHOW_BORDERS, parentHwnd, gBorderShowAll

    ShowBorderInit()

; ---------------------------
; 1) Normalize input rect (AHK v2 safe blocks)
; ⚠ RULES (v2):
;   - else must be on same line as closing brace: "} else {"
;   - else never follows try/for/while
;   - to avoid "Unexpected Else" in long functions, prefer flat if-blocks
; ---------------------------
; Support:
;   - coords: (x1,y1,x2,y2)
;   - Map/Object: x1
L := 0, T := 0, R := 0, B := 0

if (IsObject(x1)) {
    rect := x1
    if (Type(rect) = "Map") {
        if (rect.Has("L") && rect.Has("T") && rect.Has("R") && rect.Has("B")) {
            L := rect["L"], T := rect["T"], R := rect["R"], B := rect["B"]
        }
        if ((L = 0 && T = 0 && R = 0 && B = 0) && rect.Has("X") && rect.Has("Y") && rect.Has("W") && rect.Has("H")) {
            L := rect["X"], T := rect["Y"]
            R := rect["X"] + rect["W"], B := rect["Y"] + rect["H"]
        }
    } else {
        _L := "", _T := "", _R := "", _B := ""
        try {
            _L := rect.L
        } catch {
        }
        if (_L = "") {
            try {
                _L := rect.Left
            } catch {
            }
        }
        try {
            _T := rect.T
        } catch {
        }
        if (_T = "") {
            try {
                _T := rect.Top
            } catch {
            }
        }
        try {
            _R := rect.R
        } catch {
        }
        if (_R = "") {
            try {
                _R := rect.Right
            } catch {
            }
        }
        try {
            _B := rect.B
        } catch {
        }
        if (_B = "") {
            try {
                _B := rect.Bottom
            } catch {
            }
        }
        if (_L != "" && _T != "" && _R != "" && _B != "") {
            L := _L, T := _T, R := _R, B := _B
        }
    }
}

; coords path (no else-chains)
if (!IsObject(x1) && IsSet(x2) && IsSet(y2)) {
    L := Min(x1, x2)
    T := Min(y1, y2)
    R := Max(x1, x2)
    B := Max(y1, y2)
}
if (!IsObject(x1) && (!IsSet(x2) || !IsSet(y2))) {
    ; Called with a point/incomplete -> allow logs but skip draw later via size check
    L := x1
    T := (IsSet(y1) ? y1 : 0)
    R := L
    B := T
}

    __BORDER_LAST_TICK := A_TickCount

    ; ---------------------------
    ; 2) SCREEN-COORD normalization (ClientToScreen / DPI)
    ;    - If rect already looks like screen coords (within window rect), keep it.
    ;    - Else treat it as client coords and convert via ClientToScreen(0,0).
    ; ---------------------------
    hwnd := 0
    try {
        if (IsSet(parentHwnd) && parentHwnd)
            hwnd := parentHwnd
    } catch {
        hwnd := 0
    }

    try {
        Log("SRC inRect=" L "," T "," R "," B " hwnd=" (hwnd ? Format("0x{:X}", hwnd+0) : "0x0"), "DEBUG", "BORDER")
    } catch {
    }

    dx := 0, dy := 0
    alreadyScreen := 0
    if (hwnd) {
        win := 0
        try {
            win := GetWinRect(hwnd)
        } catch {
            win := 0
        }
        if (IsObject(win)) {
            if (L >= win["L"] - 4 && T >= win["T"] - 4 && R <= win["R"] + 4 && B <= win["B"] + 4) {
                alreadyScreen := 1
            } else {
                pt := Buffer(8, 0)
                NumPut("int", 0, pt, 0)
                NumPut("int", 0, pt, 4)
                okCTS := 0
                try {
                    okCTS := DllCall("user32.dll\ClientToScreen", "ptr", hwnd, "ptr", pt, "int")
                } catch {
                    okCTS := 0
                }
                if (okCTS) {
                    dx := NumGet(pt, 0, "int")
                    dy := NumGet(pt, 4, "int")
                    L += dx, R += dx
                    T += dy, B += dy
                } else {
                    try {
                        Log("WARN ClientToScreen failed hwnd=" Format("0x{:X}", hwnd+0), "DEBUG", "BORDER")
                    } catch {
                    }
                }
            }
        } else {
            try {
                Log("WARN GetWinRect failed hwnd=" Format("0x{:X}", hwnd+0), "DEBUG", "BORDER")
            } catch {
            }
        }
    }

    sysDpi := 96
    winDpi := 96
    try {
        sysDpi := CAP_GetSystemDPI()
    } catch {
        sysDpi := (A_ScreenDPI > 0 ? A_ScreenDPI : 96)
    }
    try {
        winDpi := CAP_GetWindowDPI(hwnd, sysDpi)
    } catch {
        winDpi := sysDpi
    }

    try {
        Log("SCREEN outRect=" L "," T "," R "," B
            " alreadyScreen=" alreadyScreen
            " dx=" dx " dy=" dy
            " sysDpi=" sysDpi " winDpi=" winDpi, "DEBUG", "BORDER")
    } catch {
    }

    ; ---------------------------
    ; 3) Validate + WARNs
    ; ---------------------------
    wRaw := (R - L)
    hRaw := (B - T)
    if (wRaw < 2 || hRaw < 2) {
        try {
            Log("WARN invalid size (<2) w=" wRaw " h=" hRaw " rect=" L "," T "," R "," B, "DEBUG", "BORDER")
        } catch {
        }
        return
    }

    vx := 0, vy := 0, vw := 0, vh := 0
    try {
        CAP_GetVirtualDesktop(&vx, &vy, &vw, &vh)
    } catch {
        vx := 0, vy := 0, vw := A_ScreenWidth, vh := A_ScreenHeight
    }
    if (vw <= 0)
        vw := A_ScreenWidth
    if (vh <= 0)
        vh := A_ScreenHeight

    if (L < vx || T < vy || R > vx + vw || B > vy + vh) {
        try {
            Log("WARN outOfScreen rect=" L "," T "," R "," B
                " desktop=" vx "," vy "," (vx+vw) "," (vy+vh), "DEBUG", "BORDER")
        } catch {
        }
    }

    ; ---------------------------
    ; 4) Draw border
    ; ---------------------------
    w := wRaw
    h := hRaw
    th := 2

    ; Ensure visible (HideBorder() may have hidden them)
    try {
        borderG["top"].Show("NA")
        borderG["bottom"].Show("NA")
        borderG["left"].Show("NA")
        borderG["right"].Show("NA")
    } catch {
    }

    ; Move is smoother than repeated Show(x y w h) -> less flicker
    try {
        borderG["top"].Move(L, T, w, th)
        borderG["bottom"].Move(L, B - th, w, th)
        borderG["left"].Move(L, T, th, h)
        borderG["right"].Move(R - th, T, th, h)
        ; keep border lines above topmost UI
        try {
            Border_SetTopMost(borderG["top"].Hwnd)
        } catch {
        }
        try {
            Border_SetTopMost(borderG["bottom"].Hwnd)
        } catch {
        }
        try {
            Border_SetTopMost(borderG["left"].Hwnd)
        } catch {
        }
        try {
            Border_SetTopMost(borderG["right"].Hwnd)
        } catch {
        }
    } catch {
    }


    ; Keep OrderInputs synced with border redraw (ALL ROI mode)
    try {
        if (gBorderShowAll) {
            Border_DrawOrderInputsAll()
            Border_BringOrderInputsToTop()
        }
    } catch {
    }
}




GetWinRect(hwnd) {
    x := 0
    y := 0
    w := 0
    h := 0
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    } catch {
        return 0
    }
    return Map("L", x, "T", y, "R", x + w, "B", y + h, "W", w, "H", h)
}


Cleanup(*) {
    global borderG
    ; Destroy border overlay GUIs to avoid handle leaks on reload/exit.
    ; (Layer7) No UI calls here.
    try {
        for _, gg in borderG {
            try {
                gg.Destroy()
            } catch {
            }
        }
    } catch {
    }
}


; =========================================================
; Anchor Pack
; =========================================================
MakeEmptyAnchorPack() {
    p := Map()
    p["cluster"] := [] ; 5 points
    p["h"] := []       ; horizontal L
    p["v"] := []       ; vertical L
    return p
}


CountAnchorHits(x, y, anchors, thr) {
    hits := 0
    for _, a in anchors {
        dx := a["dx"]
        dy := a["dy"]
        c0 := a["col"]
        c1 := ""
        try {
            c1 := PixelGetColor(x + dx, y + dy, "RGB")
        } catch {
            continue
        }

        if (ColorNear(c1, c0, thr))
            hits += 1
    }
    return hits
}


SaveImageListsToIni() {
    global DIA_LIST, SCA_LIST, CFG_FILE, diaSel, scaSel

    IniWriteSafe(DIA_LIST.Length, CFG_FILE, "diamond_images", "count")
    IniWriteSafe(diaSel,          CFG_FILE, "diamond_images", "selected")

    prevDia := ToIntSafe(IniReadSafe(CFG_FILE, "diamond_images", "max", "0"), 0)
    if (prevDia < DIA_LIST.Length)
        prevDia := DIA_LIST.Length
    IniWriteSafe(prevDia, CFG_FILE, "diamond_images", "max")
    loop prevDia {
        i := A_Index
        sec := "diamond_" i
        if (i <= DIA_LIST.Length)
            IniWriteSafe(DIA_LIST[i], CFG_FILE, sec, "path")
        else
            IniWriteSafe("", CFG_FILE, sec, "path")
    }

    IniWriteSafe(SCA_LIST.Length, CFG_FILE, "scale_images", "count")
    IniWriteSafe(scaSel,          CFG_FILE, "scale_images", "selected")

    prevSca := ToIntSafe(IniReadSafe(CFG_FILE, "scale_images", "max", "0"), 0)
    if (prevSca < SCA_LIST.Length)
        prevSca := SCA_LIST.Length
    IniWriteSafe(prevSca, CFG_FILE, "scale_images", "max")
    loop prevSca {
        i := A_Index
        sec := "scale_" i
        if (i <= SCA_LIST.Length)
            IniWriteSafe(SCA_LIST[i], CFG_FILE, sec, "path")
        else
            IniWriteSafe("", CFG_FILE, sec, "path")
    }
}


; =========================================================
; GUI - Combos & click modes
; =========================================================
RefreshDiaCombo() {
    global cbDia, DIA_LIST, diaSel
    ClearComboItems(cbDia)
    items := []
    for idx, p in DIA_LIST
        items.Push(Format("{} | {}", idx, ShortName(p)))
    if (items.Length > 0) {
        cbDia.Add(items)
        if (diaSel < 1 || diaSel > items.Length)
            diaSel := 1
        try {
            cbDia.Choose(diaSel)
        } catch {
            try {
                cbDia.Text := items[diaSel]
            } catch {
            }
        }
    } else {
        try {
            cbDia.Text := ""
        } catch {
        }
    }
}


RefreshScaCombo() {
    global cbSca, SCA_LIST, scaSel
    ClearComboItems(cbSca)
    items := []
    for idx, p in SCA_LIST
        items.Push(Format("{} | {}", idx, ShortName(p)))
    if (items.Length > 0) {
        cbSca.Add(items)
        if (scaSel < 1 || scaSel > items.Length)
            scaSel := 1
        try {
            cbSca.Choose(scaSel)
        } catch {
            try {
                cbSca.Text := items[scaSel]
            } catch {
            }
        }
    } else {
        try {
            cbSca.Text := ""
        } catch {
        }
    }
}


; =========================================================
; Best match: priority top-most/left-most + jitter retry + anchor verify
; =========================================================
FindBestMatch(imgList, region, pack, &outX, &outY) {
    global anchorThr, anchorNeedCluster, anchorNeedH, anchorNeedV
    global retryMs, retryMinSleep, retryMaxSleep

    start := A_TickCount
    bestX := ""
    bestY := ""
    bestFound := false

    while (A_TickCount - start < retryMs) {
        bestFound := false
        bestX := ""
        bestY := ""

        for _, img in imgList {
            if (img = "" || !FileExist(img))
                continue

            if ImageSearchOne(img, region["L"], region["T"], region["R"], region["B"], &x, &y) {
                ; refine with L-axes before verify
                if (pack["h"].Length > 0 || pack["v"].Length > 0)
                    RefineByLAxes(&x, &y, pack, anchorThr)

                ; verify anchors
                if ((pack["cluster"].Length > 0) || (pack["h"].Length > 0) || (pack["v"].Length > 0)) {
                    if (!VerifyAnchorPack(x, y, pack, anchorThr, anchorNeedCluster, anchorNeedH, anchorNeedV))
                        continue
                }

                if (!bestFound) {
                    bestFound := true
                    bestX := x
                    bestY := y
                } else {
                    if (y < bestY || (y = bestY && x < bestX)) {
                        bestX := x
                        bestY := y
                    }
                }
            }
        }

        if (bestFound) {
            outX := bestX
            outY := bestY
            return true
        }

        ; jittered retry to dodge animation frames
        Sleep(Random(retryMinSleep, retryMaxSleep))
    }

    outX := ""
    outY := ""
    return false
}
