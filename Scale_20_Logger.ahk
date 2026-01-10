; ==================================================================================================
;  MODULE 20 — Logger
;  Source lines (original scale.ahk): 9280 – 9741
; ==================================================================================================
Border_EnsureLabel(i) {
    global BORDER_LABELS
    if (!IsObject(BORDER_LABELS))
        BORDER_LABELS := []
    if (i < 1)
        i := 1
    if (i <= BORDER_LABELS.Length && IsObject(BORDER_LABELS[i]))
        return BORDER_LABELS[i]
    while (BORDER_LABELS.Length < i)
        BORDER_LABELS.Push(0)

    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale")
    ; Use transcolor background
    g.BackColor := "FFFF00"
    txt := g.AddText("x0 y0 w28 h18 Center +0x200", i) ; +0x200 = SS_CENTERIMAGE
    try {
        txt.SetFont("s9 Bold", "Segoe UI")
    } catch {
    }
    ; show tiny first, then apply TransColor
    g.Show("NA x0 y0 w1 h1")
    try {
        Border_SetTopMost(g.Hwnd)
    } catch {
    }
    try {
        WinSetTransColor("FFFF00", "ahk_id " g.Hwnd)
    } catch {
    }
    BORDER_LABELS[i] := Map("gui", g, "txt", txt)
    return BORDER_LABELS[i]
}

Border_DrawLabel(i, rectOrL, labelText := "") { 
    ; rectOrL must be SCREEN rect (Map with L/T/R/B or object with L/T/R/B)
    lab := Border_EnsureLabel(i)
    g := lab["gui"], txt := lab["txt"]
    try {
        if (labelText = "")
            labelText := i
        txt.Text := labelText
    } catch {
    }
    x := 0, y := 0
    if (IsObject(rectOrL) && Type(rectOrL) = "Map" && rectOrL.Has("L") && rectOrL.Has("T")) {
        x := rectOrL["L"] + 2
        y := rectOrL["T"] + 2
    } else if (IsObject(rectOrL)) {
        _L := HasProp(rectOrL, "L") ? rectOrL.L : (HasProp(rectOrL, "Left") ? rectOrL.Left : 0)
        _T := HasProp(rectOrL, "T") ? rectOrL.T : (HasProp(rectOrL, "Top") ? rectOrL.Top : 0)
        x := _L + 2
        y := _T + 2
    } else {
        return
    }
    ; draw small fixed-size label
    try {
        g.Hide()
    } catch {
    }
    try {
        g.Show("NA x" x " y" y " w28 h18")
    } catch {
    }
    try {
        Border_SetTopMost(g.Hwnd)
    } catch {
    }
    try {
        Border_SetTopMost(g.Hwnd)
    } catch {
    }
    try {
        Border_SetTopMost(g.Hwnd)
    } catch {
    }
    try {
        Border_SetTopMost(g.Hwnd)
    } catch {
    }
    try {
        Border_SetTopMost(g.Hwnd)
    } catch {
    }
}

Border_HideAllLabels() {
    global BORDER_LABELS
    if (!IsObject(BORDER_LABELS))
        return
    for _, it in BORDER_LABELS {
        if (!IsObject(it))
            continue
        try {
            it["gui"].Hide()
        } catch {
        }
    }
}

; ------------------------------
; ROI order input boxes (for Show Border ALL ROI)
; ------------------------------

Border_HideAllOrderInputs() {
    global BORDER_ORDERINPUTS
    if (!IsObject(BORDER_ORDERINPUTS))
        return
    for _, obj in BORDER_ORDERINPUTS {
        if (!IsObject(obj))
            continue
        try {
            obj["gui"].Hide()
        } catch {
        }
    }
}

Border_DestroyAllOrderInputs() {
    global BORDER_ORDERINPUTS
    if (!IsObject(BORDER_ORDERINPUTS))
        return
    for i, obj in BORDER_ORDERINPUTS {
        try {
            if (IsObject(obj) && obj.Has("gui"))
                obj["gui"].Destroy()
        } catch {
        }
    }
    BORDER_ORDERINPUTS := Map()
}




Border_DrawOrderInputsAll() {
    global F3_ROI_LIST
    global BORDER_ORDEROVERRIDE
    if (!IsObject(F3_ROI_LIST))
        return
    for idx, it in F3_ROI_LIST {
        if (!IsObject(it))
            continue
        if (!it.Has("screenRect"))
            continue
        sr := it["screenRect"]

        ; Show current manual order (if any). Blank means "auto".
        v := ""
        try {
            if (it.Has("order") && it["order"] > 0)
                v := it["order"]
        } catch {
        }
        try {
            if (v = "" && IsObject(BORDER_ORDEROVERRIDE) && BORDER_ORDEROVERRIDE.Has(idx))
                v := BORDER_ORDEROVERRIDE[idx]
        } catch {
        }

        try {
            Border_DrawOrderInput(idx, sr, v)
        } catch {
        }
    }
}

Border_EnsureOrderInput(i) {
    global BORDER_ORDERINPUTS
    global gBorderShowAll
    try {
        Log("ENTER idx=" i " showAll=" gBorderShowAll, "DEBUG", "ORDER")
    } catch {
    }
    if (!gBorderShowAll) {
        try {
            Log("GUARD showAll=0 idx=" i, "DEBUG", "ORDER")
        } catch {
        }
        return 0
    }
    if (!IsObject(BORDER_ORDERINPUTS))
        BORDER_ORDERINPUTS := Map()
    if (BORDER_ORDERINPUTS.Has(i) && IsObject(BORDER_ORDERINPUTS[i]) && BORDER_ORDERINPUTS[i].Has("gui") && IsObject(BORDER_ORDERINPUTS[i]["gui"])) {
        try {
            Log("REUSE idx=" i " hwnd=" BORDER_ORDERINPUTS[i]["gui"].Hwnd, "DEBUG", "ORDER")
        } catch {
        }
        return BORDER_ORDERINPUTS[i]
    }
    ; Small topmost edit box (clickable) to type order number
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border -DPIScale")
    try {
        Log("CREATE idx=" i, "DEBUG", "ORDER")
    } catch {
    }
    g.BackColor := "FFFFFF"
    g.MarginX := 2, g.MarginY := 1
    g.SetFont("s9", "Segoe UI")

    edt := g.AddEdit("w36 h20 Center Number Limit3 vord", "")
    ; Prevent initial activation flicker
    try {
        g.Show("Hide")
    } catch {
    }

    ; Remember index in the GUI object
    g.__idx := i
    ; Change event: store value (does not modify ROI list to avoid breaking logic)
    edt.OnEvent("Change", (*) => Border_OnOrderInputChange(i, edt))

    obj := Map("gui", g, "edit", edt)
    BORDER_ORDERINPUTS[i] := obj
    try {
        Log("CREATED idx=" i " hwnd=" g.Hwnd, "DEBUG", "ORDER")
    } catch {
    }
    try {
        Border_SetTopMost(g.Hwnd)
    } catch {
    }
    return obj
}

Border_OnOrderInputChange(i, edt) {
    global BORDER_ORDEROVERRIDE
    global F3_ROI_LIST

    if (!IsObject(BORDER_ORDEROVERRIDE))
        BORDER_ORDEROVERRIDE := Map()

    v := Trim(edt.Value)
    ; Keep only digits
    v := RegExReplace(v, "[^\d]")

    ord := 0
    if (v != "")
        ord := v + 0

    ; Store override map (by ROI index)
    if (ord <= 0) {
        try {
            if (BORDER_ORDEROVERRIDE.Has(i))
                BORDER_ORDEROVERRIDE.Delete(i)
        } catch {
        }
    } else {
        BORDER_ORDEROVERRIDE[i] := ord
    }

    ; Apply to ROI data so RUN uses it (order>0 => manual)
    try {
        if (IsObject(F3_ROI_LIST) && i >= 1 && i <= F3_ROI_LIST.Length && IsObject(F3_ROI_LIST[i])) {
            F3_ROI_LIST[i]["order"] := ord
        }
    } catch {
    }

    ; Refresh GUI list label (ord=...)
    try {
        RefreshF3RoiCombo(i)
    } catch {
    }

    msg := "ORDERINPUT idx=" i " ord=" (ord <= 0 ? "<auto>" : ord)
    try {
        Log(msg, "DEBUG", "BORDER")
    } catch {
    }
}

Border_DrawOrderInput(i, rect, val := "") {
    try {
        Log("ENTER idx=" i, "DEBUG", "ORDER")
    } catch {
    }
    ; rect is expected to be SCREEN coords (L,T,R,B)
    obj := Border_EnsureOrderInput(i)
    if (!IsObject(obj))
        return

    L := 0, T := 0, R := 0, B := 0
    if (!SC_RectUnpack_SAFE(rect, &L, &T, &R, &B)) {
        ; Fallback (older rect objects)
        if (IsObject(rect)) {
            try L := rect.Has("L") ? rect["L"] : rect.L
            catch {
            }
            try T := rect.Has("T") ? rect["T"] : rect.T
            catch {
            }
            try R := rect.Has("R") ? rect["R"] : rect.R
            catch {
            }
            try B := rect.Has("B") ? rect["B"] : rect.B
            catch {
            }
        }
    }

    try {
        Log("RECT idx=" i " L=" L " T=" T " R=" R " B=" B, "DEBUG", "ORDER")
    } catch {
    }

    ; Put the input box INSIDE the border, top-right corner.
    w := 36
    x := (R > 0 ? (R - w - 2) : (L + 2))
    y := T + 2
    if (x < 0)
        x := 0
    if (y < 0)
        y := 0

    ; Set value (only if provided; blank means "auto" and should not wipe user's input)
    if (val != "")
        try {
            obj["edit"].Value := val
        } catch {
        }
    try {
        Log("SHOW idx=" i " x=" x " y=" y, "DEBUG", "ORDER")
    } catch {
    }
    try {
        obj["gui"].Show("x" x " y" y " NA")
    } catch {
    }
    try {
        Border_SetTopMost(obj["gui"].Hwnd)
    } catch {
    }
}



; ===============================
; Border sets for ALL ROI (multi borders)
Border_EnsureSet(i) {
    global BORDER_SETS
    if (!IsObject(BORDER_SETS))
        BORDER_SETS := []
    if (i < 1)
        i := 1
    if (i <= BORDER_SETS.Length && IsObject(BORDER_SETS[i]))
        return BORDER_SETS[i]
    ; grow array
    while (BORDER_SETS.Length < i)
        BORDER_SETS.Push(0)
    set := Map()
    set["top"] := MakeLineGui()
    set["left"] := MakeLineGui()
    set["right"] := MakeLineGui()
    set["bottom"] := MakeLineGui()
    BORDER_SETS[i] := set
    return set
}

Border_DrawUsingSet(set, rectOrL, T := unset, R := unset, B := unset, hwnd := 0) {
    static _lastDrawTick := 0
    if (A_TickCount - _lastDrawTick < 60) {
        Border_BringOrderInputsToTop()
        return
    }
    _lastDrawTick := A_TickCount

    global borderG
    old := borderG
    borderG := set
    try {
        ; reuse existing UpdateBorderRect logic (SCREEN COORD + logs + w/h<2 skip)
        if (IsObject(rectOrL)) {
            ; rectOrL may be Map/Object; UpdateBorderRect requires L,T,R,B (no extra params)
            if (Type(rectOrL) = "Map") {
                if (rectOrL.Has("L") && rectOrL.Has("T") && rectOrL.Has("R") && rectOrL.Has("B")) {
                    UpdateBorderRect(rectOrL["L"], rectOrL["T"], rectOrL["R"], rectOrL["B"])
                } else if (rectOrL.Has("X") && rectOrL.Has("Y") && rectOrL.Has("W") && rectOrL.Has("H")) {
                    UpdateBorderRect(rectOrL["X"], rectOrL["Y"], rectOrL["X"] + rectOrL["W"], rectOrL["Y"] + rectOrL["H"])
                } else {
                    UpdateBorderRect(0, 0, 0, 0)
                }
            } else {
                ; Object rect: support L/T/R/B or Left/Top/Right/Bottom without try/catch
                _L := HasProp(rectOrL, "L") ? rectOrL.L : (HasProp(rectOrL, "Left") ? rectOrL.Left : 0)
                _T := HasProp(rectOrL, "T") ? rectOrL.T : (HasProp(rectOrL, "Top") ? rectOrL.Top : 0)
                _R := HasProp(rectOrL, "R") ? rectOrL.R : (HasProp(rectOrL, "Right") ? rectOrL.Right : 0)
                _B := HasProp(rectOrL, "B") ? rectOrL.B : (HasProp(rectOrL, "Bottom") ? rectOrL.Bottom : 0)
                UpdateBorderRect(_L+0, _T+0, _R+0, _B+0)
            }
        } else if (IsSet(T) && IsSet(R) && IsSet(B)) {
            UpdateBorderRect(rectOrL, T, R, B)
        } else {
            UpdateBorderRect(rectOrL, 0, rectOrL, 0)
        }
    } catch {
    }
    Border_BringOrderInputsToTop()

    borderG := old
}

F3GuiDrawAllRoiBorders() {
    global F3_ROI_LIST, F3_ROI_PARENT_RECT
    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0) {
        try {
            Log("SHOW BORDERS: no ROIs", "DEBUG", "BORDER")
        } catch {
        }
        return
    }
    ; draw ALL roi borders using pooled sets (avoid overlay GUI => no black bar)
    for i, it in F3_ROI_LIST {
        sr := 0
        ; prefer screenRect
        if (IsObject(it) && it.Has("screenRect")) {
            try {
                sr := it["screenRect"]
            } catch {
            }
        }
        ; fallback: rectRel -> screen via parent
        if (!IsObject(sr) && IsObject(it) && it.Has("rectRel") && IsObject(F3_ROI_PARENT_RECT)) {
            rr := 0
            try {
                rr := it["rectRel"]
            } catch {
            }
            if (IsObject(rr)) {
                try {
                    sr := AL_RelToScreen(F3_ROI_PARENT_RECT, rr)
                } catch {
                }
            }
        }
        if (!IsObject(sr))
            continue
        set := Border_EnsureSet(i)
        ; sr is already screen coords; keep hwnd=0 so dx/dy = 0
        Border_DrawUsingSet(set, sr, unset, unset, unset, 0)
        ; label order/index for this ROI
        labelVal := i
        try {
            if (IsObject(it) && it.Has("order") && (it["order"] > 0))
                labelVal := it["order"]
        } catch {
        }
        try {
            Border_DrawOrderInput(i, sr, labelVal)
        } catch {
        }
    }
}






; =========================================================
; CORE: Diamond -> Scale
; =========================================================
