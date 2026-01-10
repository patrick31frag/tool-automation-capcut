; ==================================================================================================
;  MODULE 06 — Logger
;  Source lines (original scale.ahk): 2581 – 2958
; ==================================================================================================




AL_GdipSaveBitmapToFile(pBitmap, outPath, cap := 0) {
    AL_GdipGetEncoderClsid := Func("AL_GdipGetEncoderClsid")
    capId := ""
    debug := true
    if (IsObject(cap)) {
        try {
            if (cap.Has("id"))
                capId := cap["id"]
            if (cap.Has("debug"))
                debug := cap["debug"]
        } catch {
        }
    }

    if (capId = "")
        capId := "NA"

    if (!pBitmap) {
        if (IsObject(cap)) {
            cap["fail"] := "InvalidBitmap"
            cap["lastStage"] := "SAVE"
        }

        if (debug)
            CAP_KV("SAVE FAIL", capId, "reason=InvalidBitmap", "ERROR")
        return false
    }

    ; Pick encoder from extension, default PNG
    ext := ""
    try {
        ext := StrLower(RegExReplace(outPath, ".*\.(\w+)$", "$1"))
    } catch {
        ext := "png"
    }

    if (ext = "bmp")
        clsid := AL_GdipGetEncoderClsid("image/bmp")
    else if (ext = "jpg" || ext = "jpeg")
        clsid := AL_GdipGetEncoderClsid("image/jpeg")
    else
        clsid := AL_GdipGetEncoderClsid("image/png")

    if (!clsid) {
        if (IsObject(cap)) {
            cap["fail"] := "MissingEncoderClsid"
            cap["lastStage"] := "SAVE"
        }

        if (debug)
            CAP_KV("SAVE FAIL", capId, "reason=MissingEncoderClsid", "ERROR")
        return false
    }

    ; Ensure folder exists
    try {
        dir := RegExReplace(outPath, "[\\/][^\\/]+$", "")
        if (dir && !DirExist(dir))
            DirCreate(dir)
    } catch {
    }

    hr := 2
    try {
        hr := DllCall("gdiplus.dll\GdipSaveImageToFile"
            , "ptr", pBitmap
            , "wstr", outPath
            , "ptr", clsid.Ptr
            , "ptr", 0
            , "uint")
    } catch as e {
        if (IsObject(cap)) {
            cap["fail"] := "GdipSaveImageToFile exception: " e.Message
            cap["lastStage"] := "SAVE"
        }

        if (debug)
            CAP_KV("SAVE FAIL", capId, "reason=Exception msg=" e.Message, "ERROR")
        return false
    }

    ok := (hr = 0)
    if (!ok) {
        if (IsObject(cap)) {
            cap["fail"] := "hr=" . hr
            cap["lastStage"] := "SAVE"
        }

        if (debug)
            CAP_KV("SAVE FAIL", capId, Format('reason=hr={} path="{}"', hr, outPath), "ERROR")
        return false
    }

    return true
}


AL_GdipDisposeImage(pBitmap) {
    if (pBitmap) {
        try {
            DllCall("gdiplus.dll\GdipDisposeImage", "ptr", pBitmap)
        } catch {
        }
    }
}


AL_GdipShutdown(*) {
    global GdipToken
    if (GdipToken) {
        Gdip_Shutdown(GdipToken)
        GdipToken := 0
    }
}


AL_GdipBitmapFromHWNDRect(hwnd, r, cap := 0) {
    global CAP_USE_DXGI
    ; Capture a screen-rect region from a WINDOW DC (HWND) using PrintWindow/BitBlt fallback.
    ; r is Rect in SCREEN coords (LTRB). hwnd is a valid window handle.
    capId := ""
    debug := false
    deep := false
    try {
        if (IsObject(cap)) {
            if (cap.Has("id"))
                capId := cap["id"]
            if (cap.Has("debug"))
                debug := cap["debug"]
            if (cap.Has("deep"))
                deep := cap["deep"]
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

    if (!IsNumber(L) || !IsNumber(T) || !IsNumber(R) || !IsNumber(B))
        return 0

    W := Max(1, R - L)
    H := Max(1, B - T)



; === HWND CAPTURE POLICY ===
; Default: DXGI only (stable rect/map), allow opt-in GDI/PrintWindow via cap.forceGDI=1.
forceGDI := 0
try {
    if (IsObject(cap) && cap.Has("forceGDI"))
        forceGDI := cap["forceGDI"] ? 1 : 0
} catch {
    forceGDI := 0
}

if (!forceGDI) {
    if (CAP_USE_DXGI) {
        rectAbs := Format("{},{},{},{}", L, T, R, B)
        bmp := CAP_CopyRect_DXGI(rectAbs)
        if (IsObject(cap)) {
            cap["method"] := "DXGI"
            cap["lastStage"] := "COPY"
            cap["fail"] := (bmp ? "" : "DXGI=0")
            cap["winErr"] := 0
        }
        return bmp
    } else {
        if (IsObject(cap)) {
            cap["method"] := "DXGI"
            cap["lastStage"] := "COPY"
            cap["fail"] := "DXGI disabled"
            cap["winErr"] := 0
        }
        return 0
    }
}


    tCopy := A_TickCount
    hdcWin := 0, hdcMem := 0, hbm := 0, obm := 0
    pBitmap := 0
    winErr := 0

    ; Resolve window top-left to convert SCREEN -> WINDOWDC coords
    wx := 0, wy := 0
    try {
        rc := Buffer(16, 0)
        if (DllCall("user32.dll\GetWindowRect", "ptr", hwnd, "ptr", rc, "int")) {
            wx := NumGet(rc, 0, "int")
            wy := NumGet(rc, 4, "int")
        }
    } catch {
        wx := 0, wy := 0
    }
    xSrc := L - wx
    ySrc := T - wy

    try {
        if (IsObject(cap) && cap.Has("coordBase") && cap["coordBase"] = "WND") {
            xSrc := L
            ySrc := T
        }
    } catch {
    }

    try {
        if (IsObject(cap)) {
            cap["lastStage"] := "COPY"
            cap["fail"] := ""
            cap["winErr"] := 0
        }

        ; Get window DC (includes non-client); fall back to client DC if needed
        hdcOwner := hwnd
hdcWin := DllCall("user32.dll\GetWindowDC", "ptr", hwnd, "ptr")
if (!hdcWin)
    hdcWin := DllCall("user32.dll\GetDC", "ptr", hwnd, "ptr")
if (!hdcWin) {
    hdcOwner := 0
    hdcWin := DllCall("user32.dll\GetDC", "ptr", 0, "ptr")
}

if (!hdcWin) {
            winErr := A_LastError
            if (IsObject(cap)) {
                cap["fail"] := "GetWindowDC/GetDC failed"
                cap["winErr"] := winErr
                cap["method"] := "HWND.DC"
            }

            if (debug)
                CAP_KV("COPY FAIL", capId, Format("method=HWND.DC winErr={} msg=NoWindowDC hwnd=0x{}", winErr, Format("{:X}", hwnd+0)), "ERROR")
            return 0
        }

        hdcMem := DllCall("gdi32.dll\CreateCompatibleDC", "ptr", hdcWin, "ptr")
        hbm := DllCall("gdi32.dll\CreateCompatibleBitmap", "ptr", hdcWin, "int", W, "int", H, "ptr")
        if (!hdcMem || !hbm) {
            winErr := A_LastError
            if (IsObject(cap)) {
                cap["fail"] := "CreateCompatibleDC/Bitmap failed"
                cap["winErr"] := winErr
                cap["method"] := "HWND.CreateCompatible*"
            }

            if (debug)
                CAP_KV("COPY FAIL", capId, Format("method=HWND.CreateCompatible winErr={} msg=AllocFail", winErr), "ERROR")
            return 0
        }

        obm := DllCall("gdi32.dll\SelectObject", "ptr", hdcMem, "ptr", hbm, "ptr")

        ; Try PrintWindow first (often works for layered/accelerated windows)
        ok := 0

        printFlags := 0x00000002
        try {
            CAP_Log("PW HWND | " WinGetClass("ahk_id " hwnd))
        } catch {
        }
        if (!(printFlags & 0x00000002))
            CAP_Log("PW WARN | missing FULLCONTENT flag", "WARN")
        try {
            ok := DllCall("user32.dll\PrintWindow", "ptr", hwnd, "ptr", hdcMem, "uint", printFlags, "int")
        } catch {
            ok := 0
        }

        if (ok) {
            if (IsObject(cap))
                cap["method"] := "PrintWindow"
        } else {
            ok := 0
            if (IsObject(cap)) {
                try {
                    cap["method"] := "PrintWindow"
                } catch {
                }
                try {
                    cap["fail"] := "PrintWindow=0"
                } catch {
                }
            }
        }

        dur := A_TickCount - tCopy
        if (IsObject(cap))
            cap["copyMs"] := dur

        if (!ok) {
            winErr := A_LastError
            if (IsObject(cap)) {
                cap["winErr"] := winErr
                cap["fail"] := (cap.Has("fail") ? cap["fail"] : (cap.Has("method") ? cap["method"] : "HWND") " returned 0")
            }

            if (debug)
                CAP_KV("COPY FAIL", capId, Format("method={} winErr={} msg={}"
                    , (IsObject(cap) && cap.Has("method") ? cap["method"] : "HWND")
                    , winErr
                    , (IsObject(cap) && cap.Has("fail") ? cap["fail"] : "Copy=0")), "ERROR")
            return 0
        }

        ; Convert HBITMAP -> GDI+ Bitmap
        try {
            pBitmap := Gdip_CreateBitmapFromHBITMAP(hbm)
        } catch as e {
            pBitmap := 0
            if (IsObject(cap)) {
                cap["fail"] := "CreateBitmapFromHBITMAP ex: " e.Message
            }
        }

        if (debug) {
            if (pBitmap)
                CAP_KV("COPY", capId, Format("method={} ok=1 duration={}ms", (IsObject(cap) && cap.Has("method") ? cap["method"] : "HWND"), dur))
            else
                CAP_KV("COPY FAIL", capId, Format("method={} winErr={} msg={}"
                    , (IsObject(cap) && cap.Has("method") ? cap["method"] : "HWND")
                    , (IsObject(cap) && cap.Has("winErr") ? cap["winErr"] : 0)
                    , (IsObject(cap) && cap.Has("fail") && cap["fail"] != "" ? cap["fail"] : "HBITMAP->Bitmap=0")), "ERROR")
        }

        return pBitmap
    } catch as e {
        if (IsObject(cap)) {
            cap["fail"] := "HWND capture exception: " e.Message
            cap["winErr"] := A_LastError
            cap["method"] := "HWND.Exception"
        }

        if (debug)
            CAP_KV("COPY FAIL", capId, Format("method=HWND.Exception winErr={} msg={}", A_LastError, e.Message), "ERROR")
        return 0
    } finally {
        ; Always restore/release GDI handles (no leaks)
        if (hdcMem && obm) {
            try {
                DllCall("gdi32.dll\SelectObject", "ptr", hdcMem, "ptr", obm)
            } catch {
            }
        }

        if (hbm) {
            try {
                DllCall("gdi32.dll\DeleteObject", "ptr", hbm)
            } catch {
            }
        }

        if (hdcMem) {
            try {
                DllCall("gdi32.dll\DeleteDC", "ptr", hdcMem)
            } catch {
            }
        }

        if (hdcWin) {
            try {
                DllCall("user32.dll\ReleaseDC", "ptr", hdcOwner, "ptr", hdcWin)
            } catch {
            }
        }
    }
}
