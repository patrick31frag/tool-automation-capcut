; ==================================================================================================
;  MODULE 17 — Logger
;  Source lines (original scale.ahk): 7853 – 8322
; ==================================================================================================


ShowCurrentParent() {
    global busy
    global parentL, parentT, parentR, parentB
    global DBG_F3_DIM_TOOLTIP
    global targetExe, targetTitle

    if (busy)
        return

    ; Prefer showing the currently selected history entry (more intuitive).
    if (TryGetSelectedParentHist(&L, &T, &R, &B)) {
        ApplyParentRect(L, T, R, B, true)
        ShowRectOverlay(L, T, R, B, 1300)
        SetStatus("Showing selected Parent history region.")
        return
    }

    if (parentR > parentL && parentB > parentT) {
        ShowRectOverlay(parentL, parentT, parentR, parentB, 1300)
        SetStatus("Showing current [parent] region.")
        return
    }
    SetStatus("No parent region saved yet. Press F3 to set.")
}


PickAndSaveParentRegion(&ok) {
    global CFG_FILE
    global parentL, parentT, parentR, parentB
    global DBG_F3_DIM_TOOLTIP
    global allowClickPick

    ok := false
    pickMsg := allowClickPick ? "F3 Set Parent: Drag OR Click with Left Mouse  (ESC=cancel)" : "F3 Set Parent: Drag with Left Mouse  (ESC=cancel)"
    SetStatus(pickMsg)
    Log("F3 PICK begin allowClickPick=" allowClickPick, "DEBUG", "F3")

    ; --- PICK SNAPSHOT (fix overwrite/double-call symptoms) ---
    ; Step 1) Take the raw return
    pick0 := PickRegionDrag(!allowClickPick)

    ; Step 2) Hard type guard BEFORE any indexing
    if (!IsObject(pick0) || Type(pick0) != "Map") {
        SetStatus("F3 Set Parent: canceled (non-map).")
        rType := IsObject(pick0) ? Type(pick0) : Type(pick0)
        rRepr := IsObject(pick0) ? "<obj:" rType ">" : pick0
        Log("F3 PICK fail non-map r=" rRepr " type=" rType, "DEBUG", "F3")
        return
    }

    ; Step 3) Snapshot-clone immediately, then NEVER touch pick0 again
    ; This isolates the F3 flow from any accidental overwrite / reuse of the same var name elsewhere.
    pick := Map()
    for k, v in pick0
        pick[k] := v
    pick0 := ""  ; drop reference (debug-friendly)

    if (!pick.Has("ok")) {
        SetStatus("F3 Set Parent: canceled (missing-ok).")
        Log("F3 PICK fail missing-ok", "DEBUG", "F3")
        return
    }

    if (!pick["ok"]) {
        reason := pick.Has("reason") ? pick["reason"] : "unknown"
        SetStatus("F3 Set Parent: canceled (" reason ").")
        Log("F3 PICK fail reason=" reason, "DEBUG", "F3")
        return
    }

    if (!pick.Has("L") || !pick.Has("T") || !pick.Has("R") || !pick.Has("B")) {
        SetStatus("F3 Set Parent: canceled (bad-data).")
        Log("F3 PICK fail bad-data keys missing", "DEBUG", "F3")
        return
    }

    ; Avoid any crash here (some users reported rare cases where map becomes non-indexable).
    try {
        L := pick["L"]
        T := pick["T"]
        R := pick["R"]
        B := pick["B"]
        hPicked := (pick.Has("hwnd") ? pick["hwnd"] : 0)
    } catch as e {
        SetStatus("F3 Set Parent: canceled (bad-return).")
        Log("F3 PICK fail bad-return type=" Type(pick) " err=" e.Message, "DEBUG", "F3")
        return
    }

    if (DBG_F3_DIM_TOOLTIP) {
        ToolTip("DEBUG F3: W=" (R - L) "  H=" (B - T))
        SetTimer(() => ToolTip(), -800)
    }

    ; NOTE: Do NOT reject here. PickRegionDrag() already enforces min size + clamps safely.
    ; Some edge cases (very fast drag / near screen edges) can still yield collapsed width/height.
    ; We repair to a minimum size instead of returning with ok=false.
    minSz := 5
    sw := A_ScreenWidth
    sh := A_ScreenHeight

    rawW := R - L
    rawH := B - T

    ; Optional debug (shows raw dimensions before repair)
    if (DBG_F3_DIM_TOOLTIP) {
        ToolTip("DEBUG F3 RAW: W=" rawW "  H=" rawH)
        SetTimer(() => ToolTip(), -800)
    }

    ; Expand tiny/collapsed selections
    if (rawW < minSz)
        R := L + minSz
    if (rawH < minSz)
        B := T + minSz

    ; Shift to keep inside screen bounds (CoordMode Screen)
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

    ; Final safety: re-enforce min size without collapsing
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

    wL := IniWriteSafe(L, CFG_FILE, "parent", "L")
    wT := IniWriteSafe(T, CFG_FILE, "parent", "T")
    wR := IniWriteSafe(R, CFG_FILE, "parent", "R")
    wB := IniWriteSafe(B, CFG_FILE, "parent", "B")
    wH := IniWriteSafe(hPicked, CFG_FILE, "parent", "hwnd")
    Log("F3 INI write parent okL=" wL " okT=" wT " okR=" wR " okB=" wB " okH=" wH " hwnd=" Format("0x{:X}", hPicked+0) " rect=" L "," T "," R "," B, "DEBUG", "F3")

    parentL := L
    parentT := T
    parentR := R
    parentB := B
    global parentHwnd := hPicked
    ok := true
}


ApplyParentRect(L, T, R, B, persist := true) {
    global parentL, parentT, parentR, parentB
    global DBG_F3_DIM_TOOLTIP, CFG_FILE
    parentL := L
    parentT := T
    parentR := R
    parentB := B
    if (persist) {
        IniWriteSafe(parentL, CFG_FILE, "parent", "L")
        IniWriteSafe(parentT, CFG_FILE, "parent", "T")
        IniWriteSafe(parentR, CFG_FILE, "parent", "R")
        IniWriteSafe(parentB, CFG_FILE, "parent", "B")
    }
}


TryGetSelectedParentHist(&L, &T, &R, &B) {
    global cbParentHist, PARENT_HIST
    L := 0
    T := 0
    R := 0
    B := 0

    if (PARENT_HIST.Length < 1)
        return false

    idx := 0
    try {
        idx := cbParentHist.Value
    } catch {
        idx := 0
    }

    if (idx < 1 || idx > PARENT_HIST.Length) {
        txt := ""
        try {
            txt := cbParentHist.Text
        } catch {
            return false
        }
        if RegExMatch(txt, "i)^\s*#\s*(\d+)", &m) {
            idx := ToIntSafe(m[1], 0)
        }
    }

    if (idx < 1 || idx > PARENT_HIST.Length)
        return false

    rec := PARENT_HIST[idx]
    if (!IsObject(rec) || Type(rec) != "Map")
        return false
    if (!rec.Has("L") || !rec.Has("T") || !rec.Has("R") || !rec.Has("B"))
        return false

    L := rec["L"]
    T := rec["T"]
    R := rec["R"]
    B := rec["B"]
    return (R > L && B > T)
}


; forceAdd=true is used by F3 so each pick is visibly recorded (better UX).
AddOrTouchParentHistory(L, T, R, B, &wasNew, forceAdd := false) {
    global PARENT_HIST

    wasNew := false
    now := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") "." Format("{:03}", A_MSec)

    ; If identical to newest, just refresh its timestamp (unless caller forces add).
    if (!forceAdd && PARENT_HIST.Length > 0) {
        top := PARENT_HIST[1]
        if (IsObject(top) && Type(top) = "Map" && top.Has("L") && top.Has("T") && top.Has("R") && top.Has("B")) {
            if (top["L"] = L && top["T"] = T && top["R"] = R && top["B"] = B) {
                top["time"] := now
                return
            }
        }
    }

    rec := Map("L", L, "T", T, "R", R, "B", B, "time", now)
    PARENT_HIST.InsertAt(1, rec)
    wasNew := true

    ; Limit history length
    maxKeep := 20
    while (PARENT_HIST.Length > maxKeep) {
        PARENT_HIST.Pop()
    }
}


LoadParentHistoryFromIni() {
    global PARENT_HIST, CFG_FILE
    PARENT_HIST := []

    ; Load into a temp array first, then normalize ordering so index 1 is ALWAYS newest.
    tmp := []

    cnt := ToIntSafe(IniReadSafe(CFG_FILE, "parent_history", "count", "0"), 0)
    if (cnt < 0)
        cnt := 0

    loop cnt {
        i := A_Index
        sec := "parent_hist_" i
        l := IniReadSafe(CFG_FILE, sec, "L", "")
        if (Trim(l) = "")
            continue
        t := IniReadSafe(CFG_FILE, sec, "T", "")
        r := IniReadSafe(CFG_FILE, sec, "R", "")
        b := IniReadSafe(CFG_FILE, sec, "B", "")
        if (Trim(r) = "" || Trim(b) = "")
            continue

        rec := Map()
        rec["L"] := ToIntSafe(l, 0)
        rec["T"] := ToIntSafe(t, 0)
        rec["R"] := ToIntSafe(r, 0)
        rec["B"] := ToIntSafe(b, 0)
        rec["time"] := IniReadSafe(CFG_FILE, sec, "time", "")
        tmp.Push(rec)
    }

    if (tmp.Length <= 1) {
        PARENT_HIST := tmp
        return
    }

    ; Heuristic: if timestamps exist and appear oldest->newest in INI, reverse.
    k1 := TimeKeySafe(tmp[1].Has("time") ? tmp[1]["time"] : "")
    kN := TimeKeySafe(tmp[tmp.Length].Has("time") ? tmp[tmp.Length]["time"] : "")
    if (k1 && kN && k1 < kN)
        ReverseArray(tmp)

    ; If all have valid timestamps, sort by time desc (newest first) for maximum robustness.
    allOk := true
    for rec in tmp {
        k := TimeKeySafe(rec.Has("time") ? rec["time"] : "")
        if (!k) {
            allOk := false
            break
        }
        rec["__k"] := k
    }

    if (allOk) {
        AL_ArraySort(tmp, (a, b) => (b["__k"] - a["__k"]))
        for rec in tmp
            rec.Delete("__k")
    }

    PARENT_HIST := tmp
}


SaveParentHistoryToIni() {
    global PARENT_HIST, CFG_FILE
    global iniFaulted
    iniFaultBefore := iniFaulted

    ; Keep a max marker so we can clear stale sections when history shrinks.
    prev := ToIntSafe(IniReadSafe(CFG_FILE, "parent_history", "max", "0"), 0)
    if (prev < PARENT_HIST.Length)
        prev := PARENT_HIST.Length

    IniWriteSafe(PARENT_HIST.Length, CFG_FILE, "parent_history", "count")
    IniWriteSafe(prev,              CFG_FILE, "parent_history", "max")

    loop prev {
        i := A_Index
        sec := "parent_hist_" i
        if (i <= PARENT_HIST.Length) {
            rec := PARENT_HIST[i]
            IniWriteSafe(rec["L"], CFG_FILE, sec, "L")
            IniWriteSafe(rec["T"], CFG_FILE, sec, "T")
            IniWriteSafe(rec["R"], CFG_FILE, sec, "R")
            IniWriteSafe(rec["B"], CFG_FILE, sec, "B")
            IniWriteSafe(rec.Has("time") ? rec["time"] : "", CFG_FILE, sec, "time")
        } else {
            IniWriteSafe("", CFG_FILE, sec, "L")
            IniWriteSafe("", CFG_FILE, sec, "T")
            IniWriteSafe("", CFG_FILE, sec, "R")
            IniWriteSafe("", CFG_FILE, sec, "B")
            IniWriteSafe("", CFG_FILE, sec, "time")
        }
    }
    Log("F3 INI write history done count=" PARENT_HIST.Length " iniFaultBefore=" iniFaultBefore " iniFaultAfter=" iniFaulted, "DEBUG", "F3")

}


UpdateParentHistCountUI() {
    global stParentHistCount, PARENT_HIST
    cnt := PARENT_HIST.Length
    try {
        stParentHistCount.Text := "Items: " cnt
    } catch {
    }
}


ParentHistLine(idx, rec) {
    w := rec["R"] - rec["L"]
    h := rec["B"] - rec["T"]
    tm := rec.Has("time") ? rec["time"] : ""
    return "#" idx "  (" rec["L"] "," rec["T"] ")-(" rec["R"] "," rec["B"] ")  [" w "x" h "]  " tm
}


RefreshParentHistCombo() {
    global cbParentHist, PARENT_HIST
    UpdateParentHistCountUI()

    ; IMPORTANT: ComboBox.Delete() does NOT reliably clear all items.
    ; Use a real reset so history always refreshes after F3.
    ClearComboItems(cbParentHist)

    if (PARENT_HIST.Length = 0) {
        try {
            cbParentHist.Text := ""
        } catch {
        }
        return
    }
    items := []
    for idx, rec in PARENT_HIST {
        items.Push(ParentHistLine(idx, rec))
    }
    cbParentHist.Add(items)
    try {
        cbParentHist.Choose(1)
    } catch {
    }


    ; Ensure displayed text reflects the newest entry immediately (programmatic Choose may not sync Text instantly).
    try {
        cbParentHist.Text := items[1]
    } catch {
    }
}



ParentHistOnChange(*) {
    global busy, f3Atomic, parentHistHardLock
    global cbParentHist, PARENT_HIST
    global parentHistSuppressStatusOnce
    global PERSIST_PARENT_ON_HISTORY_SELECT

    if (f3Atomic || busy || parentHistHardLock)
        return

    idx := 0
    try {
        idx := cbParentHist.Value
    } catch {
        idx := 0
    }

    ; ComboBox can still report Value=0 in some edge cases.
    ; Fallback: parse "#N" from the displayed text.
    if (idx < 1 || idx > PARENT_HIST.Length) {
        txt := ""
        try {
            txt := cbParentHist.Text
        } catch {
            return
        }
        if RegExMatch(txt, "i)^\s*#\s*(\d+)", &m) {
            idx := ToIntSafe(m[1], 0)
        }
    }

    if (idx < 1 || idx > PARENT_HIST.Length)
        return

    rec := PARENT_HIST[idx]
    L := rec["L"]
    T := rec["T"]
    R := rec["R"]
    B := rec["B"]
    ApplyParentRect(L, T, R, B, PERSIST_PARENT_ON_HISTORY_SELECT)
    ShowRectOverlay(L, T, R, B, 1300)
    if (parentHistSuppressStatusOnce) {
        parentHistSuppressStatusOnce := false
    } else {
        SetStatus("Loaded parent region from history.")
    }

}
