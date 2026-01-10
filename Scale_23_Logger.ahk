; ==================================================================================================
;  MODULE 23 — Logger
;  Source lines (original scale.ahk): 10720 – 11232
; ==================================================================================================
AL_L4_Extract(parentCtx, filtered, store := 0, opts := 0) {
    ; Input: ParentContext + Filtered[]
    ; Output: ElementModel (template + anchors)

    if (!IsObject(opts))
        opts := AL_DefaultOpts()

    if (!IsObject(filtered) || filtered.Length = 0)
        return 0

    best := filtered[1]
    rel := best.rectRel
    parent := parentCtx.rect
    screenRect := AL_RelToScreen(parent, rel)

    id := "elem_" FormatTime(A_Now, "yyyyMMdd_HHmmss")

    ; 4.1 crop template (no refactor): HWND = capture FULL parent -> parent.bmp -> crop rectRel -> tpl_elem.bmp
    tplPath := ""

    pad := opts["templatePad"]

    ; determine HWND FIRST
    capHwnd := 0
    try {
        if (IsObject(parentCtx) && IsObject(parentCtx.meta) && parentCtx.meta.Has("hwnd")) {
            capHwnd := parentCtx.meta["hwnd"]
        }
    } catch {
        capHwnd := 0
    }


; ===== FAST MODE GATE: bypass CAP DECIDE + parent capture =====
global CAP_FAST_MODE, AL_FAST_MODE, PIPE_MODE
if (capHwnd && (CAP_FAST_MODE || AL_FAST_MODE || PIPE_MODE = "F4")) {
    CAP_Log("FAST MODE | bypass CAP DECIDE + parent capture → use SCREEN template capture (ROI-only)")
    capHwnd := 0
}

    if (capHwnd) {
        parentDxgiPath := A_ScriptDir "\parent_dxgi.bmp"  ; DXGI map (RECT only)
        parentBmpPath := A_ScriptDir "\parent_gdi.bmp"    ; GDI/PrintWindow image (looks like screen)
        ; ⚠️ DEBUG: KHÔNG ghi đè template. Mỗi lần F3/F4 (khi save) tạo 1 file tpl_* mới.
        tplPath := DBG__MakeUniqueBmpPath("tpl_elem")

        ; 1) CAPTURE FULL parent -> parent.bmp (single source)
        okDxgi := false
        okGdi := false

        ; IDOL LAYER: Browser/App UI -> prefer PrintWindow; Desktop/Game -> prefer DXGI.
        targetType := "APP"
        capMethod2 := "DXGI"
        pwHwnd := capHwnd

        ; ===== IDOL CAP DECISION STATE (no refactor) =====
        renderLayer := "UI"
        capMethod := ""
        capReason := ""
        blackFrameReason := ""
        captureSource := ""
        capSrcMode := "HWND"
        guiVisible := 0
        printFlags := 0x00000002
        dxgiBmp := ""
        alphaChannel := ""
        outputBitDepth := 0
        try {
            global g
            if (IsObject(g) && g.Hwnd)
                guiVisible := CAP_IsWindowVisible(g.Hwnd) ? 1 : 0
        } catch {
            guiVisible := 0
        }
        useDXGI := (capMethod2 = "DXGI") ? 1 : 0
        global CAP_HIDE_GUI, CAP_FAST_MODE

        if (guiVisible && !CAP_HIDE_GUI && !CAP_FAST_MODE) {
            CAP_Log("BLACK FRAME | GUI overlay present", "WARN")
            CAP_Log("CAP DECIDE | GUI visible → forbid DXGI (GLOBAL)", "WARN")
            useDXGI := 0
            useDXGI_SCREEN := 0 ; nếu có biến riêng cho SCREEN
        }

        if (!useDXGI && capMethod2 = "DXGI")
            capMethod2 := "PRINTWINDOW"

        try {
            targetType := CAP_DetectTargetType(capHwnd)
        } catch {
            targetType := "APP"
        }

        if (targetType = "BROWSER") {
            capMethod2 := "PRINTWINDOW"
        }

        ; ----- IDOL DECIDE (mandatory logs) -----
        if (targetType = "BROWSER")
            renderLayer := "GPU"
        else if (targetType = "GAME")
            renderLayer := "GPU"
        else
            renderLayer := "UI"

        CAP_Log("CAP DECIDE | targetType=" targetType)
        CAP_Log("CAP DECIDE | renderLayer=" renderLayer)

        capMethod := capMethod2
        if (capMethod = "PRINTWINDOW") {
            capReason := "Browser → avoid DXGI"
        } else if (targetType = "GAME") {
            capReason := "Game detected → prefer DXGI"
        } else {
            capReason := "Desktop/App → prefer DXGI"
        }

        CAP_Log("CAP MODE | " capSrcMode)
        CAP_Log("CAP METHOD | use=" capMethod)
        CAP_Log("CAP REASON | " capReason)


        try {
            pwHwnd := CAP_GetBestPrintWindowHwnd(capHwnd)
        } catch {
            pwHwnd := capHwnd
        }

        if (capMethod2 = "PRINTWINDOW") {
            ; Browser: PrintWindow on best render HWND; avoid DXGI black frames.
            try {
                okGdi := AL_Capture_RectToBMP(
                    parent,
                    parentBmpPath,
                    Map(
                        "caller","AL_L4_ParentCapture_PW",
                        "srcMode","HWND",
                        "hwnd",pwHwnd,
                        "method","PrintWindow"
                    )
                )
            } catch {
                okGdi := false
            }

            if (!okGdi) {
                ; Last resort: SCREEN capture (may include occlusion)

                capSrcMode := "SCREEN"
                CAP_Log("CAP MODE | SCREEN")
                try {
                    okGdi := AL_Capture_RectToBMP(
                        parent,
                        parentBmpPath,
                        Map(
                            "caller","AL_L4_ParentCapture_SCREEN",
                            "srcMode","SCREEN",
                            "hwnd",0,
                            "useDXGI",useDXGI
                        )
                    )
                } catch {
                    okGdi := false
                }
            }
        } else {
        ; 1) DXGI capture FULL parent -> parent_dxgi.bmp (flatten alpha inside)
            okDxgi := false
            try {
                okDxgi := AL_Capture_RectToBMP(
                    parent,
                    parentDxgiPath,
                    Map(
                        "caller","AL_L4_ParentCapture_DXGI",
                        "srcMode","HWND",
                        "hwnd",capHwnd
                    )
                )
            } catch {
                okDxgi := false
            }

            ; 2) GDI/PrintWindow capture parent rect -> parent_gdi.bmp (normal-looking)
            okGdi := false

            ; FLOWLOCK (no refactor): when DXGI ok, STOP here — do not call GDI or SCREEN.
            ; Use DXGI output as the parent image for template crop.
            if (okDxgi) {
                okGdi := true
                parentBmpPath := parentDxgiPath

                ; ----- DXGI PROBE (black/alpha reasons) -----
                dxgiBmp := parentDxgiPath
                bpp0 := 0
                if (SC_BmpGetBitCount(parentDxgiPath, &bpp0)) {
                    if (bpp0 != 24)
                        CAP_Log("WARN | 32bit alpha BMP detected", "WARN")
                }
                a0 := 0, rgb0 := 0
                if (SC_BmpProbeAlphaAndBlack(parentDxgiPath, &a0, &rgb0)) {
                    if (targetType = "BROWSER")
                        CAP_Log("BLACK FRAME | DXGI used on Browser", "WARN")
                    if (rgb0)
                        CAP_Log("BLACK FRAME | DXGI cannot see UI layer", "ERROR")
                    if (a0) {
                        alphaChannel := "0"
                        CAP_Log("BLACK FRAME | DXGI alpha=0", "WARN")
                    } else {
                        alphaChannel := "OK"
                    }
                }
                ; FORCE opaque 24-bit so the saved parent image is "normal-looking" (no alpha=0 black preview)
                try {
                    SC_BmpFlattenTo24(parentDxgiPath, true)
                } catch {
                }
            } else {
                ; DXGI failed → fallback chain: PrintWindow (HWND) → SCREEN (DXGI)
                try {
                    okGdi := AL_Capture_RectToBMP(
                        parent,
                        parentBmpPath,
                        Map(
                            "caller","AL_L4_ParentCapture_GDI",
                            "srcMode","HWND",
                            "hwnd",capHwnd,
                            "method","PrintWindow"
                        )
                    )
                } catch {
                    okGdi := false
                }

                ; ----- IDOL CAP OUTPUT (mandatory logs) -----
                if (okGdi) {
                    try {
                        captureSource := RegExReplace(parentBmpPath, "^.*\\", "")
                    } catch {
                        captureSource := parentBmpPath
                    }
                    CAP_Log("CAP SOURCE | " captureSource)

                    bpp2 := 0
                    if (SC_BmpGetBitCount(parentBmpPath, &bpp2)) {
                        outputBitDepth := bpp2
                        if (bpp2 != 24)
                            CAP_Log("WARN | 32bit alpha BMP detected", "WARN")
                    }

                    CAP_Log("CAP END | success")
                } else {
                    CAP_Log("CAP END | fail", "ERROR")
                }

                if (!okGdi) {
                    try {
                        okGdi := AL_Capture_RectToBMP(
                            parent,
                            parentBmpPath,
                            Map(
                                "caller","AL_L4_ParentCapture_SCREEN",
                                "srcMode","SCREEN",
                                "hwnd",0
                            )
                        )
                    } catch {
                        okGdi := false
                    }
                }
            }

        }

    ; 3) crop parent.bmp by rectRel (+pad) -> tpl_elem.bmp (template final)
    ; IDOL STANDARD: crop from the SAME captured file (no extra capture; no baseBmp; no hGraphics).
    ; We crop at file-level and output an opaque 24-bit BMP so the template is always "normal-looking".
        okTpl := false
        ; Ensure parent image is opaque 24-bit before cropping template (prevents black preview / alpha issues)
        if (okGdi && FileExist(parentBmpPath)) {
            try {
                SC_BmpFlattenTo24(parentBmpPath, true)
            } catch {
            }
        }

        if (okGdi && FileExist(parentBmpPath)) {
            try {
                bw := 0, bh := 0
                if (SC_BmpGetSize(parentBmpPath, &bw, &bh)) {
                    x := Max(0, rel.L - pad)
                    y := Max(0, rel.T - pad)
                    cw := Min(bw - x, ((rel.R - rel.L) + 1) + pad*2)  ; +1 để tránh cắt thiếu 1px (inclusive R/B)
                    ch := Min(bh - y, ((rel.B - rel.T) + 1) + pad*2)  ; +1 để tránh cắt thiếu 1px (inclusive R/B)

                    if (cw > 0 && ch > 0)
                        okTpl := SC_BmpCropFile(parentBmpPath, tplPath, x, y, cw, ch, true)
                }
            } catch {
                okTpl := false
            }
        }

        if (!okTpl)
            tplPath := ""

; ===============================
; MULTI-ICON EXPORT (HWND parent): crop extra candidates from SAME parentBmpPath
; ===============================
; - Không capture lại parent nhiều lần (nhanh)
; - Mỗi ROI → 1 file tpl_elem_2, tpl_elem_3...
global F3_MULTI_ICON, AL_MULTI_SAVE_EACH
if (F3_MULTI_ICON && AL_MULTI_SAVE_EACH && IsObject(filtered) && filtered.Length > 1) {
    try {
        if (okGdi && FileExist(parentBmpPath)) {
            bw := 0, bh := 0
            if (SC_BmpGetSize(parentBmpPath, &bw, &bh)) {
                dupIouThr := (IsObject(opts) && opts.Has("multiDupIou")) ? opts["multiDupIou"] : 0.92
                savedRects := [rel]  ; winner rectRel đã lưu ở tpl_elem.bmp

                ; ---- MULTI DUP GUARD ----
                ; Nếu L2/L3 trả ra nhiều rect chồng gần như y hệt cho CÙNG 1 icon,
                ; việc export nhiều tpl sẽ nhìn như "cắt chồng crop" (roi#1 -> roi#2).
                ; Chặn bằng IoU để mỗi icon chỉ ra 1 tpl (KHÔNG đụng thuật toán detect).
                Loop filtered.Length {
                    if (A_Index = 1)
                        continue
                    rel2 := filtered[A_Index].rectRel

                    ; ---- MULTI CONTAINMENT GUARD ----
                    ; Trường hợp L2/L3 đôi khi giữ lại 1 rect nhỏ nằm "lọt" trong rect winner (artifact/đốm),
                    ; export sẽ nhìn giống như "cắt chồng crop" (roi#1 rồi lại cắt 1 phần của roi#1).
                    ; Giữ nguyên thuật toán detect: chỉ skip khi rect nhỏ gần như nằm hoàn toàn trong winner.
                    containThr := (IsObject(opts) && opts.Has("multiContainThr")) ? opts["multiContainThr"] : 0.95
                    areaFracMax := (IsObject(opts) && opts.Has("multiContainAreaFracMax")) ? opts["multiContainAreaFracMax"] : 0.35
                    interW := Max(0, Min(rel2.R, rel.R) - Max(rel2.L, rel.L))
                    interH := Max(0, Min(rel2.B, rel.B) - Max(rel2.T, rel.T))
                    interA := interW * interH
                    a2 := rel2.W * rel2.H
                    aW := rel.W * rel.H
                    contain := (a2 > 0) ? (interA / a2) : 0
                    if (contain >= containThr && a2 <= (aW * areaFracMax)) {
                        CAP_Log("MULTI | SKIP INSIDE WINNER idx=" A_Index " contain=" Round(contain,3) " area=" a2, "WARN")
                        continue
                    }

                    isDup := false
                    for _, rr in savedRects {
                        ; containment first
                        if (AL_RectInside(rel2, rr, 0.92, 0.45)) {
                            isDup := true
                            break
                        }
                        if (AL_IoU(rel2, rr) >= dupIouThr) {
                            isDup := true
                            break
                        }
                    }
                    if (isDup) {
                        CAP_Log("MULTI | SKIP DUP idx=" A_Index " (IoU>=" dupIouThr ")", "WARN")
                        continue
                    }

                    tpl2 := DBG__MakeUniqueBmpPath("tpl_elem_" A_Index)
                    x2 := Max(0, rel2.L - pad)
                    y2 := Max(0, rel2.T - pad)
                    cw2 := Min(bw - x2, ((rel2.R - rel2.L) + 1) + pad*2)  ; +1 inclusive
                    ch2 := Min(bh - y2, ((rel2.B - rel2.T) + 1) + pad*2)  ; +1 inclusive
                    if (cw2 > 0 && ch2 > 0) {
                        ok2 := SC_BmpCropFile(parentBmpPath, tpl2, x2, y2, cw2, ch2, true)
                        if (ok2) {
                            CAP_Log("MULTI | SAVE tpl idx=" A_Index " -> " tpl2)
                            savedRects.Push(rel2)
                        } else
                            CAP_Log("MULTI | FAIL tpl idx=" A_Index, "WARN")
                    } else {
                        CAP_Log("MULTI | SKIP tpl idx=" A_Index " (bad crop size)", "WARN")
                    }
                }
            }
        }
    } catch {
    }
}
    } else {
        cropRect := AL_ExpandRect(screenRect, pad)

        ; CAPTURE (Screen)
        tplPath := ""
        try {
            ; FAST MODE: vẫn có ảnh để soi ROI, nhưng phải THROTTLE (mỗi N vòng) để giữ tốc độ.
            ; - Khi KHÔNG tới lượt save: giữ tplPath = ảnh lần trước (đã tồn tại), không capture+save nữa.
            global PIPE_MODE, DBG_LAST_TPL_PATH, g_F4_Index
            doSaveTpl := DBG__ShouldSaveTpl(PIPE_MODE)

            ; đảm bảo lần đầu luôn có 1 ảnh tồn tại
            if (!doSaveTpl && DBG_LAST_TPL_PATH = "")
                doSaveTpl := true

            if (doSaveTpl) {
                if (PIPE_MODE = "F4") {
                tplPath := DBG__MakeUniqueBmpPath("f4_" Format("{:03}", g_F4_Index))
            } else {
                tplPath := DBG__MakeUniqueBmpPath("tpl_elem")
            }
                if (!AL_Capture_RectToBMP(
                        cropRect,
                        tplPath,
                        Map(
                            "caller","AL_L4_TemplateCapture",
                            "srcMode","Screen",
                            "hwnd",0
                        )))
                    tplPath := ""
                else
                    DBG_LAST_TPL_PATH := tplPath
            } else {
                tplPath := DBG_LAST_TPL_PATH
                CAP_Log("FAST MODE | throttle skip tpl_elem SAVE (reuse last)")
            }
        } catch {
            tplPath := ""
        }
    }

; ===============================
; MULTI-ICON EXPORT (SCREEN parent): capture each ROI cropRect separately
; ===============================
global F3_MULTI_ICON, AL_MULTI_SAVE_EACH
if (F3_MULTI_ICON && AL_MULTI_SAVE_EACH && IsObject(filtered) && filtered.Length > 1) {
    try {
        dupIouThr := (IsObject(opts) && opts.Has("multiDupIou")) ? opts["multiDupIou"] : 0.92
        savedRects := [rel]
        ; MULTI DUP GUARD: skip near-duplicate rects so không sinh "cắt lại lần nữa" cho cùng 1 icon.
        Loop filtered.Length {
            if (A_Index = 1)
                continue
            rel2 := filtered[A_Index].rectRel
            isDup := false
            for _, rr in savedRects {
                if (AL_IoU(rel2, rr) >= dupIouThr) {
                    isDup := true
                    break
                }
            }
            if (isDup) {
                CAP_Log("MULTI | SKIP DUP idx=" A_Index " (IoU>=" dupIouThr ")", "WARN")
                continue
            }

            sr2 := AL_RelToScreen(parent, rel2)
            cr2 := AL_ExpandRect(sr2, pad)
            tpl2 := DBG__MakeUniqueBmpPath("tpl_elem_" A_Index)
            ok2 := AL_Capture_RectToBMP(
                cr2,
                tpl2,
                Map(
                    "caller","AL_L4_TemplateCapture_MULTI",
                    "srcMode","Screen",
                    "hwnd",0
                )
            )
            if (ok2) {
                CAP_Log("MULTI | SAVE tpl idx=" A_Index " -> " tpl2)
                savedRects.Push(rel2)
            } else
                CAP_Log("MULTI | FAIL tpl idx=" A_Index, "WARN")
        }
    } catch {
    }
}
    ; 4.2 pick anchors (non-ML): choose K points with high local contrast
    ; NOTE: PixelGetColor loop can be extremely slow on some systems (multi-second).
    ; FAST MODE: skip anchor picking to keep F4/learning responsive.
    global AL_FAST_MODE, CAP_FAST_MODE
    anchors := []
    try {
        if (!AL_FAST_MODE && !CAP_FAST_MODE) {
            anchors := AL_PickAnchors(parentCtx, rel, opts["anchorsK"], opts["anchorTol"])
        } else {
            anchors := []
        }
    } catch {
        anchors := []
    }

    model := ElementModel(id, rel, tplPath, anchors, Map("score", best.score))

    ; Optional persist
    if (IsObject(store)) {
        try {
            store.Write("element", "id", id)
            store.Write("element", "template", tplPath)
            store.Write("element", "rectL", rel.L)
            store.Write("element", "rectT", rel.T)
            store.Write("element", "rectR", rel.R)
            store.Write("element", "rectB", rel.B)
            store.Write("element", "anchorCount", anchors.Length)
            for i, a in anchors {
                store.Write("anchor" i, "dx", a["dx"])
                store.Write("anchor" i, "dy", a["dy"])
                store.Write("anchor" i, "rgb", Format("0x{:06X}", a["rgb"]))
                store.Write("anchor" i, "tol", a["tol"])
            }
        } catch {
        }
    }
    return model
}


; ============================================================
; Layer 5 - State / Behavior Learning
; ============================================================
