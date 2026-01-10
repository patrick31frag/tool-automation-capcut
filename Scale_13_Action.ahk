; ==================================================================================================
;  MODULE 13 — Action
;  Source lines (original scale.ahk): 5874 – 6399
; ==================================================================================================
F3RoiModeOnChange(*) {
    global cbF3RoiMode, F3_ROI_SELECTED, F3_ROI_LIST
    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0)
        return

    idx := F3_ROI_SELECTED
    if (idx < 1 || idx > F3_ROI_LIST.Length)
        idx := 1

    v := SafeCtrlValue(cbF3RoiMode)
    mode := (v = 2) ? 2 : 1
    try {
        F3_ROI_LIST[idx]["mode"] := mode
    } catch {
    }

    ; Refresh labels to show mode per ROI
    RefreshF3RoiCombo(idx)
}

RefreshF3RoiCombo(keepIndex := 1) {
    global cbF3Rois, stF3RoiCount, F3_ROI_LIST, cbF3RoiMode
    if (!IsObject(cbF3Rois))
        return

    try {
        ClearComboItems(cbF3Rois)
    } catch {
    }

    labels := []
    if (IsObject(F3_ROI_LIST)) {
        for i, it in F3_ROI_LIST {
            cx := Round(it["cx"]) , cy := Round(it["cy"])
            w := it["w"] , h := it["h"]
            sc := it.Has("score") ? it["score"] : 0
            md := (it["mode"] = 2) ? "Double" : "Click"
            ord := it.Has("order") ? it["order"] : 0
            labels.Push(Format("{1:02d} | ord={2} | x={3} y={4} w={5} h={6} | score={7} | {8}", i, ord, cx, cy, w, h, Round(sc, 3), md))
        }
    }

    try {
        if (labels.Length > 0)
            cbF3Rois.Add(labels)
    } catch {
    }

    try {
        stF3RoiCount.Text := "ROIs: " (IsObject(F3_ROI_LIST) ? F3_ROI_LIST.Length : 0)
    } catch {
    }

    if (keepIndex < 1)
        keepIndex := 1
    if (IsObject(F3_ROI_LIST) && keepIndex > F3_ROI_LIST.Length)
        keepIndex := F3_ROI_LIST.Length

    try {
        if (labels.Length > 0) {
            cbF3Rois.Choose(keepIndex)
            ; sync mode combo for selected
            cbF3RoiMode.Choose(F3_ROI_LIST[keepIndex]["mode"] = 2 ? 2 : 1)
        } else {
            cbF3RoiMode.Choose(1)
        }
    } catch {
    }
}

F3PreviewSelected() {
    global F3_GUI_SHOW_BORDERS, btnF3Borders
    global F3_ROI_LIST, cbF3Rois, F3_ROI_PARENT_RECT

    ; MODE: PREVIEW one ROI only. Ensure multi-ROI overlay is OFF.
    if (F3_GUI_SHOW_BORDERS) {
        F3_GUI_SHOW_BORDERS := false
        try {
            btnF3Borders.Text := "Show Borders"
        } catch {
        }
        try {
            F3OverlayHide()
        } catch {
        }
    }

    ; Clear any leftover borders before switching mode.
    try {
        Border_ClearLinesForce("preview")
    } catch {
    }

    ; Ensure ROI list exists (auto-build from last parent if needed)
    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0) {
        try {
            F3__BuildRoisFromLastParentForOverlay()
        } catch {
        }
    }
    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0) {
        SetStatus("Overlay: no ROIs yet. Press F3 to set Parent, then scan.")
        try {
            Log("PREVIEW ROI: no ROIs", "DEBUG", "BORDER")
        } catch {
        }
        return
    }

    idx := 0
    try {
        idx := cbF3Rois.Value
    } catch {
        idx := 0
    }
    if (idx < 1 || idx > F3_ROI_LIST.Length) {
        SetStatus("Preview: select a ROI first.")
        try {
            Log("PREVIEW ROI: bad idx=" idx, "DEBUG", "BORDER")
        } catch {
        }
        return
    }

    it := F3_ROI_LIST[idx]
    sr := 0

    ; Prefer stored screenRect
    if (IsObject(it) && it.Has("screenRect")) {
        try {
            sr := it["screenRect"]
        } catch {
            sr := 0
        }
    }

    ; Fallback: rectRel + last parent rect -> screenRect
    if (!IsObject(sr) && IsObject(it) && it.Has("rectRel") && IsObject(F3_ROI_PARENT_RECT)) {
        rr := 0
        try {
            rr := it["rectRel"]
        } catch {
            rr := 0
        }
        if (IsObject(rr)) {
            try {
                sr := AL_RelToScreen(F3_ROI_PARENT_RECT, rr)
            } catch {
                sr := 0
            }
        }
    }

    L := 0, T := 0, R := 0, B := 0
    if (SC_RectUnpack_SAFE(sr, &L, &T, &R, &B)) {
        UpdateBorderRect(L, T, R, B)
        try {
            Log("MODE=PREVIEW idx=" idx " L=" L " T=" T " R=" R " B=" B, "DEBUG", "BORDER")
        } catch {
        }
        return
    }

    try {
        Log("PREVIEW ROI: no valid screen rect idx=" idx, "DEBUG", "BORDER")
    } catch {
    }
}

F3RunSequence() {
    global F3_ROI_LIST, F3_OVERLAY_VISIBLE
    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0) {
        SetStatus("F3 Run: no ROIs.")
        return
    }

    ; If any ROI has a manual order>0, click by that manual order (ascending).
    hasManual := false
    for _, it in F3_ROI_LIST {
        try {
            if (it.Has("order") && it["order"] > 0) {
                hasManual := true
                break
            }
        } catch {
        }
    }

    if (hasManual) {
        seq := []
        used := Map()
        seenOrd := Map()
        dupCount := 0
        for i, it in F3_ROI_LIST {
            ord := 0
            try {
                ord := it.Has("order") ? it["order"] : 0
            } catch {
                ord := 0
            }
            if (ord > 0) {
                ; detect duplicate orders (safe + deterministic tie-break)
                try {
                    if (seenOrd.Has(ord))
                        dupCount += 1
                    else
                        seenOrd[ord] := i
                } catch {
                }

                p := Map()
                p["ord"] := ord
                p["idx"] := i
                seq.Push(p)
                used[i] := true
            }
        }

        try {
            seq.Sort((a, b) => (a["ord"] < b["ord"] ? -1 : (a["ord"] > b["ord"] ? 1 : (a["idx"] < b["idx"] ? -1 : (a["idx"] > b["idx"] ? 1 : 0)))))
        } catch {
        }

        if (dupCount > 0) {
            try {
                Log("F3 Run WARN: duplicate manual orders dup=" dupCount, "WARN", "F3")
            } catch {
            }
        }

        if (F3_OVERLAY_VISIBLE) {
            ; PATCH SLOT: overlay ON => overlay makes master (click ordered only, no LTR remainder)
            SetStatus("F3 Run: clicking " seq.Length " ROI(s) by overlay order only...")
            for _, p in seq {
                i := p["idx"]
                F3__HighlightIndex(i, 260)
                Sleep 40
                F3__ClickIndex(i)
                Sleep 80
            }
        } else {
            rest := []
            for i, _ in F3_ROI_LIST {
                if (!used.Has(i))
                    rest.Push(i)
            }

            SetStatus("F3 Run: clicking " seq.Length " ROI(s) by overlay order + " rest.Length " ROI(s) remaining...")
            ; 1) assigned
            for _, p in seq {
                i := p["idx"]
                F3__HighlightIndex(i, 260)
                Sleep 40
                F3__ClickIndex(i)
                Sleep 80
            }
            ; 2) remaining (keeps current spatial sort)
            for _, i in rest {
                F3__HighlightIndex(i, 180)
                Sleep 30
                F3__ClickIndex(i)
                Sleep 80
            }
        }
    } else {
        SetStatus("F3 Run: clicking " F3_ROI_LIST.Length " ROI(s) in order...")
        ; Click each ROI in the current sorted list
        for i, it in F3_ROI_LIST {
            F3__HighlightIndex(i, 260)
            Sleep 40
            F3__ClickIndex(i)
            Sleep 80
        }
    }

    SetStatus("F3 Run: done.")
}


F3__HighlightIndex(idx, duration := 260) {
    global F3_ROI_LIST
    if (!IsObject(F3_ROI_LIST) || idx < 1 || idx > F3_ROI_LIST.Length)
        return

    it := F3_ROI_LIST[idx]
    if (!IsObject(it) || !it.Has("screenRect"))
        return

    r := it["screenRect"]
    L := 0, T := 0, R := 0, B := 0
    if (!SC_RectUnpack_SAFE(r, &L, &T, &R, &B))
        return
    try {
        ShowRectOverlay(L, T, R, B, duration)
    } catch {
    }
}

F3__ClickIndex(idx) {
    global F3_ROI_LIST
    if (!IsObject(F3_ROI_LIST) || idx < 1 || idx > F3_ROI_LIST.Length)
        return

    it := F3_ROI_LIST[idx]
    if (!IsObject(it) || !it.Has("screenRect"))
        return

    r := it["screenRect"]
    L := 0, T := 0, R := 0, B := 0
    if (!SC_RectUnpack_SAFE(r, &L, &T, &R, &B))
        return
    x := Floor((L + R) / 2)
    y := Floor((T + B) / 2)

    mode := 1
    try {
        mode := (it["mode"] = 2) ? 2 : 1
    } catch {
        mode := 1
    }

    try {
        MoveCursor(x, y)
    } catch {
        try {
            MouseMove(x, y, 0)
        } catch {
        }
    }
    Sleep 10
    try {
        MouseClickLeft(mode)
    } catch {
        ; fallback
        try {
            Click(x, y, mode)
        } catch {
            Click
            if (mode = 2)
                Click
        }
    }
}

F3__ResortExisting() {
    global F3_ROI_LIST, F3_SORT_MODE
    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0)
        return

    try {
        F3__SortRoiItems(F3_ROI_LIST, F3_SORT_MODE)
    } catch {
    }

    RefreshF3RoiCombo(F3_ROI_SELECTED)
}

; ----------------------------------------------------------------------
; ⚠️ SYNTAX NOTE (AHK v2): If you ever see "Error: Missing comma" pointing
; to a function header with "ByRef" (e.g. F3__SortRoiItems(ByRef items,...))
; it usually means the parser got confused by the ByRef token in that spot.
; In v2, Objects/Arrays are already passed by reference (you can modify them
; inside the function and the caller sees the change). So we avoid ByRef here
; to prevent syntax pitfalls when patching/editing quickly.
; ----------------------------------------------------------------------
F3__SortRoiItems(items, mode) {
    ; items: array of roi-items, each has cx, cy, score, area
    if (!IsObject(items) || items.Length <= 1)
        return

    try {
        items.Sort((a, b) => F3__CompareRoi(a, b, mode))
    } catch {
        ; if Sort failed, keep original order
    }
}

F3__CompareRoi(a, b, mode) {
    ; return -1/0/1
    ax := a.Has("cx") ? a["cx"] : 0
    ay := a.Has("cy") ? a["cy"] : 0
    bx := b.Has("cx") ? b["cx"] : 0
    by := b.Has("cy") ? b["cy"] : 0
    ; NOTE (anti-syntax trap): In AutoHotkey v2, the word "as" is reserved (e.g. "catch as e").
    ; NOTE (anti-syntax trap): In AutoHotkey v2, the word "as" is reserved (e.g. catch as e).
    ; Do NOT name variables "as". Use aScore/bScore instead.
    ; Do NOT name variables "as". Use aScore/bScore instead.
    ; NOTE (anti-syntax trap): "as" is a reserved word in AHK v2 (e.g. catch as e).
    ; Avoid variable names: as, try, catch, class, global, static, etc.
    aScore := a.Has("score") ? a["score"] : 0
    bScore := b.Has("score") ? b["score"] : 0

    aa := a.Has("area") ? a["area"] : 0
    ba := b.Has("area") ? b["area"] : 0

    switch mode {
        case "LTR":
            if (ax != bx)
                return ax < bx ? -1 : 1
            if (ay != by)
                return ay < by ? -1 : 1
        case "RTL":
            if (ax != bx)
                return ax > bx ? -1 : 1
            if (ay != by)
                return ay < by ? -1 : 1
        case "TTB":
            if (ay != by)
                return ay < by ? -1 : 1
            if (ax != bx)
                return ax < bx ? -1 : 1
        case "BTT":
            if (ay != by)
                return ay > by ? -1 : 1
            if (ax != bx)
                return ax < bx ? -1 : 1
        case "SCORE":
            if (aScore != bScore)
                return aScore > bScore ? -1 : 1
            ; tie-break: left-to-right
            if (ax != bx)
                return ax < bx ? -1 : 1
        case "AREA":
            if (aa != ba)
                return aa > ba ? -1 : 1
            if (ax != bx)
                return ax < bx ? -1 : 1
        default:
            ; fallback LTR
            if (ax != bx)
                return ax < bx ? -1 : 1
            if (ay != by)
                return ay < by ? -1 : 1
    }

    return 0
}


; Build F3_ROI_LIST from AutoLearn filter candidates (F4) and apply user ordering.
; Returns: sorted candidate list (same objects as input, but reordered).
F3__ApplyOrderFromF4(parentRect, candidates) {
    global F3_ROI_LIST, F3_ROI_PARENT_RECT, F3_SORT_MODE, F3_OVERLAY_VISIBLE

    ; reset if empty
    if (!IsObject(candidates) || candidates.Length = 0) {
        F3_ROI_LIST := []
        F3_ROI_PARENT_RECT := 0
        try {
            RefreshF3RoiCombo(1)
        } catch {
        }
        return candidates
    }

    items := []
    for i, c in candidates {
        rr := c.rectRel
        L := rr.L, T := rr.T, R := rr.R, B := rr.B
        cx := (L + R) / 2
        cy := (T + B) / 2
        w := Abs(R - L)
        h := Abs(B - T)
        area := w * h
        sc := 0
        try {
            sc := c.score
        } catch {
            try {
                sc := c["score"]
            } catch {
                sc := 0
            }
        }
        srect := 0
        try {
            srect := AL_RelToScreen(parentRect, rr)
        } catch {
            srect := 0
        }

        it := Map()
        it["cand"] := c
        it["rectRel"] := rr
        it["cx"] := cx
        it["cy"] := cy
        it["w"] := w
        it["h"] := h
        it["area"] := area
        it["score"] := sc
        it["mode"] := 1
        it["order"] := 0
        if (IsObject(srect))
            it["screenRect"] := srect
        items.Push(it)
    }

    try {
        ; PATCH SLOT: overlay ON => do NOT force LTR sort (overlay order makes master)
        if (!(F3_OVERLAY_VISIBLE && F3_SORT_MODE = "LTR"))
            F3__SortRoiItems(items, F3_SORT_MODE)
    } catch {
    }

    F3_ROI_LIST := items
    F3_ROI_PARENT_RECT := parentRect

    ; Update GUI list if GUI exists
    try {
        RefreshF3RoiCombo(1)
    } catch {
    }

    ; If overlay is visible, rebuild borders/labels for the new ROI list.
    try {
        if (F3_OVERLAY_VISIBLE)
            F3OverlayRebuild()
    } catch {
    }

    sorted := []
    for _, it in items {
        sorted.Push(it["cand"])
    }
    return sorted
}
