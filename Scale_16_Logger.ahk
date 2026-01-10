; ==================================================================================================
;  MODULE 16 — Logger
;  Source lines (original scale.ahk): 7341 – 7852
; ==================================================================================================





DiaScanToggle(*) {
    global chkDiaScan, chkScaScan, f2ScanDia, f2ScanSca
    f2ScanDia := (chkDiaScan.Value = 1)
    if (f2ScanDia) {
        f2ScanSca := false
        chkScaScan.Value := 0
        SetStatus("F2 Scan DIAMOND: drag to select [runner] region.")
    } else {
        SetStatus("F2 Scan DIAMOND: OFF.")
    }
}


ScaScanToggle(*) {
    global chkDiaScan, chkScaScan, f2ScanDia, f2ScanSca
    f2ScanSca := (chkScaScan.Value = 1)
    if (f2ScanSca) {
        f2ScanDia := false
        chkDiaScan.Value := 0
        SetStatus("F2 Scan SCALE: drag to select [scale_runner] region.")
    } else {
        SetStatus("F2 Scan SCALE: OFF.")
    }
}


; =========================================================
; Image list actions
; =========================================================
DiaAddImages(*) {
    global DIA_LIST, diaSel
    files := PickMultiImages("Select DIAMOND images (Ctrl/Shift)")
    if (files.Length = 0) {
        SetStatus("Diamond Add: canceled.")
        return
    }
    added := 0
    for p in files {
        if (p != "" && FileExist(p)) {
            DIA_LIST.Push(p)
            added += 1
        }
    }

    if (added = 0) {
        SetStatus("Diamond Add: no valid files.")
        return
    }
    diaSel := DIA_LIST.Length
    SaveImageListsToIni()
    RefreshDiaCombo()
    SetStatus("Diamond Add: +" added)
}


DiaUpdateSelected(*) {
    global DIA_LIST, diaSel
    if (DIA_LIST.Length < 1) {
        SetStatus("Diamond Update: list empty.")
        return
    }

    if (diaSel < 1 || diaSel > DIA_LIST.Length)
        diaSel := 1
    p := PickSingleImage("Select replacement DIAMOND image")
    if (p = "") {
        SetStatus("Diamond Update: canceled.")
        return
    }
    DIA_LIST[diaSel] := p
    SaveImageListsToIni()
    RefreshDiaCombo()
    SetStatus("Diamond Updated #" diaSel)
}


DiaRemoveSelected(*) {
    global DIA_LIST, diaSel
    if (DIA_LIST.Length < 1)
        return
    if (diaSel < 1 || diaSel > DIA_LIST.Length)
        diaSel := 1
    DIA_LIST.RemoveAt(diaSel)
    if (diaSel > DIA_LIST.Length)
        diaSel := DIA_LIST.Length
    if (diaSel < 1)
        diaSel := 1
    SaveImageListsToIni()
    RefreshDiaCombo()
    SetStatus("Diamond Removed.")
}


ScaAddImages(*) {
    global SCA_LIST, scaSel
    files := PickMultiImages("Select SCALE images (Ctrl/Shift)")
    if (files.Length = 0) {
        SetStatus("Scale Add: canceled.")
        return
    }
    added := 0
    for p in files {
        if (p != "" && FileExist(p)) {
            SCA_LIST.Push(p)
            added += 1
        }
    }

    if (added = 0) {
        SetStatus("Scale Add: no valid files.")
        return
    }
    scaSel := SCA_LIST.Length
    SaveImageListsToIni()
    RefreshScaCombo()
    SetStatus("Scale Add: +" added)
}


ScaUpdateSelected(*) {
    global SCA_LIST, scaSel
    if (SCA_LIST.Length < 1) {
        SetStatus("Scale Update: list empty.")
        return
    }

    if (scaSel < 1 || scaSel > SCA_LIST.Length)
        scaSel := 1
    p := PickSingleImage("Select replacement SCALE image")
    if (p = "") {
        SetStatus("Scale Update: canceled.")
        return
    }
    SCA_LIST[scaSel] := p
    SaveImageListsToIni()
    RefreshScaCombo()
    SetStatus("Scale Updated #" scaSel)
}


ScaRemoveSelected(*) {
    global SCA_LIST, scaSel
    if (SCA_LIST.Length < 1)
        return
    if (scaSel < 1 || scaSel > SCA_LIST.Length)
        scaSel := 1
    SCA_LIST.RemoveAt(scaSel)
    if (scaSel > SCA_LIST.Length)
        scaSel := SCA_LIST.Length
    if (scaSel < 1)
        scaSel := 1
    SaveImageListsToIni()
    RefreshScaCombo()
    SetStatus("Scale Removed.")
}


; =========================================================
; File pick helpers
; =========================================================
PickMultiImages(title) {
    global g
    g.Opt("-AlwaysOnTop")
    sel := FileSelect("M", "", title, "Images (*.png; *.bmp; *.jpg; *.jpeg)")
    g.Opt("+AlwaysOnTop")
    try {
        WinActivate("ahk_id " g.Hwnd)
    } catch {
    }
    return ParseFileSelectMulti(sel)
}


PickSingleImage(title) {
    global g
    g.Opt("-AlwaysOnTop")
    p := FileSelect(1, "", title, "Images (*.png; *.bmp; *.jpg; *.jpeg)")
    g.Opt("+AlwaysOnTop")
    try {
        WinActivate("ahk_id " g.Hwnd)
    } catch {
    }
    return p
}


ParseFileSelectMulti(sel) {
    files := []
    if (sel = "")
        return files

    try {
        if IsObject(sel) {
            for p in sel {
                if (p != "")
                    files.Push(p)
            }
            return files
        }
    } catch {
    }

    s := "" sel
    if InStr(s, "`n") {
        parts := StrSplit(s, "`n")
        dir := RTrim(parts[1], "")
        loop parts.Length - 1 {
            name := parts[A_Index + 1]
            if (name = "")
                continue
            files.Push(dir "" name)
        }
        return files
    }

    files.Push(s)
    return files
}


ShortName(p) {
    if (p = "")
        return ""
    parts := StrSplit(p, "\\")
    return parts.Length ? parts[parts.Length] : p
}


; =========================================================
; Save all settings
; =========================================================
SaveAllToIni(*) {
    global CFG_FILE
    global tolerance, baseV, lowV, highV, scaleDx, scaleDy, workflowMode, jumpPreEsc
    global edTol, edBase, edLow, edHigh, edDx, edDy

    tolerance := ToIntSafe(edTol.Value, 40)
    baseV := ToIntSafe(edBase.Value, 100)
    lowV  := ToIntSafe(edLow.Value, 96)
    highV := ToIntSafe(edHigh.Value, 104)
    scaleDx := ToIntSafe(edDx.Value, 160)
    scaleDy := ToIntSafe(edDy.Value, 0)

    IniWriteSafe(tolerance, CFG_FILE, "main", "tolerance")
    IniWriteSafe(baseV, CFG_FILE, "cycle", "base")
    IniWriteSafe(lowV,  CFG_FILE, "cycle", "low")
    IniWriteSafe(highV, CFG_FILE, "cycle", "high")
    IniWriteSafe(workflowMode, CFG_FILE, "workflow", "mode")
    IniWriteSafe(jumpPreEsc, CFG_FILE, "workflow", "jumpPreEsc")
    IniWriteSafe(scaleDx, CFG_FILE, "auto", "scaleDx")
    IniWriteSafe(scaleDy, CFG_FILE, "auto", "scaleDy")

    SaveImageListsToIni()
    SaveScansToIni()
    SetStatus("Saved INI.")
}


; =========================================================
; Scan history ComboBox
; =========================================================
RefreshScanCombo() {
    global cbScan, SCANS
    ClearComboItems(cbScan)
    if (SCANS.Length = 0) {
        try {
            cbScan.Text := ""
        } catch {
        }
        return
    }
    items := []
    idx := 0
    for rec in SCANS {
        idx += 1
        items.Push(ScanLine(idx, rec))
    }
    cbScan.Add(items)
    try {
        cbScan.Choose(1)
    } catch {
        try {
            cbScan.Text := items[1]
        } catch {
        }
    }
}


ScanLine(n, rec) {
    d := rec["diaL"] "," rec["diaT"] "," rec["diaR"] "," rec["diaB"]
    s := rec["scaL"] "," rec["scaT"] "," rec["scaR"] "," rec["scaB"]
    t := rec["time"]
    return "#" n " | Dia[" d "] | Sca[" s "] | " t
}


; =========================================================
; Cycle logic
; =========================================================
GetCycleValue(idx) {
    global baseV, lowV, highV
    if (idx = 1)
        return baseV
    if (idx = 2)
        return lowV
    if (idx = 3)
        return highV
    return baseV
}


NextCycleIndex(idx) {
    idx += 1
    if (idx > 4)
        idx := 1
    return idx
}



JumpNextFrame_Auto() {
    global nextCutKey, jumpPreEsc
    ; Ensure we are not typing into an edit box in CapCut
    if (jumpPreEsc)
        Send("{Esc}")

    if (nextCutKey != "")
        Send(nextCutKey)

    ; Small settle window (AUTO-ish). The DoOne matcher already retries; this just avoids the "first-frame" miss.
    Sleep(Random(55, 95))
}
; ---------------- AI_SAFEZONE100:CYCLE_MODULE_BEGIN ------------------
; Cycle/index helpers used by scale/sequence logic.
; ---------------------------------------------------------------------

; =========================================================
; Hotkeys logic
; =========================================================
F2Handler() {
    global busy, f2ScanDia, f2ScanSca
    if (busy)
        return

    if (f2ScanDia) {
        busy := true
        try {
            PickAndSaveRegion("runner", "F2 Scan Diamond: Drag with Left Mouse", &ok)
            SetStatus(ok ? "Saved [runner] region." : "Diamond region pick canceled.")
        } finally {
            busy := false
        }
        return
    }

    if (f2ScanSca) {
        busy := true
        try {
            PickAndSaveRegion("scale_runner", "F2 Scan Scale: Drag with Left Mouse", &ok)
            SetStatus(ok ? "Saved [scale_runner] region." : "Scale region pick canceled.")
        } finally {
            busy := false
        }
        return
    }

    RunOnce()
}


; =========================================================
; Parent region (tier0) - Hotkey F3 + History
; =========================================================
F3Handler() {
    
    global __UI_IS_TESTING, allowClickPick, busy, IS_RUNNING
    __ENTRY_Log("F3Handler", "IsTesting=" __UI_IS_TESTING " allowClickPick=" allowClickPick " busy=" (busy ? 1 : 0) " IS_RUNNING=" (IS_RUNNING ? 1 : 0))
    if (__UI_IS_TESTING) {
        Log("F3 IGNORE: UI test lock active", "DEBUG", "F3")
        return
    }
; PIPE STATE (F3 / LEARN):
    ;   INPUT_ACQUIRE → SEGMENTING → FILTERING → BEHAVIOR → EXTRACT_MODEL → SAVE_MODEL
    ; Ghi chú:
    ; - F3 là "học" model (setup). Thường hide GUI để pick/capture window sạch.
    ; - Không click theo kịch bản ở đây (click thuộc ACTION/STEP).

    global g
    global cbParentHist
    global parentL, parentT, parentR, parentB
    global parentHistSuppressStatusOnce
    global f3Atomic
    global parentHistHardLock
    global PARENT_HIST
    global lastF3CommitTick, lastF3CommitOk
    global iniFaulted
    global allowClickPick
    global busy

    global HAS_ACTION_SINCE_PICK
    ; Re-entry guard: prevents double F3 threads (button+hotkey, auto-repeat, etc.)
    static f3Busy := false
    if (f3Busy || busy) {
        try {
            Log("F3 IGNORE reentry busy=" (busy ? 1 : 0) " f3Busy=" (f3Busy ? 1 : 0), "DEBUG", "F3")
        } catch {
        }
        return
    }
    ; Reset ACTION gate for behavior learning (F3 chỉ pick/setup)
    HAS_ACTION_SINCE_PICK := false
    f3Busy := true
    busy := true

    ok := false
    lastF3CommitOk := false
    histBefore := PARENT_HIST.Length
    Log("F3 START ok=0 histBefore=" histBefore " iniFaulted=" iniFaulted " allowClickPick=" allowClickPick, "DEBUG", "F3")
    Critical "On"
    f3Atomic := true
    try {
        ; IMPORTANT: release GUI focus (prevents pick issues)
        try {
            g.Opt("-AlwaysOnTop")
        } catch {
        }
        Sleep 30

        ; Activate the window under the mouse so GUI doesn't steal the drag.
        MouseGetPos(,, &hwndUnder)
        if (hwndUnder && IsSet(g) && hwndUnder != g.Hwnd) {
            try {
                WinActivate("ahk_id " hwndUnder)
            } catch {
            }
        }
        Sleep 30

        ; Hide GUI during pick to avoid stealing clicks/focus
        try {
            g.Hide()
        } catch {
        }
        Sleep 20

        ; Atomic: pick -> save -> apply (no busy, no timer, no ComboBox dependency)
        PickAndSaveParentRegion(&ok)

        if (ok) {
            ; SNAPSHOT: lock the picked rect into locals so GUI/events can't overwrite the source of truth mid-flow
            L := parentL
            T := parentT
            R := parentR
            B := parentB

            wasNew := false
            ; F3 is user-driven: always add an entry so UX never feels like "it didn't save".
            AddOrTouchParentHistory(L, T, R, B, &wasNew, true)
            SaveParentHistoryToIni()
            Log("COMMIT history OK", "DEBUG", "F3")

            ; Refresh UI without letting Change handlers interfere with the atomic F3 flow
            try {
                cbParentHist.OnEvent("Change", ParentHistOnChange, 0)
            } catch {
            }
            parentHistHardLock := true
            RefreshParentHistCombo()
            try {
                cbParentHist.OnEvent("Change", ParentHistOnChange, 1)
            } catch {
            }
            ; Allow any queued Change messages from programmatic refresh to drain
            SetTimer(() => parentHistHardLock := false, -50)

            ; Atomic apply (use locals, not globals)
            ApplyParentRect(L, T, R, B, true)
            ShowRectOverlay(L, T, R, B, 1300)
            parentHistSuppressStatusOnce := true

            histAfter := PARENT_HIST.Length
            lastF3CommitTick := A_TickCount
            lastF3CommitOk := true
            msg := (wasNew ? "Saved [parent] + added to history." : "Saved [parent] (same as last, refreshed).")
            SetStatus(msg " History=" histAfter)
            Log("F3 COMMIT ok=1 histBefore=" histBefore " histAfter=" histAfter " tick=" lastF3CommitTick " iniFaulted=" iniFaulted, "DEBUG", "F3")
        } else {
            SetStatus("Parent region pick canceled.")
            Log("F3 END ok=0 (pick canceled) histBefore=" histBefore " iniFaulted=" iniFaulted, "DEBUG", "F3")
        }
    } finally {
        busy := false
        f3Busy := false
        f3Atomic := false
        try {
            g.Show()
        } catch {
        }
        try {
            g.Opt("+AlwaysOnTop")
        } catch {
        }
        Log("F3 END ok=" (ok ? 1 : 0), "DEBUG", "F3")
        Critical "Off"
    }
}
