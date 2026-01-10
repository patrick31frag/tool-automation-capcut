; ==================================================================================================
;  MODULE 05 — Logger
;  Source lines (original scale.ahk): 1953 – 2580
; ==================================================================================================
SC_BmpProbeAlphaAndBlack(path, &alphaAllZero, &rgbAllZero) {
    ; Quick probe (sample a few rows/cols) to detect DXGI "alpha=0" or full black frames.
    alphaAllZero := 0
    rgbAllZero := 0
    f := 0
    try {
        f := FileOpen(path, "r -raw")
        if (!f)
            return false

        ; Validate BMP signature
        if (f.ReadUShort() != 0x4D42) {
            try {
                f.Close()
            } catch {
            }
            return false
        }

        ; OffBits
        f.Pos := 10
        offBits := f.ReadUInt()

        ; Width/Height/BitCount
        f.Pos := 18
        w := f.ReadInt()
        hRaw := f.ReadInt()
        h := Abs(hRaw)
        f.Pos := 28
        bpp := f.ReadUShort()

        if (w <= 0 || h <= 0) {
            try {
                f.Close()
            } catch {
            }
            return false
        }

        if (bpp != 32 && bpp != 24) {
            try {
                f.Close()
            } catch {
            }
            return false
        }

        bytesPP := (bpp = 32 ? 4 : 3)
        stride := (bpp = 24) ? (((w * 3 + 3) // 4) * 4) : (w * 4)

        sampleRows := Min(3, h)
        sampleCols := Min(64, w)

        alphaZero := true
        rgbZero := true

        rowBuf := Buffer(sampleCols * bytesPP, 0)

        Loop sampleRows {
            f.Pos := offBits + (A_Index - 1) * stride
            f.RawRead(rowBuf, rowBuf.Size)

            Loop sampleCols {
                i := (A_Index - 1) * bytesPP
                b := NumGet(rowBuf, i + 0, "UChar")
                g := NumGet(rowBuf, i + 1, "UChar")
                r := NumGet(rowBuf, i + 2, "UChar")

                if ((r | g | b) != 0)
                    rgbZero := false

                if (bpp = 32) {
                    a := NumGet(rowBuf, i + 3, "UChar")
                    if (a != 0)
                        alphaZero := false
                }
            }
        }

        try {
            f.Close()
        } catch {
        }

        alphaAllZero := (bpp = 32 && alphaZero) ? 1 : 0
        rgbAllZero := rgbZero ? 1 : 0
        return true
    } catch {
        try {
            if (f)
                f.Close()
        } catch {
        }
        alphaAllZero := 0
        rgbAllZero := 0
        return false
    }
}


SC_BmpCropFile(srcPath, dstPath, x, y, cw, ch, flattenOnWhite := true) {
    ; x,y,cw,ch in top-left coordinate system of the source image
    ; Supports uncompressed 24-bit and 32-bit BMP. Outputs 24-bit BMP.
    fs := 0
    fd := 0
    try {
        fs := FileOpen(srcPath, "r -raw")
        if (!fs)
            return false

        ; --- BITMAPFILEHEADER (14 bytes) ---
        bfType := fs.ReadUShort()
        if (bfType != 0x4D42) { ; 'BM'
            try {
                fs.Close()
            } catch {
            }
            return false
        }
        bfSize := fs.ReadUInt()
        fs.ReadUShort() ; bfReserved1
        fs.ReadUShort() ; bfReserved2
        bfOffBits := fs.ReadUInt()

        ; --- BITMAPINFOHEADER (assume >= 40 bytes) ---
        biSize := fs.ReadUInt()
        if (biSize < 40) {
            try {
                fs.Close()
            } catch {
            }
            return false
        }
        biWidth := fs.ReadInt()
        biHeight := fs.ReadInt()
        biPlanes := fs.ReadUShort()
        biBitCount := fs.ReadUShort()
        biCompression := fs.ReadUInt()
        biSizeImage := fs.ReadUInt()
        fs.ReadInt() ; biXPelsPerMeter
        fs.ReadInt() ; biYPelsPerMeter
        fs.ReadUInt() ; biClrUsed
        fs.ReadUInt() ; biClrImportant

        if (biPlanes != 1) {
            try {
                fs.Close()
            } catch {
            }
            return false
        }

        ; Only BI_RGB (0) or BI_BITFIELDS (3) are common for 32-bit.
        if (biCompression != 0 && biCompression != 3) {
            try {
                fs.Close()
            } catch {
            }
            return false
        }

        srcW := biWidth
        srcHRaw := biHeight
        srcTopDown := (srcHRaw < 0)
        srcH := Abs(srcHRaw)

        if (srcW <= 0 || srcH <= 0) {
            try {
                fs.Close()
            } catch {
            }
            return false
        }

        if (x < 0 || y < 0 || cw <= 0 || ch <= 0 || x + cw > srcW || y + ch > srcH) {
            try {
                fs.Close()
            } catch {
            }
            return false
        }

        bpp := biBitCount
        if (bpp != 24 && bpp != 32) {
            try {
                fs.Close()
            } catch {
            }
            return false
        }
        srcBytesPP := (bpp = 24 ? 3 : 4)
        srcStride := (bpp = 24) ? (((srcW * 3 + 3) // 4) * 4) : (srcW * 4)

        ; If BI_BITFIELDS and header has masks, skip them (we still treat as BGRA for standard masks).
        ; For simplicity, we do not parse masks; most desktop captures use standard BGRA.

        ; --- Prepare destination (24-bit) ---
        dstBpp := 24
        dstBytesPP := 3
        dstStride := (((cw * dstBytesPP + 3) // 4) * 4)
        dstImageSize := dstStride * ch
        dstOffBits := 14 + 40
        dstFileSize := dstOffBits + dstImageSize

        ; Write headers
        fd := FileOpen(dstPath, "w -raw")
        if (!fd) {
            try {
                fs.Close()
            } catch {
            }
            return false
        }

        ; BITMAPFILEHEADER
        fd.WriteUShort(0x4D42)
        fd.WriteUInt(dstFileSize)
        fd.WriteUShort(0)
        fd.WriteUShort(0)
        fd.WriteUInt(dstOffBits)

        ; BITMAPINFOHEADER (40 bytes)
        fd.WriteUInt(40)
        fd.WriteInt(cw)
        fd.WriteInt(ch) ; bottom-up
        fd.WriteUShort(1)
        fd.WriteUShort(dstBpp)
        fd.WriteUInt(0) ; BI_RGB
        fd.WriteUInt(dstImageSize)
        fd.WriteInt(0)
        fd.WriteInt(0)
        fd.WriteUInt(0)
        fd.WriteUInt(0)

        ; --- Copy pixels row by row (write bottom-up) ---
        padBytes := dstStride - (cw * dstBytesPP)
        if (padBytes < 0)
            padBytes := 0
        pad := (padBytes ? Buffer(padBytes, 0) : 0)

        rowBuf := Buffer(cw * srcBytesPP, 0)

        ; Destination row index 0 is bottom row in file
        Loop ch {
            dstRowTop := ch - A_Index ; 0..ch-1 (top-down index)
            srcY := y + dstRowTop
            fileRow := srcTopDown ? srcY : (srcH - 1 - srcY)
            srcPos := bfOffBits + fileRow * srcStride + x * srcBytesPP
            fs.Pos := srcPos

            ; Read the contiguous crop row bytes
            fs.RawRead(rowBuf, cw * srcBytesPP)

            ; Convert/write 24-bit row
            if (srcBytesPP = 3) {
                ; BGR already
                fd.RawWrite(rowBuf, cw * 3)
            } else {
                ; BGRA -> BGR (flatten on white if requested)
                outRow := Buffer(cw * 3, 0)
                si := 0
                di := 0
                Loop cw {
                    b := NumGet(rowBuf, si, "UChar")
                    g := NumGet(rowBuf, si+1, "UChar")
                    r := NumGet(rowBuf, si+2, "UChar")
                    a := NumGet(rowBuf, si+3, "UChar")
                    if (flattenOnWhite) {
                        inv := 255 - a
                        b := (b * a + 255 * inv) // 255
                        g := (g * a + 255 * inv) // 255
                        r := (r * a + 255 * inv) // 255
                    }
                    NumPut("UChar", b, outRow, di)
                    NumPut("UChar", g, outRow, di+1)
                    NumPut("UChar", r, outRow, di+2)
                    si += 4
                    di += 3
                }
                fd.RawWrite(outRow, cw * 3)
            }

            if (padBytes)
                fd.RawWrite(pad, padBytes)
        }

        try {
            fs.Close()
        } catch {
        }
        try {
            fd.Close()
        } catch {
        }
        return FileExist(dstPath) ? true : false
    } catch {
        try {
            fs.Close()
        } catch {
        }
        try {
            fd.Close()
        } catch {
        }
        return false
    }
}


SC_BmpFlattenTo24(path, flattenOnWhite := true) {
    ; Converts the whole BMP to an opaque 24-bit BMP in-place (safe temp swap).
    ; Fixes "black preview" when DXGI outputs pixels with A=0.
    if (!FileExist(path))
        return false
    bw := 0, bh := 0
    if (!SC_BmpGetSize(path, &bw, &bh))
        return false
    if (bw <= 0 || bh <= 0)
        return false
    tmp := path ".tmp24.bmp"
    ok := false
    try {
        ok := SC_BmpCropFile(path, tmp, 0, 0, bw, bh, flattenOnWhite)
    } catch {
        ok := false
    }

    if (!ok) {
        try {
            FileDelete tmp
        } catch {
        }
        return false
    }
    try {
        FileMove(tmp, path, 1)
    } catch {
        ; if move fails, keep tmp for inspection
        return false
    }
    return true
}

AL_GdipBitmapFromScreenRect(r, cap := 0) {
    global CAP_USE_DXGI
    IsFunc := Func("IsFunc")
    ; Returns: pBitmap (GDI+ Bitmap ptr) or 0
    ; cap: Map used for CAPTURE DEBUG MASTER (id/debug/deep). This function may write:
    ;   cap["lastStage"], cap["fail"], cap["method"], cap["copyMs"], cap["winErr"]
    L := 0, T := 0, R := 0, B := 0
    if (!SC_RectUnpack_SAFE(r, &L, &T, &R, &B))
        return 0


    rectAbs := L "," T "," R "," B

    ; (DXGI disabled for ScreenRect path; DESKTOP must use GDI only)

; clamp to virtual desktop to avoid out-of-screen DXGI/GDI issues
vdL := SysGet(76), vdT := SysGet(77), vdW := SysGet(78), vdH := SysGet(79)
vdR := vdL + vdW, vdB := vdT + vdH
if (L < vdL)
    L := vdL
if (T < vdT)
    T := vdT
if (R > vdR)
    R := vdR
if (B > vdB)
    B := vdB
    capId := ""
    debug := true
    deep := false
    if (IsObject(cap)) {
        try {
            if (cap.Has("id"))
                capId := cap["id"]
            if (cap.Has("debug"))
                debug := cap["debug"]
            if (cap.Has("deep"))
                deep := cap["deep"]
        } catch {
        }
    }
        ; srcMode := StrUpper(srcMode)  ; (unused local, avoid shadow)
if (capId = "")
        capId := "NA"
    if (!IsNumber(L) || !IsNumber(T) || !IsNumber(R) || !IsNumber(B))
        return 0


; clamp to virtual desktop to avoid out-of-screen DXGI/GDI issues
vdL := SysGet(76), vdT := SysGet(77), vdW := SysGet(78), vdH := SysGet(79)
vdR := vdL + vdW, vdB := vdT + vdH
if (L < vdL)
    L := vdL
if (T < vdT)
    T := vdT
if (R > vdR)
    R := vdR
if (B > vdB)
    B := vdB
    W := Max(1, R - L)
    H := Max(1, B - T)

    
rectAbs := Format("{},{},{},{}", L, T, R, B)

; (DXGI disabled for ScreenRect path; DESKTOP must use GDI only)

pBitmap := 0
    tCopy := A_TickCount

    ; =========================
    ; Method 1: Gdip_All helper (fast, simple)
    ; =========================
    if (IsFunc("Gdip_BitmapFromScreen")) {
        if (IsObject(cap)) {
            cap["method"] := "Gdip_BitmapFromScreen"
            cap["lastStage"] := "COPY"
        }
        try {
            pBitmap := Gdip_BitmapFromScreen(L "|" T "|" W "|" H)
        } catch as e {
            pBitmap := 0
            if (IsObject(cap))
                cap["fail"] := "Gdip_BitmapFromScreen exception: " e.Message
        }
        dur := A_TickCount - tCopy
        if (IsObject(cap))
            cap["copyMs"] := dur

        if (debug) {
            if (pBitmap)
                CAP_KV("COPY", capId, Format("method=Graphics.Copy ok=1 duration={}ms", dur))
            else
                CAP_KV("COPY FAIL", capId, Format("method=Graphics.Copy ok=0 duration={}ms msg={}", dur, ((IsObject(cap) && cap.Has("fail") && cap["fail"] != "") ? cap["fail"] : "Gdip_BitmapFromScreen=0")), "ERROR")
        }

        if (pBitmap)
            return pBitmap
    }

    ; =========================
    ; Method 2: Manual BitBlt (fallback)
    ; =========================
    if (IsObject(cap)) {
        cap["method"] := "BitBlt"
        cap["lastStage"] := "CTX"
        cap["winErr"] := 0
    }

    hdcScreen := 0
    hdcMem := 0
    hbm := 0
    obm := 0

    try {
        ; CTX
        hdcScreen := DllCall("user32.dll\GetDC", "ptr", 0, "ptr")
        if (!hdcScreen) {
            if (IsObject(cap)) {
                cap["winErr"] := A_LastError
                cap["fail"] := "GetDC=0"
                cap["lastStage"] := "CTX"
            }

            if (debug)
                CAP_KV("CTX FAIL", capId, Format("step=GetDC err={}", A_LastError), "ERROR")
            return 0
        }

        if (debug)
            CAP_KV("CTX", capId, "getWindowDC=0 hdcWindow=NA hdcScreen=OK hdcMem=...")

        hdcMem := DllCall("gdi32.dll\CreateCompatibleDC", "ptr", hdcScreen, "ptr")
        if (!hdcMem) {
            if (IsObject(cap)) {
                cap["winErr"] := A_LastError
                cap["fail"] := "CreateCompatibleDC=0"
                cap["lastStage"] := "CTX"
            }

            if (debug)
                CAP_KV("CTX FAIL", capId, Format("step=CreateCompatibleDC err={}", A_LastError), "ERROR")
            return 0
        }

        hbm := DllCall("gdi32.dll\CreateCompatibleBitmap", "ptr", hdcScreen, "int", W, "int", H, "ptr")
        if (!hbm) {
            if (IsObject(cap)) {
                cap["winErr"] := A_LastError
                cap["fail"] := "CreateCompatibleBitmap=0"
                cap["lastStage"] := "BMP"
            }

            if (debug)
                CAP_KV("BMP FAIL", capId, Format("reason=CreateFailed winErr={} W={} H={}", A_LastError, W, H), "ERROR")
            return 0
        }

        obm := DllCall("gdi32.dll\SelectObject", "ptr", hdcMem, "ptr", hbm, "ptr")
        if (!obm) {
            if (IsObject(cap)) {
                cap["winErr"] := A_LastError
                cap["fail"] := "SelectObject=0"
                cap["lastStage"] := "CTX"
            }

            if (debug)
                CAP_KV("CTX FAIL", capId, Format("step=SelectObject err={}", A_LastError), "ERROR")
            return 0
        }

        if (debug)
            CAP_KV("BMP", capId, Format("create=1 w={} h={} handle={}", W, H, hbm))

        ; COPY
        if (IsObject(cap))
            cap["lastStage"] := "COPY"
        t2 := A_TickCount
        ; COPY safety (AHK v2: prevent [] on non-objects upstream)
        if (debug)
            CAP_KV("COPY PRE", capId, Format('rectType={} rectIsObj={} hbmType={} hbmIsObj={} hdcMemType={} hdcScreenType={}'
                , Type(r), IsObject(r) ? 1 : 0, Type(hbm), IsObject(hbm) ? 1 : 0, Type(hdcMem), Type(hdcScreen)))
        if (!hbm || !hdcMem || !hdcScreen) {
            if (IsObject(cap)) {
                cap["fail"] := "preCopy invalid handles"
                cap["lastStage"] := "COPY"
                cap["winErr"] := A_LastError
            }

            if (debug)
                CAP_KV("COPY FAIL", capId, "bmp invalid", "ERROR")
            return 0
        }

        ok := DllCall("gdi32.dll\BitBlt"
            , "ptr", hdcMem
            , "int", 0, "int", 0
            , "int", W, "int", H
            , "ptr", hdcScreen
            , "int", L, "int", T
            , "uint", 0x00CC0020
            , "int")
        dur := A_TickCount - t2

        if (!ok) {
            if (IsObject(cap)) {
                cap["winErr"] := A_LastError
                cap["fail"] := "BitBlt=0"
                cap["copyMs"] := dur
            }

            if (debug)
                CAP_KV("COPY FAIL", capId, Format("method=BitBlt ok=0 winErr={} msg=BitBlt=0 duration={}ms", A_LastError, dur), "ERROR")
            return 0
        }

        if (IsObject(cap))
            cap["copyMs"] := dur

        if (debug)
            CAP_KV("COPY", capId, Format("method=BitBlt ok=1 duration={}ms", dur))

        ; Convert HBITMAP -> GDI+ bitmap pointer
        if (IsObject(cap))
            cap["lastStage"] := "BMP"

        try {
            pBitmap := Gdip_CreateBitmapFromHBITMAP(hbm)
        } catch as e {
            pBitmap := 0
            if (IsObject(cap))
                cap["fail"] := "CreateBitmapFromHBITMAP exception: " e.Message
        }

        if (!pBitmap) {
            if (IsObject(cap)) {
                cap["fail"] := (cap.Has("fail") ? cap["fail"] : "CreateBitmapFromHBITMAP=0")
                cap["lastStage"] := "BMP"
            }

            if (debug)
                CAP_KV("BMP FAIL", capId, Format("reason=CreateFailed msg={}", ((IsObject(cap) && cap.Has("fail") && cap["fail"] != "") ? cap["fail"] : "CreateBitmapFromHBITMAP=0")), "ERROR")
            return 0
        }

        return pBitmap
    } catch as e {
        if (IsObject(cap)) {
            cap["fail"] := "EXCEPTION: " e.Message
            cap["lastStage"] := "COPY"
        }

        if (debug)
            CAP_KV("COPY FAIL", capId, Format("method=Exception msg={}", e.Message), "ERROR")
        return 0
    } finally {
        ; Always restore/release GDI handles (no leaks on any path)
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

        if (hdcScreen) {
            try {
                DllCall("user32.dll\ReleaseDC", "ptr", 0, "ptr", hdcScreen)
            } catch {
            }
        }
    }
}
