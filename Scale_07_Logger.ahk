; ==================================================================================================
;  MODULE 07 — Logger
;  Source lines (original scale.ahk): 2959 – 3558
; ==================================================================================================

AL_GdipBitmapFromHWNDBitBlt(hwnd, r, cap := 0) {
    ; Minimal HWND BitBlt capture (WindowDC). r is Rect in SCREEN coords (LTRB).
    capId := ""
    debug := false
    try {
        if (IsObject(cap)) {
            if (cap.Has("id"))
                capId := cap["id"]
            if (cap.Has("debug"))
                debug := cap["debug"]
            cap["lastStage"] := "COPY"
            cap["fail"] := ""
            cap["winErr"] := 0
        }
    } catch {
    }

    if (capId = "")
        capId := "NA"

    L := 0, T := 0, R := 0, B := 0
    try {
        L := r.L, T := r.T, R := r.R, B := r.B
    } catch {
        return 0
    }
    W := R - L, H := B - T
    if (W <= 0 || H <= 0)
        return 0

    wx := 0, wy := 0, wr := 0, wb := 0
    try {
        winRect := Buffer(16, 0)
        if (!DllCall("user32.dll\GetWindowRect", "ptr", hwnd, "ptr", winRect, "int"))
            return 0
        wx := NumGet(winRect, 0, "int")
        wy := NumGet(winRect, 4, "int")
        wr := NumGet(winRect, 8, "int")
        wb := NumGet(winRect, 12, "int")
    } catch {
        return 0
    }

    xSrc := L - wx
    ySrc := T - wy

    hdcWin := 0
    hdcMem := 0
    hbm := 0
    obm := 0
    pBitmap := 0
    tCopy := A_TickCount

    try {
        hdcOwner := hwnd
hdcWin := DllCall("user32.dll\GetWindowDC", "ptr", hwnd, "ptr")
if (!hdcWin)
    hdcWin := DllCall("user32.dll\GetDC", "ptr", hwnd, "ptr")
if (!hdcWin) {
    hdcOwner := 0
    hdcWin := DllCall("user32.dll\GetDC", "ptr", 0, "ptr")
}

if (!hdcWin) {
            if (IsObject(cap)) {
                cap["fail"] := "GetWindowDC/GetDC=0"
                cap["winErr"] := A_LastError
                cap["method"] := "BitBlt(ScreenDC)"
            }

            if (debug)
                CAP_KV("COPY FAIL", capId, Format("method=BitBlt(ScreenDC) winErr={} msg=NoWindowDC hwnd=0x{}", A_LastError, Format("{:X}", hwnd+0)), "ERROR")
            return 0
        }

        hdcMem := DllCall("gdi32.dll\CreateCompatibleDC", "ptr", hdcWin, "ptr")
        if (!hdcMem) {
            if (IsObject(cap)) {
                cap["fail"] := "CreateCompatibleDC=0"
                cap["winErr"] := A_LastError
                cap["method"] := "BitBlt(ScreenDC)"
            }
            return 0
        }

        hbm := DllCall("gdi32.dll\CreateCompatibleBitmap", "ptr", hdcWin, "int", W, "int", H, "ptr")
        if (!hbm) {
            if (IsObject(cap)) {
                cap["fail"] := "CreateCompatibleBitmap=0"
                cap["winErr"] := A_LastError
                cap["method"] := "BitBlt(ScreenDC)"
            }
            return 0
        }

        obm := DllCall("gdi32.dll\SelectObject", "ptr", hdcMem, "ptr", hbm, "ptr")
        if (!obm) {
            if (IsObject(cap)) {
                cap["fail"] := "SelectObject=0"
                cap["winErr"] := A_LastError
                cap["method"] := "BitBlt(ScreenDC)"
            }
            return 0
        }

        rop := 0x00CC0020 | 0x40000000  ; SRCCOPY | CAPTUREBLT
        ok := DllCall("gdi32.dll\BitBlt"
            , "ptr", hdcMem
            , "int", 0, "int", 0, "int", W, "int", H
            , "ptr", hdcWin
            , "int", xSrc, "int", ySrc
            , "uint", rop
            , "int")

        if (IsObject(cap))
            cap["method"] := "BitBlt(ScreenDC)"

        ; Convert HBITMAP -> GDI+ Bitmap (may return 0 without throwing)
        try {
            pBitmap := Gdip_CreateBitmapFromHBITMAP(hbm)
        } catch as e {
            pBitmap := 0
            if (IsObject(cap))
                cap["fail"] := "CreateBitmapFromHBITMAP ex: " e.Message
        }

        if (!pBitmap && IsObject(cap) && cap["fail"] = "")
            cap["fail"] := "CreateBitmapFromHBITMAP=0"

        dur := A_TickCount - tCopy
        if (IsObject(cap))
            cap["copyMs"] := dur

        if (debug) {
            if (pBitmap)
                CAP_KV("COPY", capId, Format("method=BitBlt(ScreenDC) ok=1 duration={}ms", dur))
            else
                CAP_KV("COPY FAIL", capId, Format("method=BitBlt(ScreenDC) ok=0 duration={}ms winErr={} msg={}", dur, (IsObject(cap) && cap.Has("winErr") ? cap["winErr"] : 0), (IsObject(cap) && cap.Has("fail") ? cap["fail"] : "BitBlt=0")), "ERROR")
        }

        return pBitmap
    } catch as e {
        if (IsObject(cap)) {
            cap["fail"] := "Exception: " e.Message
            cap["winErr"] := A_LastError
            cap["method"] := "BitBlt(ScreenDC)"
        }

        if (debug)
            CAP_KV("COPY FAIL", capId, Format("method=BitBlt(ScreenDC) winErr={} msg={}", A_LastError, e.Message), "ERROR")
        return 0
    } finally {
        if (hdcMem && obm)
            DllCall("gdi32.dll\SelectObject", "ptr", hdcMem, "ptr", obm)
        if (hbm)
            DllCall("gdi32.dll\DeleteObject", "ptr", hbm)
        if (hdcMem)
            DllCall("gdi32.dll\DeleteDC", "ptr", hdcMem)
        if (hdcWin)
            DllCall("user32.dll\ReleaseDC", "ptr", 0, "ptr", hdcWin)
    }
}



AL_Capture_RectToBMP(screenRect, outPath, opt := 0) {
    ; Returns true/false. Logs the full CAPTURE DEBUG MASTER checklist when enabled.
    global CAP_DEBUG, CAP_DEBUG_DEEP, GdipToken

    ; ---- Options (caller/srcMode/hwnd/debug/deep/id) ----
    caller := ""
    srcMode := "SCREEN"
    hwnd := 0
    method := ""
    useDXGI := CAP_USE_DXGI
    debug := CAP_DEBUG
    deep := CAP_DEBUG_DEEP
    capId := ""

    if (IsObject(opt)) {
        try {
            if (opt.Has("caller"))
                caller := opt["caller"]
            if (opt.Has("srcMode") && opt["srcMode"] != "")
                srcMode := opt["srcMode"]
            if (opt.Has("hwnd"))
                hwnd := opt["hwnd"]
            if (opt.Has("method") && opt["method"] != "")
                method := opt["method"]
            if (opt.Has("useDXGI"))
                useDXGI := opt["useDXGI"]
            if (opt.Has("debug"))
                debug := opt["debug"]
            if (opt.Has("deep"))
                deep := opt["deep"]
            if (opt.Has("id"))
                capId := opt["id"]
        } catch {
        }
    }
    ; normalize srcMode (avoid shadow/blank overrides)
    srcMode := StrUpper(Trim(srcMode))
    if (srcMode = "")
        srcMode := "SCREEN"
; FAST MODE override (F4): force SCREEN ROI-only, avoid PrintWindow/DXGI paths
global CAP_FAST_MODE
if (CAP_FAST_MODE) {
    srcMode := "SCREEN"
    hwnd := 0
    useDXGI := 0
    method := "AUTO"
}



    method := StrUpper(Trim(method))
    if (capId = "")
        capId := Format("{}_{}", FormatTime(A_Now, "yyyyMMdd_HHmmss"), A_TickCount)

    tStart := A_TickCount
    stage := "INIT"
    pBitmap := 0
    gdiMs := 0
    copyMs := 0
    saveMs := 0
    normalized := 0

    ; for DPI/desktop logging
    vx := 0, vy := 0, vw := 0, vh := 0
    sysDpi := 0, winDpi := 0, scale := 1.0
    monIdx := 0, monTotal := 0

    try {
        ; =========================
        ; 1) ENTRY / RECT EXTRACT
        ; =========================
        stage := "VALID"
        
        L := 0, T := 0, R := 0, B := 0
        if (!SC_RectUnpack_SAFE(screenRect, &L, &T, &R, &B)) {
            if (debug) {
                CAP_KV("START", capId, Format("rectAbs=NA w=NA h=NA srcMode={} hwnd=0x{} caller={}", srcMode, Format("{:X}", hwnd+0), caller))
                CAP_KV("VALID FAIL", capId, Format("reason=NonRectObject srcMode={} hwnd=0x{} caller={}", srcMode, Format("{:X}", hwnd+0), caller), "ERROR")
            }
            return false
        }

        if (!IsNumber(L) || !IsNumber(T) || !IsNumber(R) || !IsNumber(B)) {
            if (debug) {
                CAP_KV("START", capId, Format("rectAbs=NA w=NA h=NA srcMode={} hwnd=0x{} caller={}", srcMode, Format("{:X}", hwnd+0), caller))
                CAP_KV("VALID FAIL", capId, Format("reason=NonNumericRect srcMode={} hwnd=0x{} caller={}", srcMode, Format("{:X}", hwnd+0), caller), "ERROR")
            }

        ; Array input is ambiguous (could be [L,T,W,H]). Require already-normalized LTRB for Arrays.
        if (screenRect is Array) {
            if (R < L || B < T) {
                if (debug) {
                    CAP_KV("START", capId, Format("rectAbs=NA w=NA h=NA srcMode={} hwnd=0x{} caller={}", srcMode, Format("{:X}", hwnd+0), caller))
                    CAP_KV("VALID FAIL", capId, Format("reason=RectArrayNotNormalized raw={},{},{},{} srcMode={} hwnd=0x{} caller={}", L, T, R, B, srcMode, Format("{:X}", hwnd+0), caller), "ERROR")
                    CAP_KV("EXIT", capId, "ok=0 stage=VALID", "ERROR")
                }
                return false
            }
        }
            return false
        }
        ; =========================
        ; FLOWLOCK (no refactor):
        ; Optionally force DXGI to capture RAW parent rect (debug only).
        ; Controlled by opt.forceParentAbs=1 so normal template capture can crop.
        ; =========================
        forceParentAbs := 0
        try {
            if (IsObject(opt) && opt.Has("forceParentAbs"))
                forceParentAbs := opt["forceParentAbs"] ? 1 : 0
        } catch {
            forceParentAbs := 0
        }

        if (forceParentAbs && srcMode = "HWND" && caller = "AL_L4_TemplateCapture") {
            global parentL, parentT, parentR, parentB
            if (IsNumber(parentL) && IsNumber(parentT) && IsNumber(parentR) && IsNumber(parentB)
                && (parentR - parentL) > 0 && (parentB - parentT) > 0) {
                L := parentL, T := parentT, R := parentR, B := parentB
            }
        }

        if (R < L) {
            tmp := L, L := R, R := tmp
            normalized := 1
        }

        if (B < T) {
            tmp := T, T := B, B := tmp
            normalized := 1
        }

        W := R - L
        H := B - T

        if (debug) {
            CAP_KV("START", capId, Format("rectAbs={},{},{},{} w={} h={} srcMode={} hwnd=0x{} caller={}", L, T, R, B, W, H, srcMode, Format("{:X}", hwnd+0), caller))
        }

        ; =========================
        ; 2) DPI + MONITOR
        ; =========================
        sysDpi := CAP_GetSystemDPI()
        winDpi := CAP_GetWindowDPI(hwnd, sysDpi)
        scale := Round(winDpi / (sysDpi ? sysDpi : 96), 3)

        CAP_GetVirtualDesktop(&vx, &vy, &vw, &vh)

        cx := L + (W // 2)
        cy := T + (H // 2)
        monIdx := CAP_GetMonitorIndexForPoint(cx, cy, &monTotal)

        if (debug) {
            CAP_KV("DPI", capId, Format("sysDpi={} winDpi={} scale={} monitorIndex={} total={} virtualDesktop={},{},{}x{}", sysDpi, winDpi, scale, monIdx, monTotal, vx, vy, vw, vh))
        }

        ; =========================
        ; 3) VALIDATION
        ; =========================
        wOK := (W > 0) ? 1 : 0
        hOK := (H > 0) ? 1 : 0
        inScreen := !(R <= vx || L >= (vx + vw) || B <= vy || T >= (vy + vh))

        if (debug) {
            CAP_KV("VALID", capId, Format("normalized={} w>0={} h>0={} inScreen={}", normalized, wOK, hOK, inScreen ? 1 : 0))
            if (deep)
                CAP_KV("RAWRECT", capId, Format("afterNormalize={},{},{},{} W={} H={}", L, T, R, B, W, H))
        }

        if (!wOK || !hOK) {
            stage := "VALID"
            if (debug)
                CAP_KV("VALID FAIL", capId, Format("reason=ZeroSize rectAbs={},{},{},{}", L, T, R, B), "ERROR")
            return false
        }

        if (!inScreen) {
            stage := "VALID"
            if (debug)
                CAP_KV("VALID FAIL", capId, Format("reason=OutOfScreen rectAbs={},{},{},{} v={},{},{}x{}", L, T, R, B, vx, vy, vw, vh), "ERROR")
            return false
        }

        ; =========================
        ; 4) GDI+
        ; =========================
        stage := "GDI"
        tGdi := A_TickCount

        ; FLOWLOCK: SCREEN must not start/log GDI+ inside CAP() (no refactor).
        ; FLOWLOCK: DXGI caller must not start/log GDI+ inside CAP() (no refactor).
        isDxgiCaller := (InStr(caller, "DXGI") ? 1 : 0)

        if (srcMode = "SCREEN" || isDxgiCaller) {
            if (!EnsureGdip(true)) {
                gdiMs := A_TickCount - tGdi
                if (debug)
                    CAP_KV("GDI+ FAIL", capId, Format("code=StartupFailed token={}", (IsSet(GdipToken) ? GdipToken : 0)), "ERROR")
                return false
            }
        } else {
            if (!EnsureGdip()) {
                gdiMs := A_TickCount - tGdi
                if (debug)
                    CAP_KV("GDI+ FAIL", capId, Format("code=StartupFailed token={}", (IsSet(GdipToken) ? GdipToken : 0)), "ERROR")
                return false
            }
        }

        gdiMs := A_TickCount - tGdi
        if (debug && srcMode != "SCREEN" && !isDxgiCaller)
            CAP_KV("GDI+ START", capId, Format("ok=1 token={}", (IsSet(GdipToken) ? GdipToken : 0)))

        ; =========================
        ; 5-7) BITMAP + COPY (delegated)
        ; =========================
        stage := "COPY"
        cap := Map("id", capId, "debug", debug, "deep", deep, "srcMode", srcMode, "hwnd", hwnd)
        cap["copyMs"] := 0
        cap["lastStage"] := ""
        cap["fail"] := ""
        cap["winErr"] := 0

        rNorm := __RectClass(L, T, R, B)

        rClient := 0
        rClient := 0
        ; Choose capture method based on srcMode/hwnd.
        bmp := 0   ; FIX: ensure defined before DXGI/GDI checks

        rectAbs := Format("{},{},{},{}", L, T, R, B)
        ; NOTE: SCREEN is handled as a terminal branch (independent pipeline) to avoid HWND/DXGI/GDI cross-contamination.

        ; ROUTE: log why branch is selected (debug only)
        if (debug)
            CAP_KV("ROUTE", capId, Format("route={} caller={} hwnd={} useDXGI={} method={}", srcMode, caller, hwnd, useDXGI, (method != "" ? method : "AUTO")))

        ; FLOWLOCK: SCREEN must be fully isolated. Capture now and skip HWND/DXGI/GDI pipelines.
        if (srcMode = "SCREEN") {
            ; isolate from any HWND state
            hwnd := 0
            try {
                cap["hwnd"] := 0
            } catch {
            }

            if (debug)
                CAP_KV("ROUTE", capId, "SCREEN early branch (isolated, no HWND/DXGI)")

            wScr := Max(1, R - L)
            hScr := Max(1, B - T)
            tGdiCopyScr := A_TickCount

            cap["method"] := "SCREEN"
            cap["lastStage"] := "COPY"

            bmp := pBitmap := Gdip_BitmapFromScreen(L "|" T "|" wScr "|" hScr)
            cap["copyMs"] := (A_TickCount - tGdiCopyScr)

            if (!bmp) {
                cap["fail"] := "SCREEN=0"
                cap["winErr"] := 0
                ; do not return here; let the common failure logger handle it below
            }
        } else if (srcMode = "HWND") {
            if (!hwnd || hwnd = 0) {
                if (debug)
                    CAP_KV("COPY FAIL", capId, Format("method=HWND winErr=0 msg=HWND mode but hwnd=0 caller={}", caller), "ERROR")
                return false
            }

            ; bring window to front to reduce occlusion artifacts
            DllCall("user32\ShowWindow", "ptr", hwnd, "int", 9) ; SW_RESTORE
            DllCall("user32\SetForegroundWindow", "ptr", hwnd)
            Sleep 50
            try {
                DllCall("dwmapi\DwmFlush")
            } catch {
            }

            if (method = "PRINTWINDOW") {
                ; HWND PrintWindow/GDI path (final image)
                tGdiCopy := A_TickCount
                cap["forceGDI"] := 1
                 cap["method"] := "PrintWindow"
                cap["lastStage"] := "COPY"

                ok := 0
                try {
                    ok := bmp := pBitmap := AL_GdipBitmapFromHWNDRect(hwnd, rNorm, cap)
                } catch {
                    ok := bmp := pBitmap := 0
                }

                cap["copyMs"] := (A_TickCount - tGdiCopy)

                ; FLOWLOCK: no HWND BitBlt / no SCREEN fallback inside CAP when srcMode="HWND" & method="PrintWindow"
                ; Caller will decide SCREEN fallback by calling AL_Capture_RectToBMP() again with srcMode="SCREEN".
                if (!ok) {
                    try {
                        cap["fail"] := "PrintWindow=0"
                    } catch {
                    }
                    try {
                        cap["winErr"] := (cap.Has("winErr") ? cap["winErr"] : A_LastError)
                    } catch {
                    }
                }

            } else {
                ; HWND DXGI path (rect/map)
                if (!CAP_USE_DXGI) {
                    cap["method"] := "DXGI"
                    cap["lastStage"] := "COPY"
                    cap["fail"] := "DXGI disabled"
                    cap["winErr"] := 0
                    return false
                }

                tDxgi := A_TickCount
                cap["method"] := "DXGI"
                cap["lastStage"] := "COPY"
                bmp := pBitmap := CAP_CopyRect_DXGI(rectAbs)
                cap["copyMs"] := (A_TickCount - tDxgi)

                if (!bmp) {
                    cap["fail"] := "DXGI=0"
                    cap["winErr"] := 0
                    ; do not return here; let the common failure logger handle it below
                }
            }
        }
        ; Guard: never fall back to GDI screen capture when srcMode is HWND or SCREEN
        if (!bmp && srcMode != "HWND" && srcMode != "SCREEN") {
            bmp := pBitmap := AL_GdipBitmapFromScreenRect(rNorm, cap)
        }

        copyMs := (cap.Has("copyMs") ? cap["copyMs"] : 0)

        if (!bmp) {
            stage := (cap.Has("lastStage") && cap["lastStage"] != "") ? cap["lastStage"] : "COPY"
            if (debug) {
                fail := (IsObject(cap) && cap.Has("fail") && cap["fail"] != "") ? cap["fail"] : "BitmapFromScreen=0"
                meth := (IsObject(cap) && cap.Has("method") && cap["method"] != "") ? cap["method"] : "Unknown"
                werr := (IsObject(cap) && cap.Has("winErr") ? cap["winErr"] : 0)
                CAP_KV("COPY FAIL", capId, Format("method={} winErr={} msg={}", meth, werr, fail), "ERROR")
            }
            return false
        }

        ; =========================
        ; 8) SAVE
        ; =========================
        stage := "SAVE"
        tSave := A_TickCount
        ; base eliminated: save uses bmp directly (no base/hBitmap/ptr)

        ; Alpha-flatten fix (DXGI may output pixels with A=0): draw onto opaque white canvas then save.
        bmpFlat := 0, gfxFlat := 0
        try {
            bw := Gdip_GetImageWidth(bmp), bh := Gdip_GetImageHeight(bmp)
            bmpFlat := Gdip_CreateBitmap(bw, bh)
            if (bmpFlat) {
                gfxFlat := Gdip_GraphicsFromImage(bmpFlat)
                if (gfxFlat) {
                    Gdip_GraphicsClear(gfxFlat, 0xFFFFFFFF) ; opaque white background
                    Gdip_DrawImage(gfxFlat, bmp, 0, 0, bw, bh)
                }
            }
        } catch {
        }

        if (gfxFlat)
            Gdip_DeleteGraphics(gfxFlat)

        if (bmpFlat) {
            ok := (Gdip_SaveBitmapToFile(bmpFlat, outPath) = 0)  ; save flattened (opaque) bitmap
            try {
                Gdip_DisposeImage(bmpFlat)
            } catch {
            }
        } else {
            ok := (Gdip_SaveBitmapToFile(bmp, outPath) = 0)  ; fallback: save original bmp
        }
        saveMs := A_TickCount - tSave

        if (!ok) {
            if (debug) {
                fail := (IsObject(cap) && cap.Has("fail") && cap["fail"] != "") ? cap["fail"] : "SaveFailed"
                CAP_KV("SAVE FAIL", capId, Format('reason={} path="{}"', fail, outPath), "ERROR")
            }
            return false
        }

        stage := "SUCCESS"
        if (debug) {
            sizeKB := ""
            try {
                sizeKB := Round(FileGetSize(outPath) / 1024, 1)
            } catch {
            }

            ext := ""
            try {
                ext := StrUpper(RegExReplace(outPath, ".*\.(\w+)$", "$1"))
            } catch {
            }

            CAP_KV("SAVE", capId, Format('ok=1 path="{}" size={}KB format={}', outPath, sizeKB, ext))
        }

        return true
    }
    catch as e {
        if (debug)
            CAP_KV("EXCEPTION", capId, Format("stage={} msg={} caller={}", stage, e.Message, caller), "ERROR")
        return false
    }
    finally {
        ; Always dispose bitmap pointer if allocated.
        if (pBitmap)
            AL_GdipDisposeImage(pBitmap)

        if (debug) {
            ; Object safety line (useful to spot unexpected return types upstream)
            nullFlag := (pBitmap ? 0 : 1)
            CAP_KV("RESULT", capId, Format("isObj={} type={} nullFlag={} pBitmap={}", (IsObject(pBitmap) ? 1 : 0), Type(pBitmap), nullFlag, (pBitmap ? 1 : 0)))

            totalMs := A_TickCount - tStart
            CAP_KV("PERF", capId, Format("total={}ms gdi={}ms copy={}ms save={}ms", totalMs, gdiMs, copyMs, saveMs))
            CAP_KV("EXIT", capId, Format("ok={} stage={}", (stage = "SUCCESS" ? 1 : 0), stage))
        }
    }
}
