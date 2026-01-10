; ==================================================================================================
;  MODULE 26 — GUI
;  Source lines (original scale.ahk): 12203 – 12698
; ==================================================================================================
SetGuiMode(mode) {
    global GUI_MODE, GUI_OPA_RUN, GUI_OPA_EDIT, g
    GUI_MODE := mode

    ; Nếu GUI chính chưa tồn tại thì bỏ qua
    try {
        if (!IsObject(g) || !g.Hwnd)
            return
    } catch {
        return
    }

    hwnd := g.Hwnd
    if (mode = "RUN") {
        ; RUN = mờ + click-through (không chặn chuột)
        try {
            WinSetTransparent(GUI_OPA_RUN, "ahk_id " hwnd)
        } catch {
        }
        try {
            WinSetExStyle("+0x20", "ahk_id " hwnd) ; WS_EX_TRANSPARENT
        } catch {
        }
        try {
            g.Show("NA")
        } catch {
        }
        return
    }

    ; EDIT = rõ nét + nhận chuột
    try {
        WinSetTransparent(GUI_OPA_EDIT, "ahk_id " hwnd)
    } catch {
    }
    try {
        WinSetExStyle("-0x20", "ahk_id " hwnd) ; remove WS_EX_TRANSPARENT
    } catch {
    }
    try {
        g.Show()
    } catch {
    }
}


Init() {
    ; ---------- Performance ----------
    SetKeyDelay(-1, -1)
    SetMouseDelay(-1)
    SetWinDelay(-1)
    SetControlDelay(-1)
    ProcessSetPriority("High")

    CoordMode("Mouse", "Screen")
    CoordMode("Pixel", "Screen")
    CoordMode("ToolTip", "Screen")

    ; ---------- DPI Guard (block-form try/catch ONLY) ----------
    global DPI_AWARE := false
    global SYS_DPI := 96
    global SCALE_PCT := 100
    InitDpiGuard()

    ; ---------- Config ----------
; ---------------- AI_SAFEZONE100:INIT_MODULE_BEGIN -------------------
; Script initialization / hotkeys / startup. Avoid return-with-value here.
; ---------------------------------------------------------------------
    global CFG_FILE := A_ScriptDir "\ScaleCycle.ini"

    ; INI health flag (must be initialized BEFORE any IniReadSafe/IniWriteSafe calls)
    global iniFaulted := 0

    ; ----- F3 commit + debug -----
    global lastF3CommitTick := 0
    global lastF3CommitOk := false
    ; LOG_FILE is defined at top-level as A_ScriptDir "\error.log"
    global iniFaultNotified := false

    EnsureIniFile()
    ; F3 UX options
    ; allowClickPick=1 in [f3] section => click-only pick is accepted (no-drag will NOT cancel).
    global allowClickPick := (ToIntSafe(IniReadSafe(CFG_FILE, "f3", "allowClickPick", "1"), 1) != 0)

    ; Debug toggles
    global DBG_F3_OK_TOOLTIP := true

    global DBG_F3_DIM_TOOLTIP := false  ; DEBUG: show W/H tooltip after pick
    ; DEBUG: show a tooltip while waiting for mouse press during region pick
    global DBG_PICK_WAIT_TOOLTIP := true
    ; Internal: prevent ParentHistOnChange from overwriting status once (used by F3 flow)
    global parentHistSuppressStatusOnce := false
    ; Internal: lock to prevent GUI Change handlers from interfering during atomic F3 flow
    global f3Atomic := false
    ; Internal: hard lock to block late ComboBox Change messages after F3 refresh
    global parentHistHardLock := false
    ; If true, selecting a history item will also persist [parent] to INI.
    ; Default false to prevent late GUI events from reverting the INI after F3.
    global PERSIST_PARENT_ON_HISTORY_SELECT := false
    ; Internal: temporarily lock Parent history ComboBox Change handler during programmatic refresh (F3)
    ; Target window (state-aware gate)
    global targetExe := Trim(IniReadSafe(CFG_FILE, "target", "exe", ""))
    global targetTitle := Trim(IniReadSafe(CFG_FILE, "target", "title", ""))

    ; General
    global tolerance := ToIntSafe(IniReadSafe(CFG_FILE, "main", "tolerance", "40"), 40)
    global clickOffsetX := ToIntSafe(IniReadSafe(CFG_FILE, "main", "clickOffsetX", "6"), 6)
    global clickOffsetY := ToIntSafe(IniReadSafe(CFG_FILE, "main", "clickOffsetY", "6"), 6)

    ; Parent (manual) region (tier0 / coarse)
    global parentL := ToIntSafe(IniReadSafe(CFG_FILE, "parent", "L", "0"), 0)
    global parentT := ToIntSafe(IniReadSafe(CFG_FILE, "parent", "T", "0"), 0)
    global parentR := ToIntSafe(IniReadSafe(CFG_FILE, "parent", "R", "0"), 0)
    global parentB := ToIntSafe(IniReadSafe(CFG_FILE, "parent", "B", "0"), 0)
    global parentHwnd := ToIntSafe(IniReadSafe(CFG_FILE, "parent", "hwnd", "0"), 0)

    ; Runner region (diamond)
    global runnerL := ToIntSafe(IniReadSafe(CFG_FILE, "runner", "L", "0"), 0)
    global runnerT := ToIntSafe(IniReadSafe(CFG_FILE, "runner", "T", "0"), 0)
    global runnerR := ToIntSafe(IniReadSafe(CFG_FILE, "runner", "R", "0"), 0)
    global runnerB := ToIntSafe(IniReadSafe(CFG_FILE, "runner", "B", "0"), 0)

    ; Scale runner region (optional)
    global scaleRunL := ToIntSafe(IniReadSafe(CFG_FILE, "scale_runner", "L", "0"), 0)
    global scaleRunT := ToIntSafe(IniReadSafe(CFG_FILE, "scale_runner", "T", "0"), 0)
    global scaleRunR := ToIntSafe(IniReadSafe(CFG_FILE, "scale_runner", "R", "0"), 0)
    global scaleRunB := ToIntSafe(IniReadSafe(CFG_FILE, "scale_runner", "B", "0"), 0)

    ; Auto offset fallback
    global scaleDx := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "scaleDx", "160"), 160)
    global scaleDy := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "scaleDy", "0"), 0)

    ; Optional relative offset scaling by window size
    global relOffset := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "relOffset", "1"), 1) ; 0=off,1=scale by window size
    global baseWinW := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "baseWinW", "0"), 0)
    global baseWinH := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "baseWinH", "0"), 0)

    ; Cache/Anchor tuning
    global cacheBox := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "cacheBox", "240"), 240)
    global anchorThr := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "anchorThr", "18"), 18)

    ; Cluster needs
    global anchorNeedCluster := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "anchorNeedCluster", "3"), 3)

    ; L-anchor needs (H/V)
    global anchorNeedH := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "anchorNeedH", "2"), 2)
    global anchorNeedV := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "anchorNeedV", "2"), 2)

    ; Retry timing
    global retryMs := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "retryMs", "700"), 700)
    global retryMinSleep := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "retryMinSleep", "25"), 25)
    global retryMaxSleep := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "retryMaxSleep", "60"), 60)

    ; History boxes
    global diaBox := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "diamondBox", "120"), 120)
    global scaBox := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "scaleBox", "160"), 160)



    ; Scan history cap (avoid INI/GUI bloat)
    global maxScanKeep := ToIntSafe(IniReadSafe(CFG_FILE, "auto", "maxScanKeep", "50"), 50)
    ; Cycle values
    global baseV := ToIntSafe(IniReadSafe(CFG_FILE, "cycle", "base", "100"), 100)
    global lowV  := ToIntSafe(IniReadSafe(CFG_FILE, "cycle", "low", "96"), 96)
    global highV := ToIntSafe(IniReadSafe(CFG_FILE, "cycle", "high", "104"), 104)

    ; Workflow
    global workflowMode := IniReadSafe(CFG_FILE, "workflow", "mode", "KEYFRAME_CYCLE") ; KEYFRAME_CYCLE | CLASSIC
    global jumpPreEsc := ToIntSafe(IniReadSafe(CFG_FILE, "workflow", "jumpPreEsc", "1"), 1)

    ; Keys
    global commitKey   := IniReadSafe(CFG_FILE, "keys", "commitKey", "{Enter}")
    global keyframeKey := IniReadSafe(CFG_FILE, "keys", "keyframeKey", "")
    global nextCutKey  := IniReadSafe(CFG_FILE, "keys", "nextCutKey", "/")

    ; Click modes (1=Click, 2=Double)
    global diamondClickMode := ToIntSafe(IniReadSafe(CFG_FILE, "clickmodes", "diamond", "1"), 1)
    global scaleClickMode   := ToIntSafe(IniReadSafe(CFG_FILE, "clickmodes", "scale", "2"), 2)


    ; F3 ROI ordering (multi-icon list order)
    ; LTR|RTL|TTB|BTT|SCORE|AREA
    try {
        sm := StrUpper(Trim(IniReadSafe(CFG_FILE, "f3roi", "sort", F3_SORT_MODE)))
        if (sm = "LTR" || sm = "RTL" || sm = "TTB" || sm = "BTT" || sm = "SCORE" || sm = "AREA")
            F3_SORT_MODE := sm
    } catch {
        ; keep default
    }

    ; Image lists
    global DIA_LIST := []
    global SCA_LIST := []
    global diaSel := 1
    global scaSel := 1
    LoadImageListsFromIni()

    ; Scan history (newest first)
    global SCANS := []
    LoadScansFromIni()

    ; Parent region history (newest first)
    global PARENT_HIST := []
    LoadParentHistoryFromIni()


    ; Runtime state
    global running := false
    global busy := false
    global F4_QUEUED := false
    global stepIndex := 1

    ; F2 scan toggles
    global f2ScanDia := false
    global f2ScanSca := false

    ; Cache last found positions
    global lastDia := Map("x","", "y","")
    global lastSca := Map("x","", "y","")

    ; Anchor packs (cluster + H + V), auto-learned
    global diaPack := MakeEmptyAnchorPack()
    global scaPack := MakeEmptyAnchorPack()

    ; Window cache (invalidate caches if window moved/resized)
    global winCache := Map("hwnd", 0, "x", 0, "y", 0, "w", 0, "h", 0)

    ; Border overlay GUIs (for region picking)
    global borderG := Map()
    global BORDER_SETS := []  ; pool of border sets for ALL ROI (each ROI = 4 line GUIs)

    OnExit(Cleanup)

        ; ---------- GUI ----------
    ; ==================================================================================================
    ; PATCHABLE_ZONE_GUI_BEGIN
    ; Automation-first GUI (Simple by default; Advanced panel optional)
    ; - SIMPLE: A/B cycle + Learn + Start/Stop + clear instructions
    ; - ADVANCED: Setup/Anchors/History/Help for power users
    ; NOTE: UI-only. Engine logic + hotkeys remain unchanged.
    ; ==================================================================================================

    global UI_VIEW := "SIMPLE"
    global UI_ADV_VISIBLE := false
    global UI_AUTOHIDE_WHEN_RUN := true
    global UI_W_SIMPLE := 640
    global UI_H_SIMPLE := 380
    global UI_W_ADV := 1120
    global UI_H_ADV := 760

    global g := Gui("+AlwaysOnTop +OwnDialogs", "CapCut Auto Keyframe Tool (AHK v2)")
    g.MarginX := 12
    g.MarginY := 10
    g.SetFont("s9", "Segoe UI")

    ; Header
    g.SetFont("s14 bold", "Segoe UI")
    global stTitle := g.AddText("x12 y10 w1200 h26 +0x200", T("TXT_CAPCUT_AUTO_KEYFRAME_TOOL"))
    g.SetFont("s9 norm", "Segoe UI")
    global stSub := g.AddText("x12 y+2 w1200 h20 +0x200"
        , T("TXT_FOCUS_A_NUMERIC_FIELD_IN_CAPCUT_F4_L"))

    ; ================================================================================================
    ; SIMPLE PANEL (default)
    ; ================================================================================================

    global gbMain := g.AddGroupBox("x12 y56 w616 h128", T("GRP_AUTO_KEYFRAME_CYCLE_A_B"))
    mx := 28, my := 86
    g.SetFont("s10 bold", "Segoe UI")
    global stA := g.AddText("x" mx " y" my " w20 h22 +0x200", T("TXT_A"))
    g.SetFont("s10 norm", "Segoe UI")
    global edLow := g.AddEdit("x" (mx+24) " y" (my-2) " w120 h28 Number", lowV)
    g.SetFont("s10 bold", "Segoe UI")
    global stB := g.AddText("x" (mx+170) " y" my " w20 h22 +0x200", T("TXT_B"))
    g.SetFont("s10 norm", "Segoe UI")
    global edHigh := g.AddEdit("x" (mx+194) " y" (my-2) " w120 h28 Number", highV)

    global btnLearn := g.AddButton("x" (mx+330) " y" (my-4) " w150 h32", T("BTN_LEARN_DIAMOND_F4"))
    btnLearn.OnEvent("Click", (*) => F4_Queue(true))

    

    ; Quick test: click the learned diamond once (no "/" and no A/B typing)
    global btnTestDia := g.AddButton("x" (mx+490) " y" (my-4) " w110 h32", T("BTN_TEST_CLICK"))
    btnTestDia.OnEvent("Click", UI_TestDiamondClick)
global chkAutoHide := g.AddCheckBox("x" (mx+340) " y" (my+34) " w220 h22 Checked", T("CHK_AUTO_HIDE_WHILE_RUN"))
    chkAutoHide.OnEvent("Click", UI_OnAutoHideToggle)

    global btnAdvanced := g.AddButton("x" (mx+340) " y" (my+60) " w150 h30", T("BTN_ADVANCED"))
    btnAdvanced.OnEvent("Click", UI_ToggleAdvanced)

    ; Legacy fields (kept for engine/backward compatibility, hidden in SIMPLE)
    global edBase := g.AddEdit("x-2000 y-2000 w90 h22 Hidden Number", baseV)
    global edTol  := g.AddEdit("x-2000 y-2000 w80 h22 Hidden Number", tolerance)
    global edDx   := g.AddEdit("x-2000 y-2000 w90 h22 Hidden Number", scaleDx)
    global edDy   := g.AddEdit("x-2000 y-2000 w90 h22 Hidden Number", scaleDy)

    global btnSave := g.AddButton("x28 y" (56+128-34) " w120 h30", T("BTN_SAVE_INI"))
    btnSave.OnEvent("Click", SaveAllToIni)

    ; How-to (always visible)
    global stHow := g.AddEdit("x12 y196 w616 r5 ReadOnly -Tabstop +VScroll -HScroll"
        , T("EDT_HOW_TO_USE_N")
        . "  1) In CapCut, click a numeric field you want to animate (Scale/Position/Effect).\n"
        . "  2) Press F4 once to learn the diamond (keyframe) button.\n"
        . "  3) Press F1 to start. The tool will: / → wait → click ◇ → type A/B.\n"
        . "  4) Press F1 again (or ESC) to stop.")

    ; ================================================================================================
    ; ADVANCED PANEL (hidden by default)
    ; ================================================================================================

    advX := 12
    advY := 310
    advW := UI_W_ADV - 24
    advH := 370

    global gbAdv := g.AddGroupBox("x" advX " y" advY " w" advW " h" advH " Hidden", T("GRP_ADVANCED"))
    global tabAdv := g.AddTab3("x" (advX+12) " y" (advY+26) " w" (advW-24) " h" (advH-40) " Hidden"
        , ["Setup", "Anchors", "History", "Help"])

    ; --- Tab 1: Setup (Parent / ROIs) ---
    tabAdv.UseTab(1)
    sx := advX + 26
    sy := advY + 70
    global stRoiLblParent := g.AddText("x" sx " y" sy " w120 h20 +0x200", T("TXT_PARENT_REGION"))
    global btnParentSet := g.AddButton("x+8 w140 h28", T("BTN_SET_PARENT_F3"))
    global btnParentShow := g.AddButton("x+10 w120 h28", T("BTN_SHOW"))
    btnParentSet.OnEvent("Click", (*) => F3Handler())
    btnParentShow.OnEvent("Click", (*) => F3GuiShowParentBorder())

    sy2 := sy + 44
    global stRoiLblF3 := g.AddText("x" sx " y" sy2 " w120 h20 +0x200", T("TXT_F3_ROIS"))
    global cbF3Order := g.AddComboBox("x+8 w160 h24", ["L→R", "R→L", "T→B", "B→T", "Score", "Size"])
    global cbF3Rois := g.AddComboBox("x+10 w520 r10 h24", [])
    global cbF3RoiMode := g.AddComboBox("x+10 w110 h24", ["Click", "Double"])
    global btnF3Preview := g.AddButton("x+10 w110 h28", T("BTN_PREVIEW"))
    global btnF3Run := g.AddButton("x+10 w110 h28", T("BTN_RUN"))
    global btnF3Borders := g.AddButton("x" sx " y" (sy2+44) " w160 h28", T("BTN_SHOW_BORDERS"))
    global stF3RoiCount := g.AddText("x+10 w180 h20 +0x200", T("TXT_ROIS_0"))

    cbF3Order.OnEvent("Change", F3OrderOnChange)
    cbF3Rois.OnEvent("Change", F3RoiOnChange)
    cbF3RoiMode.OnEvent("Change", F3RoiModeOnChange)
    btnF3Preview.OnEvent("Click", (*) => F3PreviewSelected())
    btnF3Run.OnEvent("Click", (*) => F3RunSequence())
    btnF3Borders.OnEvent("Click", (*) => F3GuiToggleBorders())

    global stRoiLblHistory := g.AddText("x" sx " y" (sy2+86) " w120 h20 +0x200", T("TXT_PARENT_HISTORY"))
    global cbParentHist := g.AddComboBox("x+8 w520 r10 h24", [])
    global stParentHistCount := g.AddText("x+10 w180 h20 +0x200", T("TXT_ITEMS_0"))
    cbParentHist.OnEvent("Change", ParentHistOnChange)

    ; --- Tab 2: Anchors ---
    tabAdv.UseTab(2)
    ax := advX + 26
    ay := advY + 70
    global stAnchLblDia := g.AddText("x" ax " y" ay " w120 h20 +0x200", T("TXT_DIAMOND_ANCHORS"))
    global cbDia := g.AddComboBox("x+8 w620 r10 h24", [])
    global cbDiaMode := g.AddComboBox("x+10 w110 h24", ["Click", "Double"])
    global chkDiaScan := g.AddCheckBox("x+12 w120", T("CHK_F2_SCAN"))
    global btnDiaAdd := g.AddButton("x+10 w90 h28", T("BTN_ADD"))
    global btnDiaUpd := g.AddButton("x+10 w90 h28", T("BTN_UPDATE"))
    global btnDiaDel := g.AddButton("x+10 w100 h28", T("BTN_REMOVE"))

    cbDia.OnEvent("Change", DiaOnChange)
    cbDiaMode.OnEvent("Change", DiaModeOnChange)
    chkDiaScan.OnEvent("Click", DiaScanToggle)
    btnDiaAdd.OnEvent("Click", DiaAddImages)
    btnDiaUpd.OnEvent("Click", DiaUpdateSelected)
    btnDiaDel.OnEvent("Click", DiaRemoveSelected)

    ay2 := ay + 46
    global stAnchLblSca := g.AddText("x" ax " y" ay2 " w120 h20 +0x200", T("TXT_SCALE_ANCHORS"))
    global cbSca := g.AddComboBox("x+8 w620 r10 h24", [])
    global cbScaMode := g.AddComboBox("x+10 w110 h24", ["Click", "Double"])
    global chkScaScan := g.AddCheckBox("x+12 w120", T("CHK_F2_SCAN"))
    global btnScaAdd := g.AddButton("x+10 w90 h28", T("BTN_ADD"))
    global btnScaUpd := g.AddButton("x+10 w90 h28", T("BTN_UPDATE"))
    global btnScaDel := g.AddButton("x+10 w100 h28", T("BTN_REMOVE"))

    cbSca.OnEvent("Change", ScaOnChange)
    cbScaMode.OnEvent("Change", ScaModeOnChange)
    chkScaScan.OnEvent("Click", ScaScanToggle)
    btnScaAdd.OnEvent("Click", ScaAddImages)
    btnScaUpd.OnEvent("Click", ScaUpdateSelected)
    btnScaDel.OnEvent("Click", ScaRemoveSelected)

    ; --- Tab 3: History ---
    tabAdv.UseTab(3)
    hx := advX + 26
    hy := advY + 70
    global stHistLblScan := g.AddText("x" hx " y" hy " w" (advW-60) " h20 +0x200", T("TXT_SCAN_HISTORY_NEWEST_FIRST"))
    global cbScan := g.AddComboBox("x" hx " y+8 w" (advW-60) " h24 r12", [])
    global stHistHint := g.AddText("x" hx " y+10 w" (advW-60) " h60"
        , T("TXT_HISTORY_RECORDS_LAST_CAPTURES_AND_CO"))

    ; --- Tab 4: Help ---
    tabAdv.UseTab(4)
    kx := advX + 26
    ky := advY + 70
    global stHelp1 := g.AddEdit("x" kx " y" ky " w" (advW-60) " r14 ReadOnly -Tabstop +VScroll -HScroll"
        , T("EDT_QUICK_START_N")
        . "  1) Activate CapCut window\n"
        . "  2) Focus a numeric field (Scale/Position/Effect)\n"
        . "  3) Learn diamond once (F4)\n"
        . "  4) Start/Stop with F1\n\n"
        . "Notes:\n"
        . "  - Tool runs keyboard-first; avoid clicking the tool while running.\n"
        . "  - If CapCut loses focus, the tool may auto-stop for safety.")

    tabAdv.UseTab(0)

    ; ================================================================================================
    ; ACTION BAR (always visible)
    ; ================================================================================================

    global gbActions := g.AddGroupBox("x12 y" (UI_H_SIMPLE-86) " w616 h76", T("GRP_ACTIONS"))
    bx := 28
    by := UI_H_SIMPLE-58
    global btnRunMain := g.AddButton("x" bx " y" by " w130 h34", T("BTN_START_F1"))
    global btnStopMain := g.AddButton("x+10 w130 h34", T("BTN_STOP"))
    global btnResetMain := g.AddButton("x+10 w130 h34 Hidden", T("BTN_RESET_UI"))

    btnRunMain.OnEvent("Click", (*) => ToggleRun())
    btnStopMain.OnEvent("Click", (*) => StopRun())
    btnResetMain.OnEvent("Click", (*) => UI_ResetUiOnly())

    g.SetFont("s12 bold", "Segoe UI")
    global stStateDot := g.AddText("x+22 y" by " w18 h28 +0x200", T("TXT_TXT_01"))
    g.SetFont("s10 bold", "Segoe UI")
    global stStateText := g.AddText("x+6 y" by+2 " w140 h28 +0x200", T("TXT_READY"))
    g.SetFont("s9 norm", "Segoe UI")

    global stStatus := g.AddText("x12 y" (UI_H_SIMPLE-26) " w616 h20 +0x200", T("TXT_STATUS_READY"))

    ; Module registry (for enable/disable gating)
    global UI_MODULES := Map()
    UI_MODULES["Main"] := [edLow, edHigh, btnLearn, chkAutoHide, btnAdvanced, btnSave]
    UI_MODULES["Advanced"] := [gbAdv, tabAdv, stRoiLblParent, btnParentSet, btnParentShow, stRoiLblF3, cbF3Order, cbF3Rois, cbF3RoiMode, btnF3Preview, btnF3Run, btnF3Borders, stF3RoiCount, stRoiLblHistory, cbParentHist, stParentHistCount, stAnchLblDia, cbDia, cbDiaMode, chkDiaScan, btnDiaAdd, btnDiaUpd, btnDiaDel, stAnchLblSca, cbSca, cbScaMode, chkScaScan, btnScaAdd, btnScaUpd, btnScaDel, stHistLblScan, cbScan, stHistHint, stHelp1]

    ; Populate UI data
    RefreshDiaCombo()
    RefreshScaCombo()
    SetModeCombos()
    SetF3OrderCombo()
    RefreshF3RoiCombo()
    RefreshScanCombo()
    RefreshParentHistCombo()
    SyncScanChecks()

    ; Initial state badge + enable policy
    UI_UpdateStateBadge()
    UI_ApplyEnablePolicy(true)

    ; Show (no-activate)
    g.Show("w" UI_W_SIMPLE " h" UI_H_SIMPLE " NA")

    ; Hide advanced by default
    UI_SetAdvancedVisible(false)

    ; PATCHABLE_ZONE_GUI_END
    ; ==================================================================================================
; ---------- GUI MODE / HOTSPOT ----------
    ; Tạo hotspot riêng để toggle GUI RUN/EDIT.
    ; RUN: g mờ + click-through (không chặn chuột)
    ; EDIT: g rõ nét + nhận chuột để chỉnh ROI
    InitGuiHotspot()
    SetGuiMode(GUI_MODE)

    ; ---------- Hotkeys ----------
    Hotkey("F1", (*) => ToggleRun())
    Hotkey("F2", (*) => F2Handler())
    Hotkey("F3", (*) => F3Handler())
    Hotkey("F4", (*) => F4_Queue(true))
    Hotkey("^F4", (*) => F4_Queue(false))

    ; ---------- F3 Overlay Order (direct on-screen) ----------
    ; F6: Toggle overlay | F8: Clear orders | F9: Run (can be changed in globals)
    try {
        InitF3OverlayHotkeys()
    } catch {
    }
    ; return   ; (removed) avoid #Warn unreachable definitions below. GUI+Hotkeys keep script running.

    ; =========================================================
    ; DPI Guard
    ; =========================================================
}

; -------------------------
; AUTO-EXEC
; -------------------------

Init()
return
