; ==================================================================================================
;  MODULE 14 — Action
;  Source lines (original scale.ahk): 6400 – 6844
; ==================================================================================================

; =========================================================
; F3 OVERLAY ORDER ENGINE (Direct on-screen ordering)
; =========================================================
; Mục tiêu:
;   - Vẽ border + số thứ tự ngay trên màn hình (overlay).
;   - Click vào icon/border -> nhập số thứ tự (order) cho ROI đó.
;   - Drag icon/border -> tự động gán order theo thứ tự bạn kéo (1,2,3...).
;   - Run sẽ click theo order thủ công nếu có (order>0), nếu không có thì dùng sort mode hiện tại.
;
; Lưu ý quan trọng (để tránh lỗi cú pháp khi ChatGPT vá):
;   - AHK v2: Arrays/Objects đã là "reference" -> không cần ByRef cho items.
;   - Tránh đặt tên biến là từ khóa: as, try, catch, class, global...
; =========================================================

global F3_OVERLAY_GUI := 0
global F3_OVERLAY_VISIBLE := false
global F3_GUI_SHOW_BORDERS := false   ; GUI button state: show/hide overlay borders
global gBorderShowAll := false   ; Show Border ALL ROI mode flag
global BORDER_ORDERINPUTS := Map()
global BORDER_ORDEROVERRIDE := Map()
global F3_OVERLAY_CTRLS := []          ; mỗi phần tử: Map("top",ctrl,"bot",ctrl,"lef",ctrl,"rig",ctrl,"lbl",ctrl)
global F3_OVERLAY_NEXT := 1

global F3_OVERLAY_DRAG_IDX := 0
global F3_OVERLAY_DRAG_SX := 0
global F3_OVERLAY_DRAG_SY := 0
global F3_OVERLAY_DRAG_MOVED := false
global F3_OVERLAY_DRAG_THRESH := 6

global F3_OVERLAY_MSG_INSTALLED := false

; --- Overlay runtime init (prevents "global variable has not been assigned" in AHK v2) ---
; NOTE for future patches (để ChatGPT vá không vỡ):
;   - AHK v2: đọc biến global chưa gán (dù chỉ trong if) sẽ nổ runtime.
;   - Vì vậy: mọi biến global overlay phải có giá trị mặc định ở đây.
global F3_OVERLAY_HK_INSTALLED := false
global F3_OVERLAY_LASTCLICK_TICK := 0
global F3_OVERLAY_DRAG := Map("down", false, "idx", 0, "x", 0, "y", 0)

; Hotkeys (tùy chọn). Nếu bị trùng phím, đổi sang "" để tắt.
global F3_OVERLAY_HK_TOGGLE := ""   ; bật/tắt overlay
global F3_OVERLAY_HK_CLEAR  := ""   ; clear toàn bộ order (order=0)
global F3_OVERLAY_HK_RUN    := ""   ; chạy click theo order (gọi F3RunSequence)
; NOTE: Overlay is controlled from GUI button "Show Borders". Hotkeys are disabled by default to avoid conflicts.

InitF3OverlayHotkeys() {
    global F3_OVERLAY_HK_TOGGLE, F3_OVERLAY_HK_CLEAR, F3_OVERLAY_HK_RUN
    try {
        if (F3_OVERLAY_HK_TOGGLE != "")
            Hotkey(F3_OVERLAY_HK_TOGGLE, (*) => F3OverlayToggle())
    } catch {
    }
    try {
        if (F3_OVERLAY_HK_CLEAR != "")
            Hotkey(F3_OVERLAY_HK_CLEAR, (*) => F3OverlayClearAll())
    } catch {
    }
    try {
        if (F3_OVERLAY_HK_RUN != "")
            Hotkey(F3_OVERLAY_HK_RUN, (*) => F3RunSequence())
    } catch {
    }
}

; ===============================
; GUI button: Show/Hide all ROI borders (Overlay)
; ===============================
F3GuiToggleBorders() {
    global F3_GUI_SHOW_BORDERS, btnF3Borders, gBorderShowAll

    ; MODE: ALL ROI SPLIT (multi borders). Do NOT draw parent here.
    if (!F3_GUI_SHOW_BORDERS) {
        ; turning ON
        try {
            Border_ClearLinesForce("toggle->ON")
        } catch {
        }
        ; ensure overlay GUI is hidden to avoid black bar
        try {
            F3OverlayHide()
        } catch {
        }
        F3_GUI_SHOW_BORDERS := true
        gBorderShowAll := true
        ; Toggle ON: chỉ clear vẽ, KHÔNG destroy OrderInput
        try {
            Log("ToggleBorders ON -> DrawOrderInputsAll", "DEBUG", "ORDER")
        } catch {
        }
        try {
            Border_DrawOrderInputsAll()
        } catch {
        }
        try {
            btnF3Borders.Text := "Hide Borders"
        } catch {
        }
        ; draw ALL ROI borders from F3_ROI_LIST (each ROI = its own GUI set)
        try {
            F3GuiDrawAllRoiBorders()
        } catch {
        }
        try {
            Border_DrawOrderInputsAll()
        } catch {
        }
        try {
            Border_BringOrderInputsToTop()
        } catch {
        }
        return
    }

    ; turning OFF
    F3_GUI_SHOW_BORDERS := false
    gBorderShowAll := false
    Border_DestroyAllOrderInputs()  ; leaving ALL-ROI mode -> destroy inputs
    try {
        btnF3Borders.Text := "Show Borders"
    } catch {
    }
    try {
        F3OverlayHide()
    } catch {
    }
    try {
        Border_ClearLinesForce("toggle->OFF")
    } catch {
    }
}

; ===============================
; Helpers: ensure borders/overlay ON and draw from GUI buttons
; ===============================
F3GuiEnsureBordersOn() {
    global F3_GUI_SHOW_BORDERS, btnF3Borders, gBorderShowAll
    if (F3_GUI_SHOW_BORDERS)
        return
    F3_GUI_SHOW_BORDERS := true
    gBorderShowAll := true

    try {
        btnF3Borders.Text := "Hide Borders"
    } catch {
    }
    try {
        F3OverlayInstallHotkeys()
    } catch {
    }
    try {
        F3OverlayShow()
    } catch {
    }

    ; Ensure->ON: clear vẽ rồi vẽ lại OrderInput + borders
    try {
        Border_ClearLinesForce("ensure->ON")
    } catch {
    }
    try {
        Border_DrawOrderInputsAll()
    } catch {
    }
    try {
        F3GuiDrawAllRoiBorders()
    } catch {
    }
    try {
        Border_DrawOrderInputsAll()
    } catch {
    }
    try {
        Border_BringOrderInputsToTop()
    } catch {
    }
}


F3GuiShowParentBorder() {
    global F3_GUI_SHOW_BORDERS, btnF3Borders
    global parentL, parentT, parentR, parentB

    ; MODE: PARENT only. Ensure multi-ROI overlay is OFF.
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
        Border_ClearLinesForce("parent")
    } catch {
    }

    L := 0, T := 0, R := 0, B := 0
    if (TryGetSelectedParentHist(&L, &T, &R, &B)) {
        UpdateBorderRect(L, T, R, B)
        try {
            Log("MODE=PARENT L=" L " T=" T " R=" R " B=" B, "DEBUG", "BORDER")
        } catch {
        }
        return
    }

    if (parentR > parentL && parentB > parentT) {
        UpdateBorderRect(parentL, parentT, parentR, parentB)
        try {
            Log("MODE=PARENT L=" parentL " T=" parentT " R=" parentR " B=" parentB, "DEBUG", "BORDER")
        } catch {
        }
        return
    }

    SetStatus("No parent region saved yet. Press F3 to set.")
    try {
        Log("MODE=PARENT no-parent", "DEBUG", "BORDER")
    } catch {
    }
}
; =====================================================================================
; Overlay hotkeys (click-through overlay). Double-click to set order, drag to swap/move.
; =====================================================================================
F3OverlayInstallHotkeys() {
    global F3_OVERLAY_HK_INSTALLED
    ; NOTE (để tránh lỗi như line 4916): AHK v2 sẽ crash nếu đọc global chưa gán.
    ; Vì vậy luôn dùng IsSet(...) khi check cờ, kể cả đã init mặc định ở phần globals.
    if (IsSet(F3_OVERLAY_HK_INSTALLED) && F3_OVERLAY_HK_INSTALLED)
        return
    F3_OVERLAY_HK_INSTALLED := true
    try {
        Hotkey("~LButton", F3Overlay_OnLButton, "On")
        Hotkey("~LButton Up", F3Overlay_OnLButtonUp, "On")
    } catch {
        ; ignore
    }
}

F3Overlay_OnLButton(*) {
    global F3_GUI_SHOW_BORDERS, F3_OVERLAY_DRAG, F3_OVERLAY_LASTCLICK_TICK, F3_ROI_LIST
    if (!F3_GUI_SHOW_BORDERS)
        return
    MouseGetPos &mx, &my
    idx := F3OverlayHitTest(mx, my)
    ; store drag start
    F3_OVERLAY_DRAG := Map("down", true, "idx", idx, "x", mx, "y", my)

    ; double-click assigns order
    isDbl := (A_PriorHotkey = "~LButton" && A_TimeSincePriorHotkey < 300)
    if (!isDbl)
        return
    if (idx <= 0)
        return

    it := F3_ROI_LIST[idx]
    cur := it.Has("order") ? it["order"] : 0
    ib := InputBox("Nhập số thứ tự click cho ROI này (1..99). Để trống = xoá.", "Set Order", cur)
    if (ib.Result != "OK")
        return
    val := Trim(ib.Value)
    if (val = "") {
        F3Overlay_SetOrderForIndex(idx, 0)
        return
    }
    if (!RegExMatch(val, "^\d+$"))
        return
    ord := Integer(val)
    if (ord < 0)
        ord := 0
    if (ord > 99)
        ord := 99
    F3Overlay_SetOrderForIndex(idx, ord)
}

F3Overlay_OnLButtonUp(*) {
    global F3_GUI_SHOW_BORDERS, F3_OVERLAY_DRAG
    if (!F3_GUI_SHOW_BORDERS)
        return
    if (!IsObject(F3_OVERLAY_DRAG) || !F3_OVERLAY_DRAG.Has("down") || !F3_OVERLAY_DRAG["down"])
        return
    MouseGetPos &mx, &my
    sx := F3_OVERLAY_DRAG["x"], sy := F3_OVERLAY_DRAG["y"], sidx := F3_OVERLAY_DRAG["idx"]
    F3_OVERLAY_DRAG["down"] := false

    if (sidx <= 0)
        return
    if (Abs(mx - sx) < 8 && Abs(my - sy) < 8)
        return

    tidx := F3OverlayHitTest(mx, my)
    if (tidx <= 0 || tidx = sidx)
        return

    F3Overlay_SwapOrMoveOrder(sidx, tidx)
}

F3Overlay_SetOrderForIndex(idx, ord) {
    global F3_ROI_LIST, F3_ROI_ORDER, F3_GUI_SHOW_BORDERS
    if (idx <= 0 || idx > F3_ROI_LIST.Length)
        return
    it := F3_ROI_LIST[idx]
    k := F3OverlayMakeKey(it)
    if (ord <= 0) {
        if (F3_ROI_ORDER.Has(k))
            F3_ROI_ORDER.Delete(k)
        it["order"] := 0
    } else {
        F3_ROI_ORDER[k] := ord
        it["order"] := ord
    }
    try {
        if (F3_GUI_SHOW_BORDERS)
            F3OverlayRebuild()
    } catch {
    }
    try {
        F3__RefreshRoiCombo()
    } catch {
    }
}

F3Overlay_SwapOrMoveOrder(aIdx, bIdx) {
    global F3_ROI_LIST
    if (aIdx <= 0 || bIdx <= 0)
        return
    a := F3_ROI_LIST[aIdx], b := F3_ROI_LIST[bIdx]
    oa := a.Has("order") ? a["order"] : 0
    ob := b.Has("order") ? b["order"] : 0

    ; If one side has an order, move it. If both have orders, swap.
    if (oa > 0 && ob = 0) {
        F3Overlay_SetOrderForIndex(bIdx, oa)
        F3Overlay_SetOrderForIndex(aIdx, 0)
        return
    }
    if (oa = 0 && ob > 0) {
        F3Overlay_SetOrderForIndex(aIdx, ob)
        F3Overlay_SetOrderForIndex(bIdx, 0)
        return
    }
    if (oa > 0 && ob > 0) {
        F3Overlay_SetOrderForIndex(aIdx, ob)
        F3Overlay_SetOrderForIndex(bIdx, oa)
        return
    }
}




F3OverlayToggle() {
    global F3_OVERLAY_VISIBLE
    if (F3_OVERLAY_VISIBLE)
        F3OverlayHide()
    else
        F3OverlayShow()
}


F3__BuildRoisFromLastParentForOverlay() {
    global F3_ROI_LIST, F3_SORT_MODE, F3_MULTI_ICON
    global AL_MULTI_MIN_W, AL_MULTI_MIN_H, AL_MULTI_MIN_CELLS, AL_MULTI_DILATE, AL_MULTI_DISABLE_NMS
    global AL_MULTI_RELAX_L3, AL_MULTI_H_TRANS_MAX, AL_MULTI_ALLOW_TEXTSTRIP
    global parentL, parentT, parentR, parentB

    ; Source of truth: selected history -> fallback to current parent globals
    L := 0, T := 0, R := 0, B := 0
    if (!TryGetSelectedParentHist(&L, &T, &R, &B)) {
        L := parentL, T := parentT, R := parentR, B := parentB
    }
    if (!(R > L && B > T)) {
        F3_ROI_LIST := []
        return false
    }

    rect := Rect(L, T, R, B)
    opts := AL_DefaultOpts()

    ; Multi-icon friendly opts (ROI split preview)
    if (F3_MULTI_ICON) {
                try {
            opts["minW"] := AL_MULTI_MIN_W
        } catch {
        }
                try {
            opts["minH"] := AL_MULTI_MIN_H
        } catch {
        }
                try {
            opts["minCells"] := AL_MULTI_MIN_CELLS
        } catch {
        }
                try {
            opts["dilate"] := AL_MULTI_DILATE
        } catch {
        }
        try {
            if (AL_MULTI_DISABLE_NMS)
                opts["nmsIou"] := 0.99
        } catch {
        }
                try {
            opts["allowTextStrip"] := AL_MULTI_ALLOW_TEXTSTRIP
        } catch {
        }
        try {
            if (AL_MULTI_RELAX_L3)
                opts["textTransHigh"] := AL_MULTI_H_TRANS_MAX
        } catch {
        }
    }

    ctx := ParentContext(rect, "", Map("dpi", A_ScreenDPI, "ts", A_Now))
    cands := []
    filt := []

    try {
        cands := AL_L2_Segment(ctx, opts)
    } catch {
        cands := []
    }

    try {
        filt := AL_L3_Filter(ctx, cands, opts)
    } catch {
        filt := []
    }

    try {
        F3__ApplyOrderFromF4(rect, filt)
    } catch {
        F3_ROI_LIST := []
    }

    return (IsObject(F3_ROI_LIST) && F3_ROI_LIST.Length > 0)
}


