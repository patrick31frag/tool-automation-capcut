# Scale.ahk Modularization Progress

## Overview
This document tracks the progress of splitting the monolithic `scale.ahk` (12,697 lines) into 10 modular files for better maintainability and collaboration.

## Completed Modules ✓

### 1. scale_modules/config.ahk (~360 lines)
**Status:** ✅ COMPLETE
**Contents:**
- Text map system (`__BuildTXT()`, `T()`)
- INI helpers (`IniReadSafe`, `IniWriteSafe`, `EnsureIniFile`)
- Debug flags and global defaults
- Self-lint boot functions
- Debug helper functions (`DBG__ShouldSaveTpl`, `DBG__MakeUniqueBmpPath`)
- Decision trace helpers (`__DECIDE_Log`, `__TEST_DiagSet`)
- Click policy explanation
- Global state flags (ST_*, SEG_*, FILT_*, BEH_*, MODEL_*, MATCH_*)

### 2. scale_modules/core/logging.ahk (~60 lines)
**Status:** ✅ COMPLETE
**Contents:**
- `IsLogLevel(x)`
- `Log(msg, level, src)`
- `LogWarn(msg, src)`
- `LogError(msg, src)`
- `LogRuntimeError(e, mode)` - Error handler hook

### 3. scale_modules/core/dllwrap.ahk (~195 lines)
**Status:** ✅ COMPLETE
**Contents:**
- `SC_DllCall(fn, params*)` - Safe DllCall wrapper
- `SC_IsMap(x)`, `SC_IsArray(x)`, `SC_TryGet(m, k, def)`
- `CAP_SM(n)` - GetSystemMetrics wrapper
- `CAP_GetVirtualDesktop(&vx, &vy, &vw, &vh)`
- `CAP_GetSystemDPI()`, `CAP_GetWindowDPI(hwnd, sysDpi)`
- `CAP_GetMonitorIndexForPoint(x, y, &total)`
- `CAP_Log(msg, level)`, `CAP_KV(stage, capId, kv, level)`
- `CAP_IsWindowVisible(hwnd)`
- `CAP_DetectTargetType(hwnd)` - Browser/Game/App detection
- `CAP_GetBestPrintWindowHwnd(hwnd)` - Chromium child window finder

### 4. scale_modules/core/rect.ahk (~370 lines)
**Status:** ✅ COMPLETE
**Contents:**
- `class Rect` - Main rectangle class with properties (L, T, R, B, W, H, CenterX, CenterY)
- `class ParentContext` - Parent region context
- `class Candidate` - Candidate region
- `class ElementModel` - UI element model
- `class BehaviorSignature` - Behavior validation signature
- `SC_RectUnpack(srcRect, &L, &T, &R, &B)` - Unpack various rect formats
- `SC_RectUnpack_SAFE(srcRect, &L, &T, &R, &B)` - Safe unpack with string support
- `SC_IsRectLike(r)` - Validate rect-like object
- `RectAbsToWnd(hwnd, rectAbs)` - Convert screen to window coordinates
- `IsNum(v)`, `ToIntSafe(v, def)`, `TimeKeySafe(s)` - Type conversion helpers
- `ReverseArray(arr)` - Reverse array in-place
- `AL_ArraySort(arr, cmpFn)` - Stable merge sort
- `AL_ArrGet(arr, idx, default)` - Safe array access
- `AL_RelToScreen(parentRect, relRect)` - Convert relative to screen coordinates
- `AL_ExpandRect(r, pad)` - Expand rect by padding
- `AL_Clamp(x, lo, hi)` - Clamp value to range
- `AL_IoU(r1, r2)` - Intersection over Union
- `AL_RectInside(a, b, containThr, areaFracMax)` - Check if rect inside another
- `GDI_BitBlt_FromHWND(hwnd, rectWnd, cap)` - Capture from window
- `GDI_BitBlt_FromScreen(rectAbs, cap)` - Capture from screen

### 5. scale_modules/core/bmp.ahk (~400 lines)
**Status:** ✅ COMPLETE
**Contents:**
- `SC_BmpGetSize(path, &w, &h)` - Read BMP dimensions from file
- `SC_BmpGetBitCount(path, &bpp)` - Read BMP bit depth
- `SC_BmpProbeAlphaAndBlack(path, &alphaAllZero, &rgbAllZero)` - Detect DXGI alpha issues
- `SC_BmpCropFile(srcPath, dstPath, x, y, cw, ch, flattenOnWhite)` - Crop and convert BMP
- `SC_BmpFlattenTo24(path, flattenOnWhite)` - Convert 32-bit to 24-bit BMP in-place

## Modules To Be Created 🔨

### 6. scale_modules/core/capture.ahk (~2200 lines)
**Status:** ⏳ TODO
**Priority:** HIGH
**Key Functions to Extract:**
- `EnsureGdip(silent)` - Initialize GDI+
- `CAP_BeginDesktopCapture()`, `CAP_EndDesktopCapture(st)` - GUI hide/show for capture
- `_GdipGetEncoderClsid(mime)`, `AL_GdipGetEncoderClsid(mime)` - Encoder lookup
- `CAP_CopyRect_DXGI(rectAbs)` - DXGI Desktop Duplication capture
- `AL_GdipBitmapFromScreenRect(r, cap)` - Screen capture with GDI+
- `AL_GdipBitmapFromHWNDRect(hwnd, r, cap)` - Window capture
- `AL_GdipBitmapFromHWNDBitBlt(hwnd, r, cap)` - Window capture via BitBlt
- `AL_GdipSaveBitmapToFile(pBitmap, outPath, cap)` - Save bitmap
- `AL_GdipDisposeImage(pBitmap)`, `AL_GdipShutdown()` - Cleanup
- `AL_Capture_RectToBMP(screenRect, outPath, opt)` - High-level capture
- `AL_Capture_ReadPixelGrid(screenRect, stride)` - Read pixel grid for analysis
- `AL_Capture_ReadPixelGrid_IDOL(screenRect, stride)` - IDOL-mode pixel grid
**Line Range:** ~1537-3779

### 7. scale_modules/core/match.ahk (~350 lines)
**Status:** ⏳ TODO
**Priority:** HIGH
**Key Functions to Extract:**
- `MakeEmptyAnchorPack()` - Create empty anchor pack structure
- `CountAnchorHits(x, y, anchors, thr)` - Count matching anchors
- `SaveImageListsToIni()` - Persist image lists
- `RefreshDiaCombo()`, `RefreshScaCombo()` - Update combo boxes
- `FindBestMatch(imgList, region, pack, &outX, &outY)` - Template matching with retry
- `ImageSearchOne(img, L, T, R, B, &x, &y)` - Single image search
- `LearnAnchorPack(x, y, &packOut)` - Learn anchor points
- `VerifyAnchorPack(x, y, pack, thr, needCluster, needH, needV)` - Verify anchors
- `ColorNear(c1, c0, thr)` - Color distance check
- `RefineByLAxes(*, *)` - L-shaped axis refinement
- `MakeCachedRegion(*)` - Create cached search region
**Line Range:** ~5200-5630

### 8. scale_modules/gui/gui_main.ahk (~500 lines)
**Status:** ⏳ TODO
**Priority:** MEDIUM
**Key Functions to Extract:**
- GUI creation code (inside `PATCHABLE_ZONE_GUI_BEGIN/END` markers)
- `g := Gui(...)` - Main GUI creation
- All `g.Add*()` control creation calls
- Event bindings (`*.OnEvent("Click", ...)`)
- Module registry (`UI_MODULES := Map()`)
- Tab creation and setup
- `InitGuiHotspot()`, `SetGuiMode()`
**Line Range:** ~12438-12690 (PATCHABLE_ZONE_GUI section)

### 9. scale_modules/gui/gui_state.ahk (~400 lines)
**Status:** ⏳ TODO
**Priority:** MEDIUM
**Key Functions to Extract:**
- `SetStatus(msg)` - Update status text
- `UI__Heartbeat()` - Periodic UI update
- `UI_UpdateGui(force)` - Main UI update logic
- `UI_OnModuleChange(*)` - Module selection handler
- `UI_ModuleNameToIndex(name)`, `UI_ShowModule(name)` - Module navigation
- `UI_OnMainGuiSize(guiObj, minMax, width, height)` - Window resize
- `UI_UpdateStateBadge()` - Update state indicator
- `UI_ApplyEnablePolicy(force)` - Enable/disable controls based on state
- `UI_OnAutoHideToggle(*)` - Auto-hide toggle
- `UI_TestDiamondClick(*)` - Test diamond click
- `UI_ToggleAdvanced(*)`, `UI_SetAdvancedVisible(show)` - Advanced panel
- `UI_OnRunStart()`, `UI_OnRunStop()` - Run state changes
- `UI_ResetUiOnly()` - Reset UI state
- `UI_SetState(state, reason, timeoutMs)` - Set UI state
- `UI_CheckTimeout()`, `UI_SyncState()` - State synchronization
**Line Range:** ~3874-4760

### 10. scale_modules/gui/overlay.ahk (~450 lines)
**Status:** ⏳ TODO
**Priority:** MEDIUM  
**Key Functions to Extract:**
- `Border_SetTopMost(hwnd)`, `Border_BringOrderInputsToTop()` - Border Z-order
- `ShowRectOverlay(L, T, R, B, ms)` - Temporary rectangle highlight
- `UpdateBorderRect(x1, y1, x2, y2)` - Update border position
- `Border_ClearLinesForce(reason)` - Clear border lines
- `Border_EnsureLabel(i)`, `Border_DrawLabel(i, rectOrL, labelText)` - Border labels
- `F3OverlayMakeKey(it)` - Generate F3 overlay key
- `F3__RefreshRoiCombo()` - Refresh ROI combo
- `F3OverlayToggle()`, `F3OverlayShow()`, `F3OverlayHide()` - F3 overlay visibility
- `F3OverlayEnsureGui()`, `F3OverlayDestroyCtrls()`, `F3OverlayRebuild()` - F3 overlay construction
- `F3OverlayComputeNext()`, `F3OverlayUpdateLabels()` - F3 overlay state
- `F3OverlayClearAll()`, `F3OverlayAssign(idx, ord, mode)` - F3 order management
- `F3OverlayHitTest(x, y)` - Mouse hit testing
- `F3Overlay_*` window message handlers
- `F3GuiToggleBorders()`, `F3GuiEnsureBordersOn()`, `F3GuiShowParentBorder()` - Border toggle
**Line Range:** ~4846-9500 (border/overlay functions scattered)

### 11. scale_modules/logic.ahk (~3000+ lines)
**Status:** ⏳ TODO
**Priority:** CRITICAL
**Key Functions to Extract:**
- `Init()` - Main initialization function (line 12249)
- `InitDpiGuard()` - DPI awareness setup
- `ToggleRun()`, `StopRun()` - Start/stop automation
- `RunStep()` - Main automation step
- `DoOne(cycIdx)` - Execute one cycle
- `F2Handler()`, `F3Handler()` - F2/F3 hotkey handlers
- `F4__InitIndexOnce()`, `F4_Queue(doClick)`, `F4__Do(doClick)` - F4 learn diamond
- `AL_L1_ManualParentPick(store)` - Layer 1: Manual parent region pick
- `AL_L2_Segment(parentCtx, opts)` - Layer 2: Segmentation
- `AL_L3_Filter(parentCtx, candidates, opts)` - Layer 3: Filtering
- `AL_L4_Extract(parentCtx, filtered, store, opts)` - Layer 4: Extraction
- `AL_L5_LearnBehavior(parentCtx, elementModel, store, opts)` - Layer 5: Behavior learning
- `AL_L5_TestBehavior(*)`, `AL_L5_VerifyBehavior(*)` - Behavior testing/verification
- `AL_F4_RunFast(doClick)`, `AL_F4_AutoLearn(doClick)` - F4 fast/auto modes
- `AL_PickRegionDrag()`, `AL_ClickCenterRect(screenRect)` - Region picking
- `AL_DefaultOpts()` - Default options
- `AL_PickAnchors(*)`, `AL_ComputeDiffMetrics(*)`, `AL_RegionMetricsFromGrid(*)` - Analysis helpers
- `AL_SigFromMetrics(*)` - Signature extraction
- `PreflightOK()`, `PreflightStateOK()` - Pre-flight checks
- F3 ROI management functions (`SetF3OrderCombo`, `F3OrderOnChange`, `F3RoiOnChange`, etc.)
- F3 overlay functions (`F3__ApplyOrderFromF4`, `F3__SortRoiItems`, `F3__CompareRoi`)
- Combo box event handlers (Dia*, Sca*, F3*, Parent*)
- History management functions
- Save/Load INI functions
**Line Range:** Multiple sections throughout file (583-12697)

### 12. scale_modules/main.ahk (~100 lines)
**Status:** ✅ STUB CREATED
**Priority:** HIGH
**Purpose:** Entry point that includes all modules and initializes the application
**Should Contain:**
- `#Requires AutoHotkey v2.0`
- `#Include <Gdip_All>`
- Module includes in dependency order
- Hotkey registrations (F1, F2, F3, F4, ^F4, ESC)
- `Init()` call
- Keep script running directive

## Dependency Order

The modules must be included in this order to satisfy dependencies:

```autohotkey
#Include scale_modules\core\logging.ahk       ; No dependencies
#Include scale_modules\core\dllwrap.ahk       ; Uses Log()
#Include scale_modules\core\rect.ahk          ; Uses helpers
#Include scale_modules\core\bmp.ahk           ; No module dependencies
#Include scale_modules\config.ahk             ; Uses Log()
#Include scale_modules\core\capture.ahk       ; Uses all core modules
#Include scale_modules\core\match.ahk         ; Uses capture, rect
#Include scale_modules\gui\gui_state.ahk      ; Uses config, core
#Include scale_modules\gui\overlay.ahk        ; Uses gui_state, rect
#Include scale_modules\gui\gui_main.ahk       ; Uses gui_state, overlay, config
#Include scale_modules\logic.ahk              ; Uses all modules
```

## Testing Strategy

1. **Unit Testing:** Each module should be testable independently
2. **Integration Testing:** Verify module includes work correctly
3. **Functional Testing:** 
   - Test F1 (Start/Stop) functionality
   - Test F2 (Scan) functionality
   - Test F3 (Pick region) functionality
   - Test F4 (Learn diamond) functionality
   - Test GUI interactions
   - Test automation workflow

## Migration Guidelines

When extracting functions to modules:

1. **Do NOT modify function logic** - Only move code
2. **Keep all comments** - Especially PATCHABLE_ZONE markers
3. **Preserve global variables** - They may be referenced across modules
4. **Test after each module** - Ensure no regressions
5. **Update main.ahk includes** - Add module includes as you create them

## Benefits of Modular Structure

- ✅ **Easier Code Review:** Reviewers can focus on specific modules
- ✅ **Reduced Merge Conflicts:** Multiple developers can work on different modules
- ✅ **Better Organization:** Clear separation of concerns
- ✅ **Easier Testing:** Modules can be tested independently
- ✅ **Improved Maintainability:** Smaller files are easier to understand
- ✅ **Faster Development:** Clear boundaries make changes safer

## Current Status Summary

- **Completed:** 5/12 modules (42%)
- **Lines Extracted:** ~1,385 lines
- **Lines Remaining:** ~11,312 lines
- **Estimated Work Remaining:** 6-8 hours

## Next Steps

1. ✅ Create core modules (logging, dllwrap, rect, bmp, config)
2. ⏳ Extract capture module (large, ~2200 lines)
3. ⏳ Extract match module (~350 lines)
4. ⏳ Extract GUI modules (gui_main, gui_state, overlay)
5. ⏳ Extract logic module (largest, ~3000+ lines)
6. ⏳ Create complete main.ahk with all includes
7. ⏳ Test full workflow
8. ⏳ Update documentation

## Notes

- The original `scale.ahk` file remains unchanged for backward compatibility
- New modular structure is in `scale_modules/` directory
- Both structures will coexist during migration phase
- Final step will be to update entry point to use modular version
