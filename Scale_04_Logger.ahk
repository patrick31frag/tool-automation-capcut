; ==================================================================================================
;  MODULE 04 — Logger
;  Source lines (original scale.ahk): 1490 – 1952
; ==================================================================================================

CAP_GetWindowDPI(hwnd, sysDpi := 96) {
    if (!hwnd)
        return sysDpi
    try {
        dpi := DllCall("user32.dll\GetDpiForWindow", "ptr", hwnd, "uint")
        return (dpi > 0 ? dpi : sysDpi)
    } catch {
        return sysDpi
    }
}

CAP_GetMonitorIndexForPoint(x, y, &total) {
    total := 0
    idx := 0
    try {
        ; Prefer built-ins (Win 10/11)
        total := MonitorGetCount()
        if (total <= 0)
            total := CAP_SM(80) ; SM_CMONITORS
        Loop total {
            i := A_Index
            MonitorGet(i, &l, &t, &r, &b)
            if (x >= l && x < r && y >= t && y < b)
                return i
        }
        return 0
    } catch {
        total := CAP_SM(80)
        return 0
    }
}

CAP_Log(msg, level := "DEBUG") {
    ; Centralized capture log line
    try {
        Log(msg, level, "CAP")
    } catch {
    }
}

CAP_KV(stage, capId, kv, level := "DEBUG") {
    ; stage="START"/"DPI"/"VALID"/... kv already formatted "a=b c=d ..."
    CAP_Log(Format("CAP | {} id={} {}", stage, capId, kv), level)
}


EnsureGdip(silent := false) {
    global GdipToken

    if (GdipToken)
        return true

    try {
        GdipToken := Gdip_Startup()
    } catch as e {
        if (!silent)
            Log("CAP | GDI+ startup EXCEPTION msg=" e.Message, "ERROR", "CAP")
        return false
    }

    if (!GdipToken) {
        if (!silent)
            Log("CAP | GDI+ startup FAIL token=0 hr=2", "ERROR", "CAP")
        return false
    }

    if (!silent)
        Log(Format("CAP | GDI+ START OK token={}", GdipToken), "DEBUG", "CAP")
    return true
}

; ============================================================
; GUI/OVERLAY GUARD FOR DXGI DESKTOP CAPTURE
; DXGI captures the final desktop composition, so any on-top GUI
; (main window, drag border overlay, tooltips) can contaminate
; the captured bitmap. We hide them briefly before running dxgi_cap.exe
; and restore right after. (No refactor: just a small guard.)
; ============================================================

CAP_IsWindowVisible(hwnd) {
    try {
        return DllCall("user32.dll\IsWindowVisible", "ptr", hwnd, "int")
    } catch {
        return 0
    }
}
; =========================
; IDOL CAP LAYER (no refactor)
; Target detect + best HWND for PrintWindow (Browser/Electron).
; =========================
CAP_DetectTargetType(hwnd) {
    ; Returns: "BROWSER" | "GAME" | "APP"
    cls := ""
    exe := ""
    try {
        cls := WinGetClass("ahk_id " hwnd)
    } catch {
        cls := ""
    }
    try {
        exe := StrLower(WinGetProcessName("ahk_id " hwnd))
    } catch {
        exe := ""
    }

if (cls = "")
        return "APP"

    ; Browsers / Chromium / Electron shells
    if (InStr(cls, "Chrome_WidgetWin") || cls = "MozillaWindowClass"
        || exe = "chrome.exe" || exe = "msedge.exe" || exe = "brave.exe" || exe = "vivaldi.exe" || exe = "opera.exe" || exe = "firefox.exe") {
        return "BROWSER"
    }

    ; Common game engines (heuristic)
    if (cls = "UnityWndClass" || InStr(cls, "UnrealWindow") || InStr(exe, "roblox") || InStr(exe, "ue4") || InStr(exe, "unity")) {
        return "GAME"
    }

    return "APP"
}

CAP_GetBestPrintWindowHwnd(hwnd) {
    ; For Chromium/Electron, PrintWindow on top-level can return 0/black.
    ; Prefer the render-host child if found.
    cls := ""
    try {
        cls := WinGetClass("ahk_id " hwnd)
    } catch {
        cls := ""
    }

if (!InStr(cls, "Chrome_WidgetWin"))
        return hwnd

    child := 0
    ; Try common Chromium render child classes
    try {
        child := DllCall("user32.dll\FindWindowExW", "ptr", hwnd, "ptr", 0, "wstr", "Chrome_RenderWidgetHostHWND", "ptr", 0, "ptr")
        if (!child)
            child := DllCall("user32.dll\FindWindowExW", "ptr", hwnd, "ptr", 0, "wstr", "Chrome_RenderWidgetHostHWND1", "ptr", 0, "ptr")
        if (!child)
            child := DllCall("user32.dll\FindWindowExW", "ptr", hwnd, "ptr", 0, "wstr", "Chrome_RenderWidgetHostHWND2", "ptr", 0, "ptr")
    } catch {
        child := 0
    }

    return child ? child : hwnd
}


CAP_BeginDesktopCapture() {
    st := Map()

    ; Kill any tooltip that could be on top.
    try {
        ToolTip()
    } catch {
    }

    ; GUI hide policy: mặc định KHÔNG hide GUI/border khi capture.
    ; Nếu bạn muốn hide thật sự (không khuyên dùng cho pixel-truth), set:
    ;   GUI_HIDE_DURING_CAPTURE := true
    try {
        global GUI_HIDE_DURING_CAPTURE
        if (!GUI_HIDE_DURING_CAPTURE)
            return st
    } catch {
    }

    ; Hide main GUI if present.
    try {
        global g
        if (IsObject(g) && g.Hwnd) {
            was := CAP_IsWindowVisible(g.Hwnd)
            st["gWasVisible"] := was
            if (was)
                g.Hide()
        }
    } catch {
    }

    ; Hide border/overlay GUIs if present.
    try {
        global borderG
        vis := []
        if (IsObject(borderG)) {
            for _, gg in borderG {
                try {
                    if (IsObject(gg) && gg.Hwnd && CAP_IsWindowVisible(gg.Hwnd)) {
                        vis.Push(gg)
                        gg.Hide()
                    }
                } catch {
                }
            }
        }
        st["borderVis"] := vis
    } catch {
    }

    ; Give DWM a moment to re-compose without overlays.
    Sleep 60
    return st
}

CAP_EndDesktopCapture(st) {
    if !IsObject(st)
        return

    ; Restore border overlays if they were visible.
    try {
        if (st.Has("borderVis")) {
            for _, gg in st["borderVis"] {
                try {
                    gg.Show("NA")
                } catch {
                }
            }
        }
    } catch {
    }

    ; Restore main GUI.
    try {
        global g
        if (st.Has("gWasVisible") && st["gWasVisible"] && IsObject(g)) {
            g.Show()
        }
    } catch {
    }
}
_GdipGetEncoderClsid(mime) {
    ; Returns Buffer(16) CLSID, or 0 (dynamic struct sizing).
    size := 0
    count := 0
    if (SC_DllCall("gdiplus\GdipGetImageEncodersSize", "UIntP", count, "UIntP", size, "Int") != 0)
        return 0
    if (count <= 0 || size <= 0)
        return 0

    buf := Buffer(size, 0)
    if (SC_DllCall("gdiplus\GdipGetImageEncoders", "UInt", count, "UInt", size, "Ptr", buf.Ptr, "Int") != 0)
        return 0

    itemSize := (A_PtrSize = 8 ? 104 : 76)  ; ImageCodecInfo struct size
    offMime := 32 + (4 * A_PtrSize)
    base := buf.Ptr

    Loop count {
        pItem := base + (A_Index - 1) * itemSize
        pMime := NumGet(pItem + offMime, "Ptr")
        if (!pMime)
            continue
        mt := StrGet(pMime, "UTF-16")
        if (mt = mime) {
            clsid := Buffer(16, 0)
            SC_DllCall("RtlMoveMemory", "Ptr", clsid.Ptr, "Ptr", pItem, "UPtr", 16)
            return clsid
        }
    }
    return 0
}

AL_GdipGetEncoderClsid(mime) {
    ; compatibility wrapper (minimal) for AL_GdipSaveBitmapToFile
    return _GdipGetEncoderClsid(mime)
}

CAP_CopyRect_DXGI(rectAbs) {
    ; rectAbs: "L,T,R,B" (absolute screen coords)
    ; returns: pBitmap (GDI+ bitmap ptr) or 0
    static dxgiExeCached := ""
    try {
        parts := StrSplit(rectAbs, ",")
        if (parts.Length < 4)
            return 0
        L := parts[1] + 0, T := parts[2] + 0, R := parts[3] + 0, B := parts[4] + 0
        W := Max(1, R - L), H := Max(1, B - T)

        dxgiExe := dxgiExeCached
        if (!dxgiExe) {
            dxgiExe := A_MyDocuments "\AutoHotkey\Lib\dxgi_cap.exe"
            if (!FileExist(dxgiExe))
                dxgiExe := A_ScriptDir "\dxgi_cap.exe"
            if (!FileExist(dxgiExe))
                return 0
            dxgiExeCached := dxgiExe
        } else if (!FileExist(dxgiExe)) {
            dxgiExeCached := ""
            return 0
        }

        outBmp := A_Temp "\dxgi_cap_" A_TickCount "_" DllCall("kernel32.dll\GetCurrentThreadId", "uint") ".bmp"
        cmd := Format('"{1}" {2} {3} {4} {5} "{6}"', dxgiExe, L, T, W, H, outBmp)

        ; Hide console; wait for completion (retry once on failure/lock)
        tries := 0
        while (tries < 2) {
            tries += 1
            try {
                FileDelete outBmp
            } catch {
            }

            Log("DXGI CALL rectAbs=" rectAbs, "DEBUG", "DXGI")

            Log("DXGI CMD=" cmd, "DEBUG", "DXGI")
            exitCode := 0
            stCap := 0
            try {
                stCap := CAP_BeginDesktopCapture()
            } catch {
                stCap := 0
            }
            try {
                exitCode := RunWait(cmd, , "Hide")
            } catch as e {
                Log("DXGI RUN EXCEPTION msg=" e.Message, "ERROR", "DXGI")
                Sleep 20
                continue
            } finally {
                try {
                    CAP_EndDesktopCapture(stCap)
                } catch {
                }
            }

            Log("DXGI EXIT exitCode=" exitCode, "DEBUG", "DXGI")
            Log("DXGI OUT exist=" FileExist(outBmp), "DEBUG", "DXGI")

            if (exitCode != 0) {
                Sleep 20
                continue
            }

            ; wait until file exists and is "ready" (size >= 100 bytes and stable)
            okFile := false
            lastSz := -1
            stableCount := 0
            t0 := A_TickCount
            while ((A_TickCount - t0) < 800) {
                if (FileExist(outBmp)) {
                    sz := 0
                    try {
                        sz := FileGetSize(outBmp)
                    } catch {
                    }
                    if (sz >= 100) {
                        if (sz = lastSz)
                            stableCount += 1
                        else
                            stableCount := 0
                        lastSz := sz
                        if (stableCount >= 1) {
                            okFile := true
                            break
                        }
                    } else {
                        lastSz := sz
                        stableCount := 0
                    }
                }
                Sleep 10
            }

            if (!okFile) {
                Sleep 20
                continue
            }

            ; load bitmap (retry a few times in case of transient lock)
            bmp := 0
            Loop 10 {
                try {
                    bmp := Gdip_CreateBitmapFromFile(outBmp)
                } catch {
                }
                if (bmp)
                    break
                Sleep 10
            }

            if (bmp) {
                try {
                    FileDelete outBmp
                } catch {
                }
                return bmp
            }

            Sleep 20
        }
        try {
            FileDelete outBmp
        } catch {
        }
        return 0
    } catch as e {
        return 0
    }
}

; ============================================================
; FILE-LEVEL BMP HELPERS (IDOL STANDARD)
; - Used to crop EXACTLY the same captured parent.bmp (DXGI/GDI)
; - Outputs opaque 24-bit BMP (normal-looking, no alpha issues)
; ============================================================

SC_BmpGetSize(path, &w, &h) {
    w := 0, h := 0
    f := 0
    try {
        f := FileOpen(path, "r -raw")
        if (!f)
            return false
        ; BITMAPINFOHEADER width/height at offset 18/22 from file start
        f.Pos := 18
        w := f.ReadInt()
        hRaw := f.ReadInt()
        h := Abs(hRaw)
        try {
            f.Close()
        } catch {
        }
        return (w > 0 && h > 0)
    } catch {
        try {
            f.Close()
        } catch {
        }
        return false
    }
}

SC_BmpGetBitCount(path, &bpp) {
    ; Reads biBitCount from BMP header. Returns true/false.
    bpp := 0
    f := 0
    try {
        f := FileOpen(path, "r -raw")
        if (!f)
            return false
        ; biBitCount at file offset 28 (BITMAPFILEHEADER 14 + BIH offset 14)
        f.Pos := 28
        bpp := f.ReadUShort()
        try {
            f.Close()
        } catch {
        }
        return (bpp > 0)
    } catch {
        try {
            if (f)
                f.Close()
        } catch {
        }
        bpp := 0
        return false
    }
}

