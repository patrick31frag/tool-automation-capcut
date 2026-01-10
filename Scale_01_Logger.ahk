; ==================================================================================================
;  MODULE 01 — Logger
;  Source lines (original scale.ahk): 27 – 513
; ==================================================================================================
; ============================================================
; PATCHABLE_ZONE__BOOT_LINT_BEGIN
; Self-lint / runtime error guard / GUI text-lock (template-aligned)
; RULE: Do NOT hardcode GUI text in Add*(). Use T("KEY") + __TXT map below.
; ============================================================

global __TXT_READY := false
global __TXT := Map()

global __UI_IS_TESTING := 0
global __DBG_ENTRYPOINT := 1
global __TEST_FORCE_BEHVALID := false

__ENTRY_Log(where, msg := "") {
    global __DBG_ENTRYPOINT
    if (!__DBG_ENTRYPOINT) {
        return
    }
    if (msg != "") {
        Log(where " | " msg, "DEBUG", "ENTRY")
    } else {
        Log(where, "DEBUG", "ENTRY")
    }
}



; --- Decision Trace + Click Policy Debug (A3) ---
; Engine-safe: logs only (no behavior changes)
global __DBG_DECIDE := 1
global __DBG_CLICKPOLICY := 1

global __TEST_LAST := Map()
global __TEST_LAST_READY := false

__STR_Join(arr, sep := " ") {
    ; STRICT (NO try/catch): safe join for Array-like objects.
    if (!IsObject(arr)) {
        return "" arr
    }
    out := ""
    first := true
    for _, v in arr {
        if (first) {
            out := "" v
            first := false
        } else {
            out := out sep "" v
        }
    }
    return out
}


__DECIDE__ToStr(v := "") {
    ; STRICT (NO try/catch): keep stringify safe by pre-filtering objects.
    if IsObject(v) {
        return "<obj>"
    }
    return "" v
}

__DECIDE__KV(fields := "") {
    if (!IsObject(fields))
        return __DECIDE__ToStr(fields)
    parts := []
    for k, v in fields {
        parts.Push(k "=" __DECIDE__ToStr(v))
    }
    return parts.Length ? __STR_Join(parts, " ") : ""
}

__DECIDE_Log(step := "", fields := "") {
    global __DBG_DECIDE
    if (!__DBG_DECIDE) {
        return
    }
    msg := step
    kv := __DECIDE__KV(fields)
    if (kv != "") {
        msg := msg " | " kv
    }
    ; Log() is part of the engine; do not swallow errors here in STRICT mode.
    Log(msg, "DEBUG", "DECIDE")
}

__TEST_DiagReset() {
    global __TEST_LAST, __TEST_LAST_READY
    __TEST_LAST := Map()
    __TEST_LAST_READY := true
}

__TEST_DiagSet(reason := "", fields := "") {
    global __TEST_LAST, __TEST_LAST_READY
    if (!__TEST_LAST_READY)
        __TEST_DiagReset()
    __TEST_LAST["reason"] := reason
    if (IsObject(fields)) {
        for k, v in fields
            __TEST_LAST[k] := v
    }
    __DECIDE_Log("TEST_DIAG", __TEST_LAST)
}

ClickPolicy_Explain(context := "") {
    global __UI_IS_TESTING, IS_RUNNING, busy
    out := Map()
    out["ctx"] := context
    out["isTesting"] := __UI_IS_TESTING
    out["IS_RUNNING"] := IS_RUNNING
    out["busy"] := busy

    reasons := []
    allow := true

    ; In TEST mode, allow click regardless of busy flag.
    if (!__UI_IS_TESTING) {
        if (IS_RUNNING) {
            allow := false
            reasons.Push("IS_RUNNING")
        }
        if (busy) {
            allow := false
            reasons.Push("busy")
        }
    }

    out["allow"] := allow ? 1 : 0
    out["reasons"] := reasons.Length ? __STR_Join(reasons, ",") : ""
    return out
}

; --- NO_WARN defaults (lint-silencer, engine-safe) ---
; These globals are referenced in UI helpers / F3 overlay but may be created dynamically later.
; Providing safe defaults prevents AHK v2 static warnings without changing runtime logic.
global lbModules   := 0
global UI_PAD      := 12
global UI_HEADER_H := 60
global UI_ACTION_H := 110
global UI_LEFT_W   := 260
global gbScale     := 0
global gbRois      := 0
global gbAnchors   := 0
global gbHistory   := 0
global gbSettings  := 0
global F3_ROI_ORDER := Map()
global busy := false


__BuildTXT() {
    global __TXT, __TXT_READY
    if __TXT_READY
        return
    __TXT["BTN_ADD"] := "Add"
    __TXT["BTN_ADVANCED"] := "Advanced ▼"
    __TXT["BTN_PREVIEW"] := "Preview"
    __TXT["BTN_REMOVE"] := "Remove"
    __TXT["BTN_RESET_UI"] := "Reset UI"
    __TXT["BTN_RUN"] := "Run"
    __TXT["BTN_SAVE_INI"] := "Save INI"
    __TXT["BTN_SET_PARENT_F3"] := "Set Parent (F3)"
    __TXT["BTN_SHOW"] := "Show"
    __TXT["BTN_SHOW_BORDERS"] := "Show Borders"
    __TXT["BTN_START_F1"] := "Start (F1)"
    __TXT["BTN_STOP"] := "Stop"
    __TXT["BTN_LEARN_DIAMOND_F4"] := "Learn Diamond (F4)"
    __TXT["BTN_TEST_CLICK"] := "Test Click"
    __TXT["BTN_TXT_01"] := "⚙"
    __TXT["BTN_UPDATE"] := "Update"
    __TXT["CHK_AUTO_HIDE_WHILE_RUN"] := "Auto-hide while RUN"
    __TXT["CHK_F2_SCAN"] := "F2 Scan"
    __TXT["EDT_HOW_TO_USE_N"] := "How to use:`n"
    __TXT["EDT_QUICK_START_N"] := "Quick start:`n"
    __TXT["GRP_ACTIONS"] := "Actions"
    __TXT["GRP_ADVANCED"] := "Advanced"
    __TXT["GRP_AUTO_KEYFRAME_CYCLE_A_B"] := "Auto Keyframe Cycle (A ↔ B)"
    __TXT["TXT_A"] := "A"
    __TXT["TXT_B"] := "B"
    __TXT["TXT_CAPCUT_AUTO_KEYFRAME_TOOL"] := "CapCut Auto Keyframe Tool"
    __TXT["TXT_DIAMOND_ANCHORS"] := "Diamond anchors:"
    __TXT["TXT_F3_ROIS"] := "F3 ROIs:"
    __TXT["TXT_FOCUS_A_NUMERIC_FIELD_IN_CAPCUT_F4_L"] := "Focus a numeric field in CapCut → F4 Learn Diamond → F1 Start/Stop (ESC = Emergency Stop)"
    __TXT["TXT_HISTORY_RECORDS_LAST_CAPTURES_AND_CO"] := "History records last captures and coordinates. Useful for debugging when UI changes."
    __TXT["TXT_ITEMS_0"] := "Items: 0"
    __TXT["TXT_PARENT_HISTORY"] := "Parent history:"
    __TXT["TXT_PARENT_REGION"] := "Parent region:"
    __TXT["TXT_READY"] := "READY"
    __TXT["TXT_ROIS_0"] := "ROIs: 0"
    __TXT["TXT_SCALE_ANCHORS"] := "Scale anchors:"
    __TXT["TXT_SCAN_HISTORY_NEWEST_FIRST"] := "Scan history (newest first):"
    __TXT["TXT_STATUS_READY"] := "Status: Ready."
    __TXT["TXT_TXT_01"] := "●"
    __TXT_READY := true
}

T(key) {
    global __TXT, __TXT_READY
    if !__TXT_READY
        __BuildTXT()
    if __TXT.Has(key)
        return __TXT[key]
    throw Error("Missing TXT key: " key, -1)
}

Opt(parts*) {
    out := ""
    for _, p in parts {
        if (p = "")
            continue
        out .= (out = "" ? p : " " p)
    }
    return out
}

__SelfLint_Boot() {
    if !InStr(A_AhkVersion, "2.") {
        MsgBox "❌ Script requires AutoHotkey v2.x", "Version Error", 16
        ExitApp
    }
    __BuildTXT()
}

__ErrProp(err, name, default := "") {
    try {
        return err.%name%
    } catch {
        return default
    }
}

__Fatal(err) {
    line := __ErrProp(err, "Line", "?")
    what := __ErrProp(err, "What", "")
    msg  := __ErrProp(err, "Message", "")
    extra := (what != "" ? "`nWhat: " what : "")
    extra .= (msg != "" ? "`nMessage: " msg : "")
    MsgBox(
        "❌ AHK v2 ERROR (guarded)`n`n"
        . "Line: " line
        . extra
        . "`n`nScript stopped to prevent undefined automation state.",
        "CapCut Tool — Self-Lint",
        16
    )
    ExitApp
}

__OnError(err, mode) {
    __Fatal(err)
    return 1
}

__SelfLint_Boot()
OnError(__OnError)

; PATCHABLE_ZONE__BOOT_LINT_END
; ============================================================


; ======================================================================
; AI_SAFEZONE100_BEGIN
; Plain-ASCII safety markers for stable patching + stable runtime.
; RULES (read once, then follow):
;   1) Do NOT insert markers/comments inside control headers or expressions.
;      Bad: if (x ; marker)  |  Good: put marker on its own line.
;   2) Prefer edits ONLY inside clearly marked SAFE modules.
;   3) try/catch MUST be block form: try { ... } catch { ... } (or catch as e { ... }).
;   4) Never use 'return <value>' in the auto-execute (global) section.
;   5) Markers MUST stay as plain ASCII (no emoji) to avoid encoding parser issues.
; AI_SAFEZONE100_END
; ======================================================================


; SAFEZONE PATCH (2026-01-02): Converted 43 one-line try statements to block try { } catch { } to prevent AHK v2 syntax pitfalls.
; ======================================================================================================================
; 🧠 AHK v2 — SYNTAX GUARD (COMMENT + HELPER FUNCTIONS)  |  KHÔNG CHẠY, KHÔNG ẢNH HƯỞNG LOGIC
; ======================================================================================================================
; MỤC TIÊU:
; - Ghi chú “khuyên nhủ” để tránh các lỗi cú pháp AHK v2 hay dính (đặc biệt các lỗi bạn đã gặp: Return ret, Else, Missing "}")
; - Thêm vài helper function chỉ chứa comment (KHÔNG BAO GIỜ được gọi), như “tài liệu sống” ngay trong file.
;
; QUY TẮC VÀNG AHK v2 (dễ dính lỗi nhất):
; 1) ✅ Return ngoài function: CHỈ được "Return" trống (kết thúc auto-execute). ❌ Không được "Return value".
;    - Sai (global / auto-execute):
;         ret := 1
;         Return ret              ; ❌ Error: Return's parameter should be blank except inside a function.
;    - Đúng:
;         ; (A) kết thúc auto-execute:
;         Return                  ; ✅ OK
;         ; (B) cần trả về giá trị -> phải đưa vào function:
;         MyFunc() {
;             ret := 1
;             return ret          ; ✅ OK
;         }
;
; 2) ✅ Else PHẢI “dính” ngay sau If tương ứng (cùng block). ❌ Không được đặt Else sau khi đã đóng block sai chỗ.
;    - Sai (thường gây "Unexpected Else"):
;         if (ok) {
;             ...
;         }
;         Else                    ; ❌ Else đứng lẻ (không attach được)
;             ...
;    - Đúng:
;         if (ok) {
;             ...
;         } else {
;             ...
;         }
;
; 3) ✅ Dấu ngoặc nhọn { } phải cân. Thiếu 1 dấu } là nổ "Missing '}'".
;    - Tip: bật bracket-matching trong editor, hoặc search "{", "}" để đếm block khi nghi ngờ.
;
; 4) ✅ try/catch AHK v2: nên dùng DẠNG BLOCK (đúng yêu cầu dự án của bạn).
;    - Đúng:
;         try {
;             ...
;         } catch {
;             ...
;         }
;    - Tránh one-line / bắt kiểu v1.
;
; 5) ✅ Toán tử "ASSIGN" vs "COMPARE":
;    - GÁN:     x := 123
;    - SO SÁNH: x = 123     (so sánh, thường case-insensitive với chuỗi)
;              x == 123    (so sánh chặt hơn / case-sensitive với chuỗi)
;    - Lỗi hay gặp: viết if (x := 1) thì nó gán luôn -> điều kiện luôn true.
;
; 6) ✅ Nếu dùng biến global trong function, phải khai báo rõ:
;         global gVar
;    - Không khai báo -> có thể thành local, gây lỗi logic khó thấy (không phải cú pháp nhưng rất hay nhầm).
;
; 7) ✅ Gọi function bắt buộc có ngoặc:
;    - Đúng:  Foo()
;    - Sai:   Foo           ; (v2 không “đoán” như v1, dễ phát sinh lỗi/hiểu nhầm)
;
; 8) ✅ Lệnh If/While/For trong v2 dùng biểu thức (expression). Hạn chế dùng kiểu legacy.
;
; 9) ✅ String literal & escape:
;    - Dùng "..." cho chuỗi; dùng `"` để chèn dấu nháy kép.
;    - Backtick ` là ký tự escape chính.
;
; 10) ✅ Khi ghép chuỗi + biến, nhớ dùng toán tử hoặc Format():
;      s := "A=" a " B=" b     ; ✅ concat theo expression
;      s := Format("A={1} B={2}", a, b)
;
; 11) ✅ Dấu phẩy trong function call / array:
;      arr := [1, 2, 3]
;      m := Map("k", "v")
;
; 12) ✅ Với object / map: dùng [] cho index, "." cho property.
;      v := obj["key"]
;      x := obj.Prop
;
; 13) ✅ Các lỗi “hay nổ chương trình” khác:
;      - Gọi biến/hàm chưa tồn tại (NameError)
;      - Thiếu ngoặc đóng ) trong call / expression
;      - Dùng `and/or/not` sai chỗ (nên dùng && || !)
;      - Dính dấu `:`/`?` sai trong ternary (cond ? a : b)
;
; ======================================================================================================================
; ⚙️ HELPER FUNCTIONS (CHỈ LÀ TÀI LIỆU - KHÔNG GỌI)
; ======================================================================================================================
__AHKv2_Syntax_Guard__DO_NOT_CALL() {
    ; KHÔNG BAO GIỜ gọi function này.
    ; Mục đích: làm “neo” để bạn search nhanh trong file: "SYNTAX GUARD", "DO_NOT_CALL", "__WARN_"
    ;
    ; Nếu muốn kiểm tra nhanh cú pháp:
    ; - Lỗi Return ret: tìm "Return " + giá trị ngoài function
    ; - Lỗi Unexpected Else: tìm "Else" và xem nó có dính ngay sau "if" không
    ; - Lỗi Missing "}": tìm block mới mở gần nhất trước dòng báo lỗi
    return
}

__WARN_Return_Outside_Function__DO_NOT_CALL() {
    ; ✅ Auto-execute (global scope) chỉ cho phép: Return (trống)
    ; ❌ Không được: Return value
    ; Nếu cần “báo kết quả”: đặt logic vào function rồi return trong function.
    return
}

__WARN_Else_Attach_Rule__DO_NOT_CALL() {
    ; ✅ else phải đi kèm if ngay lập tức:
    ; if (...) {
    ; } else {
    ; }
    ; ❌ Tránh:
    ; if (...) { }
    ; Else
    return
}

__WARN_TryCatch_BlockOnly__DO_NOT_CALL() {
    ; ✅ Chuẩn dự án: try { ... } catch { ... }
    ; Không dùng one-line.
    return
}

__WARN_Brace_Balance__DO_NOT_CALL() {
    ; ✅ Mỗi { phải có một } tương ứng.
    ; Tip: khi gặp Missing "}", hãy:
    ; - nhìn lên trên: block nào mới mở mà chưa đóng?
    ; - kiểm tra các chỗ "if {" / "try {" / "loop {" / "for {" / "while {"
    return
}

__WARN_Assign_VS_Compare__DO_NOT_CALL() {
    ; ✅ GÁN: :=   | ✅ SO SÁNH: = hoặc ==
    ; Tránh gán trong if/while trừ khi bạn thực sự muốn.
    return
}

; ======================================================================================================================
; END SYNTAX GUARD
; ======================================================================================================================

; ======================================================================
; ⚠️ IMPORTANT – AHK v2 SYNTAX SAFETY NOTICE (DO NOT IGNORE)
;
; This script is **AutoHotkey v2** (STRICT braces).
; - Every `{` MUST have a matching `}`. Extra/missing braces => "Unexpected }"
; - When editing via ChatGPT: ONLY insert code INSIDE existing blocks.
; - DO NOT add/remove standalone `{` or `}` lines unless absolutely required.
;
; ✅ PERFORMANCE NOTE (IDOL FAST MODE)
; Legacy PixelGetColor-per-sample is VERY slow (can cause 10–60s waits).
; IDOL FAST MODE replaces it with a single bitmap capture + LockBits sampling
; to keep multi-icon AutoLearn within ~1–2 seconds in most cases.
; ======================================================================
; ======================================================================
; 🧠 IMAGE-BASED UI AUTOMATION – 5 LAYER + LOGIC GLUE (IDOL DEV)
; ======================================================================
; Mục tiêu: quét ROI theo THỨ TỰ bạn sắp xếp → nhận diện ảnh → click theo kịch bản.
; Đây là "UI script bằng hình ảnh", KHÔNG phải full-screen search / chọn candidate tốt nhất.
;
; KIẾN TRÚC (6 LAYER):
;   [GUI EDITOR]  → bạn kéo ROI + đánh số thứ tự
;        ↓
;   [L0: LOGIC GLUE]        – điều phối đúng trình tự, retry/timeout (không đoán)
;   [L1: ROI MAP]           – danh sách ROI theo thứ tự kịch bản (chỉ dữ liệu)
;   [L2: CAPTURE]           – chụp pixel ROI (không logic)
;   [L3: AL CHECK]          – kiểm tra ảnh ROI (YES/NO)
;   [L4: STEP CONTROLLER]   – não: bước hiện tại, retry, sang bước
;   [L5: ACTION]            – tay: click/key/drag theo lệnh
;
; CORE RULE:
;   ROI   = BẢN ĐỒ
;   CAP   = LẤY PIXEL
;   AL    = MẮT
;   STEP  = NÃO
;   ACTION= TAY
;
; FAST MODE (F4):
;   - CAP_FAST_MODE = true  → SCREEN capture ROI trực tiếp (KHÔNG full parent rect)
;   - AL_FAST_MODE  = true  → stride>=2, minCells>=6 (ROI-only, nhanh)
;   - GUI_MODE="RUN"    → GUI mờ + click-through (không chặn chuột), KHÔNG hide
;
; GUI POLICY (MỚI – KHÓA AI/DEV):
;   - KHÔNG dùng hide/show GUI cho F3/F4.
;   - Dùng GUI_MODE + HOTSPOT:
;       RUN  = GUI mờ + click-through (vẫn click được desktop/app bên dưới)
;       EDIT = GUI rõ nét + nhận chuột để chỉnh ROI/trình tự
;   - Mọi logic capture/AL phải ROI-only (không full rect) khi FAST.
;
; ======================================================================

; ======================================================================
; 🧠 DEBUG IMAGE SAVE POLICY (IDOL DEV – GIỮ NHANH NHƯNG VẪN CÓ ẢNH SOI ROI)
; ======================================================================
; - AL/CAP xử lý ảnh trong RAM; file .bmp chỉ để CON NGƯỜI kiểm tra ROI/split/crop.
; - FAST MODE (F4) KHÔNG được save mỗi vòng (disk IO sẽ giết tốc độ).
; - Thay vào đó: THROTTLE save (mỗi N vòng) + TÊN FILE DUY NHẤT (KHÔNG GHI ĐÈ).
; - F3 (setup/learn) vẫn ưu tiên save đầy đủ để bạn nhìn đúng ROI.
;
global DEBUG_SAVE_IMAGE := true         ; bật/tắt xuất ảnh debug
global DEBUG_SAVE_EVERY := 20          ; throttle: mỗi N vòng save 1 ảnh
global DBG_SAVE_CNT := 0               ; đếm vòng để throttle
global DBG_SAVE_SEQ := 0               ; seq để đảm bảo tên file không trùng
global DBG_LAST_TPL_PATH := ""         ; giữ path ảnh tpl gần nhất đã save

; ===============================
; GLOBAL STATE – F4 CAPTURE ORDER
; ===============================
global g_F4_Index := 0          ; số thứ tự ảnh F4 (001,002,…)
global g_F4_IsBusy := false     ; khóa chống double-trigger
global g_F4_LastTick := 0       ; anti-spam / debounce (nếu cần)
global g_F4_InitDone := false   ; init index 1 lần (scan file), tránh ghi đè
; ===============================
