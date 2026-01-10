; ==================================================================================================
;  MODULE 15 — Action
;  Source lines (original scale.ahk): 6845 – 7340
; ==================================================================================================
F3OverlayShow() {
    global F3_ROI_LIST, F3_OVERLAY_GUI
    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0) {
        ; Auto-build ROI split from last F3 parent (history/INI) so "Show Borders" always has data.
        try {
            F3__BuildRoisFromLastParentForOverlay()
        } catch {
        }
    }
    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0) {
        SetStatus("Overlay: no ROIs yet. Press F3 to set Parent, then Show Borders.")
        return
    }
    F3OverlayEnsureGui()
    F3OverlayRebuild()
    try {
        F3_OVERLAY_GUI.Show("x0 y0 w" A_ScreenWidth " h" A_ScreenHeight " NA")
    } catch {
        try {
            F3_OVERLAY_GUI.Show()
        } catch {
        }
    }
    global F3_OVERLAY_VISIBLE := true
    SetStatus("Overlay ON: Click=nhập số | Drag=auto 1,2,3... | Right-click=clear ROI")
}

F3OverlayHide() {
    global F3_OVERLAY_GUI, F3_OVERLAY_VISIBLE
    try {
        if (IsObject(F3_OVERLAY_GUI))
            F3_OVERLAY_GUI.Hide()
    } catch {
    }
    F3_OVERLAY_VISIBLE := false
    SetStatus("Overlay OFF.")
}

F3OverlayEnsureGui() {
    global F3_OVERLAY_GUI, F3_OVERLAY_MSG_INSTALLED
    if (IsObject(F3_OVERLAY_GUI))
        return

    g := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20")
    g.MarginX := 0
    g.MarginY := 0
    ; nền tối nhẹ để thấy border/label (sẽ set transparency)
    g.BackColor := "010101"

    try {
        ; Show tiny first to avoid black flash before TransColor
        g.Show("x0 y0 w1 h1 NA")
    } catch {
        g.Show()
    }
    ; Không làm tối/đen màn hình: dùng TransColor để nền GUI trong suốt hoàn toàn.
    try {
        WinSetTransColor("010101 255", "ahk_id " g.Hwnd)
        try {
            Log("OVERLAY TransColor OK hwnd=" g.Hwnd, "DEBUG", "BORDER")
        } catch {
        }
    } catch as e {
        try {
            Log("OVERLAY TransColor FAIL hwnd=" g.Hwnd " err=" e.Message, "ERROR", "BORDER")
        } catch {
        }
    }
    ; Move to full screen after transparency setup (avoid desktop black bar)
    try {
        g.Move(0, 0, A_ScreenWidth, A_ScreenHeight)
    } catch {
    }
    F3_OVERLAY_GUI := g

    if (!F3_OVERLAY_MSG_INSTALLED) {
        ; Mouse messages (click/drag) cho overlay
        OnMessage(0x201, F3Overlay_WM_LBUTTONDOWN)   ; WM_LBUTTONDOWN
        OnMessage(0x200, F3Overlay_WM_MOUSEMOVE)     ; WM_MOUSEMOVE
        OnMessage(0x202, F3Overlay_WM_LBUTTONUP)     ; WM_LBUTTONUP
        OnMessage(0x205, F3Overlay_WM_RBUTTONUP)     ; WM_RBUTTONUP
        F3_OVERLAY_MSG_INSTALLED := true
    }
}

F3OverlayDestroyCtrls() {
    global F3_OVERLAY_CTRLS
    if (!IsObject(F3_OVERLAY_CTRLS))
        F3_OVERLAY_CTRLS := []

    for _, p in F3_OVERLAY_CTRLS {
        try {
            p["top"].Destroy()
        } catch {
        }
        try {
            p["bot"].Destroy()
        } catch {
        }
        try {
            p["lef"].Destroy()
        } catch {
        }
        try {
            p["rig"].Destroy()
        } catch {
        }
        try {
            p["lbl"].Destroy()
        } catch {
        }
    }
    F3_OVERLAY_CTRLS := []
}

F3OverlayRebuild() {
    global F3_OVERLAY_GUI, F3_ROI_LIST, F3_OVERLAY_CTRLS, F3_OVERLAY_NEXT, F3_ROI_PARENT_RECT
    if (!IsObject(F3_OVERLAY_GUI))
        return

    F3OverlayDestroyCtrls()

    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0)
        return

    ; next order = max(order)+1
    F3_OVERLAY_NEXT := F3OverlayComputeNext()

    thickness := 2
    for i, it in F3_ROI_LIST {
; --- FASTPATCH: convert rectRel -> screenRect using last parent rect (avoid relative-border offset) ---
if (IsObject(it) && it.Has("rectRel") && IsObject(F3_ROI_PARENT_RECT)) {
    rr := 0
    try {
        rr := it["rectRel"]
    } catch {
        rr := 0
    }
    if (IsObject(rr)) {
        try {
            sr := AL_RelToScreen(F3_ROI_PARENT_RECT, rr)
            if (IsObject(sr))
                it["screenRect"] := sr
        } catch as e {
            try {
                Log("OVERLAY RelToScreen FAIL i=" i " err=" e.Message, "ERROR", "BORDER")
            } catch {
            }
        }
    }
}
        if (!IsObject(it) || !it.Has("screenRect"))
            continue
        r := it["screenRect"]
        ; NOTE (anti-crash):
        ; screenRect đôi khi có thể bị lưu sai kiểu (Integer/Map/Array/String) do patch dài hoặc dữ liệu cũ.
        ; Tuyệt đối KHÔNG truy cập r.L/r.T/r.R/r.B trực tiếp (sẽ crash: "Integer has no property B").
        ; Luôn unpack bằng SC_RectUnpack_SAFE(...) để an toàn với mọi kiểu dữ liệu.
        L := 0, T := 0, R := 0, B := 0
        if (!SC_RectUnpack_SAFE(r, &L, &T, &R, &B))
            continue
; --- FASTPATCH: clamp to screen (avoid off-screen draw / black-bar artifacts) ---
L0 := L, T0 := T, R0 := R, B0 := B
if (L < 0)
    L := 0
if (T < 0)
    T := 0
if (R > A_ScreenWidth)
    R := A_ScreenWidth
if (B > A_ScreenHeight)
    B := A_ScreenHeight
if (L != L0 || T != T0 || R != R0 || B != B0) {
    try {
        Log("OVERLAY Clamp i=" i " from=" L0 "," T0 "," R0 "," B0 " to=" L "," T "," R "," B, "DEBUG", "BORDER")
    } catch {
    }
}
        W := Abs(R - L)
        H := Abs(B - T)
if (W < 2 || H < 2) {
    try {
        Log("OVERLAY Skip i=" i " invalidWH W=" W " H=" H " rect=" L "," T "," R "," B, "DEBUG", "BORDER")
    } catch {
    }
    continue
}

        ; 4 border lines
        top := F3_OVERLAY_GUI.AddText("x" L " y" T " w" W " h" thickness " BackgroundFF0000", "")
        bot := F3_OVERLAY_GUI.AddText("x" L " y" (B-thickness) " w" W " h" thickness " BackgroundFF0000", "")
        lef := F3_OVERLAY_GUI.AddText("x" L " y" T " w" thickness " h" H " BackgroundFF0000", "")
        rig := F3_OVERLAY_GUI.AddText("x" (R-thickness) " y" T " w" thickness " h" H " BackgroundFF0000", "")

        ; label (order number). Use SS_NOTIFY (+0x100) so Text can be clicked if needed.
        lbl := F3_OVERLAY_GUI.AddText("x" (L+2) " y" (T+2) " w60 h22 +0x100 BackgroundTrans cYellow", "")
        p := Map()
        p["top"] := top, p["bot"] := bot, p["lef"] := lef, p["rig"] := rig, p["lbl"] := lbl, p["idx"] := i
        F3_OVERLAY_CTRLS.Push(p)
    }

    F3OverlayUpdateLabels()
}

F3OverlayComputeNext() {
    global F3_ROI_LIST
    mx := 0
    if (!IsObject(F3_ROI_LIST))
        return 1
    for _, it in F3_ROI_LIST {
        try {
            if (it.Has("order") && it["order"] > mx)
                mx := it["order"]
        } catch {
        }
    }
    return mx + 1
}

F3OverlayUpdateLabels() {
    global F3_OVERLAY_CTRLS, F3_ROI_LIST, F3_OVERLAY_NEXT
    if (!IsObject(F3_OVERLAY_CTRLS) || !IsObject(F3_ROI_LIST))
        return

    ; keep next in sync
    F3_OVERLAY_NEXT := F3OverlayComputeNext()

    for _, p in F3_OVERLAY_CTRLS {
        idx := p["idx"]
        if (idx < 1 || idx > F3_ROI_LIST.Length)
            continue
        it := F3_ROI_LIST[idx]
        ord := 0
        md := 1
        ord := 0
        try {
            ord := it.Has("order") ? it["order"] : 0
        } catch {
            ord := 0
        }
        md := 1
        try {
            md := (it["mode"] = 2) ? 2 : 1
        } catch {
            md := 1
        }
        txt := ""
        if (ord > 0)
            txt := "" ord
        else
            txt := "(" idx ")"

        if (md = 2)
            txt .= "D"
        try {
            p["lbl"].Text := txt
        } catch {
        }
    }
}

F3OverlayClearAll() {
    global F3_ROI_LIST
    if (!IsObject(F3_ROI_LIST) || F3_ROI_LIST.Length = 0)
        return
    for _, it in F3_ROI_LIST {
        try {
            it["order"] := 0
        } catch {
        }
    }
    F3OverlayUpdateLabels()
    try {
        RefreshF3RoiCombo(F3_ROI_SELECTED)
    } catch {
    }
    SetStatus("Overlay: cleared all orders.")
}

F3OverlayAssign(idx, ord, mode := 0) {
    global F3_ROI_LIST
    if (!IsObject(F3_ROI_LIST) || idx < 1 || idx > F3_ROI_LIST.Length)
        return
    try {
        F3_ROI_LIST[idx]["order"] := ord
        if (mode = 2)
            F3_ROI_LIST[idx]["mode"] := 2
        else if (mode = 1)
            F3_ROI_LIST[idx]["mode"] := 1
    } catch {
    }
    F3OverlayUpdateLabels()
    try {
        RefreshF3RoiCombo(idx)
    } catch {
    }
}

F3OverlayClearOne(idx) {
    global F3_ROI_LIST
    if (!IsObject(F3_ROI_LIST) || idx < 1 || idx > F3_ROI_LIST.Length)
        return
    try {
        F3_ROI_LIST[idx]["order"] := 0
    } catch {
    }
    F3OverlayUpdateLabels()
    try {
        RefreshF3RoiCombo(idx)
    } catch {
    }
}

F3OverlayAssignNext(idx, mode := 0) {
    global F3_OVERLAY_NEXT
    ord := F3_OVERLAY_NEXT
    if (ord < 1)
        ord := 1
    F3OverlayAssign(idx, ord, mode)
    F3_OVERLAY_NEXT := F3OverlayComputeNext()
}

F3OverlayPromptOrder(idx) {
    global F3_ROI_LIST
    if (!IsObject(F3_ROI_LIST) || idx < 1 || idx > F3_ROI_LIST.Length)
        return

    cur := 0
    try {
        cur := F3_ROI_LIST[idx].Has("order") ? F3_ROI_LIST[idx]["order"] : 0
    } catch {
        cur := 0
    }
    ; Nhập số: 1..N. Mẹo: gõ "3d" để set DoubleClick cho ROI đó.
    ib := InputBox("Nhập thứ tự cho ROI #" idx " (vd: 1, 2, 3...).`nGõ 0 hoặc để trống để bỏ.`nGõ 'd' hậu tố (vd 3d) để set Double.", "Set ROI Order", "w360 h180", cur)
    if (ib.Result != "OK")
        return

    s := Trim(ib.Value)
    if (s = "") {
        F3OverlayClearOne(idx)
        return
    }

    isDouble := false
    if (RegExMatch(s, "i)d$")) {
        isDouble := true
        s := RegExReplace(s, "i)d$", "")
        s := Trim(s)
    }

    n := ToIntSafe(s, -1)
    if (n <= 0) {
        F3OverlayClearOne(idx)
        return
    }

    md := isDouble ? 2 : 1
    F3OverlayAssign(idx, n, md)
}

F3OverlayHitTest(x, y) {
    global F3_ROI_LIST
    if (!IsObject(F3_ROI_LIST))
        return 0
    for i, it in F3_ROI_LIST {
        if (!IsObject(it) || !it.Has("screenRect"))
            continue
        r := it["screenRect"]
        L := 0, T := 0, R := 0, B := 0
        if (!SC_RectUnpack_SAFE(r, &L, &T, &R, &B))
            continue
        if (x >= L && x <= R && y >= T && y <= B)
            return i
    }
    return 0
}


F3Overlay_IsOverlayHwnd(hwnd) {
    global F3_OVERLAY_GUI
    if (!IsObject(F3_OVERLAY_GUI))
        return false
    root := hwnd
    try {
        ; GA_ROOT = 2
        root := DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr")
    } catch {
        root := hwnd
    }
    return (root = F3_OVERLAY_GUI.Hwnd)
}


F3Overlay_WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global F3_GUI_SHOW_BORDERS
    if (F3_GUI_SHOW_BORDERS)
        return

    global F3_OVERLAY_GUI, F3_OVERLAY_VISIBLE, F3_OVERLAY_DRAG_IDX, F3_OVERLAY_DRAG_SX, F3_OVERLAY_DRAG_SY, F3_OVERLAY_DRAG_MOVED
    if (!F3_OVERLAY_VISIBLE || !IsObject(F3_OVERLAY_GUI))
        return
    if (!F3Overlay_IsOverlayHwnd(hwnd))
        return

    CoordMode("Mouse", "Screen")
    MouseGetPos &mx, &my
    idx := F3OverlayHitTest(mx, my)
    if (idx < 1)
        return

    F3_OVERLAY_DRAG_IDX := idx
    F3_OVERLAY_DRAG_SX := mx
    F3_OVERLAY_DRAG_SY := my
    F3_OVERLAY_DRAG_MOVED := false
}

F3Overlay_WM_MOUSEMOVE(wParam, lParam, msg, hwnd) {
    global F3_GUI_SHOW_BORDERS
    if (F3_GUI_SHOW_BORDERS)
        return

    global F3_OVERLAY_VISIBLE, F3_OVERLAY_GUI, F3_OVERLAY_DRAG_IDX, F3_OVERLAY_DRAG_SX, F3_OVERLAY_DRAG_SY, F3_OVERLAY_DRAG_MOVED, F3_OVERLAY_DRAG_THRESH
    if (!F3_OVERLAY_VISIBLE || !IsObject(F3_OVERLAY_GUI))
        return
    if (!F3Overlay_IsOverlayHwnd(hwnd))
        return
    if (F3_OVERLAY_DRAG_IDX < 1)
        return

    CoordMode("Mouse", "Screen")
    MouseGetPos &mx, &my
    dx := Abs(mx - F3_OVERLAY_DRAG_SX)
    dy := Abs(my - F3_OVERLAY_DRAG_SY)
    if (!F3_OVERLAY_DRAG_MOVED && (dx >= F3_OVERLAY_DRAG_THRESH || dy >= F3_OVERLAY_DRAG_THRESH)) {
        F3_OVERLAY_DRAG_MOVED := true
        ; highlight selected ROI while dragging
        try {
            F3__HighlightIndex(F3_OVERLAY_DRAG_IDX, 180)
        } catch {
        }
    }
}

F3Overlay_WM_LBUTTONUP(wParam, lParam, msg, hwnd) {
    global F3_GUI_SHOW_BORDERS
    if (F3_GUI_SHOW_BORDERS)
        return

    global F3_ROI_LIST
    global F3_OVERLAY_VISIBLE, F3_OVERLAY_GUI, F3_OVERLAY_DRAG_IDX, F3_OVERLAY_DRAG_MOVED
    if (!F3_OVERLAY_VISIBLE || !IsObject(F3_OVERLAY_GUI))
        return
    if (!F3Overlay_IsOverlayHwnd(hwnd))
        return

    idx := F3_OVERLAY_DRAG_IDX
    if (idx < 1)
        return

    ; If dragged -> auto-assign next order. If just click -> prompt input.
    ; Hold Shift while drag/click to set DoubleClick mode.
    isShift := GetKeyState("Shift", "P")
    md := isShift ? 2 : 1

    if (F3_OVERLAY_DRAG_MOVED) {
        F3OverlayAssignNext(idx, md)
        SetStatus("Overlay: drag assign ROI #" idx " -> order " (F3_ROI_LIST[idx].Has("order") ? F3_ROI_LIST[idx]["order"] : 0))
    } else {
        ; simple click -> input number
        F3OverlayPromptOrder(idx)
    }

    F3_OVERLAY_DRAG_IDX := 0
    F3_OVERLAY_DRAG_MOVED := false
}

F3Overlay_WM_RBUTTONUP(wParam, lParam, msg, hwnd) {
    global F3_GUI_SHOW_BORDERS
    if (F3_GUI_SHOW_BORDERS)
        return

    global F3_OVERLAY_VISIBLE, F3_OVERLAY_GUI
    if (!F3_OVERLAY_VISIBLE || !IsObject(F3_OVERLAY_GUI))
        return
    if (!F3Overlay_IsOverlayHwnd(hwnd))
        return

    CoordMode("Mouse", "Screen")
    MouseGetPos &mx, &my
    idx := F3OverlayHitTest(mx, my)
    if (idx < 1)
        return

    F3OverlayClearOne(idx)
    SetStatus("Overlay: cleared ROI #" idx)
}
