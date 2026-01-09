; ==================================================================================================
;  CapCut Scale Tool (AHKv2) — MODULAR STRUCTURE
; --------------------------------------------------------------------------------------------------
;  Main entry point that includes all modules in correct dependency order
; ==================================================================================================

#Requires AutoHotkey v2.0
#Include <Gdip_All>

; ============================================================
; MODULE INCLUDES (in dependency order)
; ============================================================

; Core modules (no dependencies on other modules)
#Include scale_modules\core\logging.ahk
#Include scale_modules\core\dllwrap.ahk
#Include scale_modules\core\rect.ahk
#Include scale_modules\core\bmp.ahk

; Config module (depends on logging for Log() function)
#Include scale_modules\config.ahk

; Initialize self-lint and error handling early
__SelfLint_Boot()
OnError(__OnError)

; Register runtime error logger and GDI+ shutdown early
OnError(LogRuntimeError)
OnExit(AL_GdipShutdown)

; ============================================================
; NOTE: Remaining code from scale.ahk will be included below
; This includes:
; - core/capture.ahk functions (EnsureGdip, AL_Gdip*, CAP_*, AL_Capture_*)
; - core/match.ahk functions (ImageSearchOne, FindBestMatch, Anchor functions)
; - gui/gui_main.ahk functions (GUI creation)
; - gui/gui_state.ahk functions (UI state management)
; - gui/overlay.ahk functions (Border overlays, F3 overlay)
; - logic.ahk functions (Init, ToggleRun, RunStep, DoOne, F2/F3/F4 handlers, AutoLearn)
;
; TODO: Extract these sections into their respective module files
; ============================================================
