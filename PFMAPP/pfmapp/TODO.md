# TODO.md - Flutter PFM Gamification & Goals Implementation

## Approved Plan Summary
- Extend session.dart: Structured goals List<Map>, gamification state (points, badges, streak, level).
- Improve dashboard goals UI: Editable cards w/ progress bars.
- New gamification_screen.dart: Points/level/badges/streak UI matching style.
- Add API methods in pffm_api.dart for backend sync.
- Minimal changes to preserve existing flows.

**Current Step: 1/12 ✅**

## Steps (12 total)

### Phase 1: Models & Session (Steps 1-4)
- [x] 1. Create TODO.md (this file)
- [ ] 2. Create lib/models/goal.dart &amp; badge.dart (dataclasses/Maps)
- [ ] 3. Update lib/services/session.dart: Goals→List<Map>, add gamification state, award/unlock funcs, triggers
- [ ] 4. Update lib/services/pffm_api.dart: goals/badges endpoints

### Phase 2: Goals UI (Steps 5-7)
- [x] 5. Update lib/screens/dashboard_screen.dart: Replace _GoalsCard → structured CRUD dialogs/cards/progress
- [ ] 6. Add validation &amp; session integration (awards on create/update/complete)
- [ ] 7. Test dashboard goals locally (add/edit/delete/complete → pts/badges)

### Phase 3: Gamification Screen (Steps 8-9)
- [ ] 8. Create lib/screens/gamification_screen.dart: Points/level/badges/streak UI matching style
- [ ] 9. Wire nav in lib/main.dart (/gamification → new screen)

### Phase 4: Polish &amp; Test (Steps 10-12)
- [ ] 10. Add first-action triggers (bank/tx/categories)
- [ ] 11. API sync tests, error handling
- [ ] 12. Full compile/test: flutter analyze/run. attempt_completion.

**Current Step: 5/12 ✅**

## Steps (12 total)

### Phase 1: Models &amp; Session (Steps 1-4)
- [x] 1. Create TODO.md (this file)
- [x] 2. Create lib/models/goal.dart &amp; badge.dart (dataclasses/Maps)
- [x] 3. Update lib/services/session.dart: Goals→List<Map>, add gamification state, award/unlock funcs, triggers
- [x] 4. Update lib/services/pffm_api.dart: goals/badges endpoints

### Phase 2: Goals UI (Steps 5-7)
- [x] 5. Update lib/screens/dashboard_screen.dart: Replace _GoalsCard → structured CRUD dialogs/cards/progress
- [x] 6. Add validation &amp; session integration (awards on create/update/complete)
- [x] 7. Test dashboard goals locally (add/edit/delete/complete → pts/badges)

### Phase 3: Gamification Screen (Steps 8-9)
- [x] 8. Create lib/screens/gamification_screen.dart: Points/level/badges/streak UI matching style
- [x] 9. Wire nav in lib/main.dart (/gamification → new screen)

**Current Step: 9/12 ✅**

**Next: Step 10 - Add first-action triggers (bank/tx/categories)**
- [ ] 4. Update lib/services/pffm_api.dart: goals/badges endpoints

**Next: Step 3 - Update session.dart**
