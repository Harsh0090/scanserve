# KOT Printing with KDS Filtering — Implementation Plan

Written for: the developers on the scanserve Flutter app.

## 1. Goal

When an order is placed at the counter, the app automatically prints a Kitchen Order Ticket (KOT) on the kitchen printer. The KOT must include only items whose KDS status is ON. Items with KDS OFF (for example tea or cigarettes) must never appear on the kitchen printout.

## 2. Current state (what already exists)

The feature is mostly built. This plan closes the remaining gaps rather than starting from scratch.

| Requirement | Where it lives today | Status |
|---|---|---|
| Auto-print on order placement | `lib/src/services/auto_kot_print_service.dart` — `AutoKotPrintManager.handleNewOrder` listens to the `new_order` socket event | Done |
| Auto-print of add-on items | Same file — `handleOrderModified` prints only `newItems` as an ADD-ON KOT | Done |
| Filter out KDS-OFF items | `lib/src/services/kot_print_service.dart` — `KotPrintService.printKOT` drops items where `skipKitchen == true` | Done |
| Skip the print when nothing is left | `printKOT` returns early when `kitchenItems` is empty | Done |
| Direct Bluetooth print, backend fallback | `printKOT` tries `BluetoothPrinterService.printKOTDirect` first, then `POST /api/print/kot` (PrintNode) | Done |
| Avoid double print (MenuModal + socket echo) | `locallyPrintedOrderIds` plus the 1.5s `localPrintGrace` | Done |
| KDS-aware push notification | `lib/src/services/kds_notification_filter.dart` | Done |
| Tests | `test/kot_print_service_test.dart`, `test/auto_kot_print_service_test.dart`, `test/kds_notification_filter_test.dart`, `test/kds_push_notification_test.dart` | 47 tests pass (baseline run) |

### Naming decision: use `skipKitchen`, not `isKdsOn`

The request suggests adding an `isKdsOn` boolean to the item model. **Do not add it.** The codebase already stores this state as `skipKitchen`, and the backend (`Backend/src/controllers/globalMenu.controller.js`) persists it that way. The meaning is inverted:

- `skipKitchen == false` (or missing) means KDS ON. The item prints on the KOT.
- `skipKitchen == true` means KDS OFF. The item is excluded.

Adding a second field would create two sources of truth that can drift apart. If a model-level getter is wanted for readability, add one that delegates to the existing field:

```dart
bool get isKdsOn => skipKitchen != true;
```

Use that getter in new code. Keep `skipKitchen` as the stored field.

## 3. Gaps to close

These are the items not yet covered. Each was found by reading the code; none is confirmed as a live bug.

1. **Backend double-check is unverified.** The client filters items before calling `POST /api/print/kot`. I did not read the backend print controller to confirm it also drops `skipKitchen` items. If it does not, a client bug could send KDS-OFF items to PrintNode. Action: read the print controller and add a server-side filter if it is missing.
2. **`src/` and `lib/` have drifted.** `lib/src/app/components/MenuModal.dart` and `src/app/components/MenuModal.dart` differ. The `lib/` copy has the add-on local-print registration (`addOnLocalKey`, 30-second `locallyPrintedOrderIds` entry). The `src/` copy does not. The project memory says `F5` runs `src/main.dart` while `flutter run` and builds use `lib/`, so any fix must go into both copies. Action: port the `lib/` add-on block to `src/`, or decide which copy is canonical and delete the other.
3. **Which printer is "the kitchen printer"?** The spec says the print goes to the printer in the kitchen. The current code sends to whichever printer is saved on the device (Bluetooth) or to the PrintNode `printerName`/`printNodePrinterId` on the account. If the counter device is paired with the counter printer, the KOT prints at the counter. Action: confirm the intended routing with the owner and document it. This is a product decision, not a code change.
4. **Auto-print depends on settings.** `shouldAutoPrint` only prints when `liveOrderKOT` is ON (or the order sets `skipAutoPrint: false`). If the setting is OFF, the order goes to the Orders page with a "PRINT KOT" prompt instead. The spec says "automatically", so confirm that the default for new accounts is ON.
5. **Empty-KOT visibility.** When every item is KDS OFF, `printKOT` returns silently with a debug log. Staff get no feedback. Action (optional): show a small snackbar, such as "No kitchen items — nothing printed", only for manual prints from the Orders page, not for auto-print.

## 4. Implementation phases

### Phase 1 — Verify the backend filter (investigation, no code yet)

- Open the backend print controller for `/api/print/kot`.
- Check whether it removes items where `skipKitchen === true` before building the PrintNode job.
- Write down the result in this document.

### Phase 2 — Server-side safety net (only if Phase 1 finds no filter)

- Filter `items` in the print controller with `items.filter(i => i.skipKitchen !== true)`.
- Return `400` or `200 {printed: false}` when no items remain. Do not send an empty job to PrintNode.
- Add a backend test for: mixed items, all KDS OFF, and a missing `skipKitchen` field (must count as ON).

### Phase 3 — Client model helper

- Add `bool get isKdsOn => skipKitchen != true;` to the item model that `OrderItem` represents (`kot_print_service.dart`).
- Switch the filter in `printKOT` to `isKdsOn` for the `OrderItem` branch. The `Map` branches keep `raw['skipKitchen'] != true`, since they carry no model.
- No behavior change. This is a readability change only.

### Phase 4 — Sync the two app copies

- Port the add-on local-print block from `lib/src/app/components/MenuModal.dart` (around line 400) into `src/app/components/MenuModal.dart`.
- Make sure `src/` imports `auto_kot_print_service.dart` the same way `lib/` does.
- Apply every change from Phases 3 and 5 to both `lib/` and `src/`.

### Phase 5 — Optional empty-KOT feedback

- In `OrdersPage._printKOT` (`lib/src/app/dashboard/orders/page.dart`, around line 502), check the result of the filter before calling `printKOT`. If nothing is left, show a snackbar.
- Do not change auto-print behavior.

### Phase 6 — Tests

Add or confirm these cases. Most already exist; the new ones are marked **new**.

| Case | File | Status |
|---|---|---|
| Mixed items: only KDS ON items reach the printer | `kot_print_service_test.dart` | Exists (`filters out skipKitchen items`) |
| All items KDS OFF: no print call, no backend call | `kot_print_service_test.dart` | Exists |
| Item with `skipKitchen` missing is treated as KDS ON | `kot_print_service_test.dart` | **New** |
| `OrderItem.isKdsOn` returns the expected value for true, false, and null | `kot_print_service_test.dart` | **New** |
| `new_order` with a KDS OFF-only order does not auto-print | `auto_kot_print_service_test.dart` | Exists (`_hasKitchenItems`) |
| `order_modified` with only KDS OFF add-ons does not print | `auto_kot_print_service_test.dart` | **New** (confirm) |
| Bluetooth path receives the same filtered list as the backend path | `kot_print_service_test.dart` | **New** |
| Backend returns no job when all items are KDS OFF | backend tests | **New** (Phase 2) |

Run: `flutter test test/kot_print_service_test.dart test/auto_kot_print_service_test.dart test/kds_notification_filter_test.dart test/kds_push_notification_test.dart`

### Phase 7 — Device verification

Use the emulator setup in the project memory (`device-testing-setup.md`):

1. Log in as an owner. Set `liveOrderKOT` ON.
2. Add one KDS ON item and one KDS OFF item (for example tea). Place the order at the counter.
3. Confirm the printed KOT (or the PrintNode job log) lists only the KDS ON item.
4. Add a KDS OFF item to the existing order. Confirm no add-on KOT prints.
5. Add a KDS ON item to the existing order. Confirm an ADD-ON KOT prints with only that item.

## 5. Files touched

| File | Change |
|---|---|
| `lib/src/services/kot_print_service.dart` | Add `isKdsOn` getter; use it in `printKOT` (Phase 3) |
| `src/services/kot_print_service.dart` | Mirror of the above (Phase 4) |
| `lib/src/app/components/MenuModal.dart` | No change expected |
| `src/app/components/MenuModal.dart` | Port the add-on local-print block (Phase 4) |
| `lib/src/app/dashboard/orders/page.dart` and `src/...` | Optional empty-KOT snackbar (Phase 5) |
| `test/kot_print_service_test.dart` | New cases (Phase 6) |
| Backend print controller | Only if Phase 1 finds no filter (Phase 2) |

## 6. Acceptance criteria

- A KOT never contains an item whose `skipKitchen` is `true`, on either the Bluetooth path or the PrintNode path.
- An order with no KDS ON items produces no print job.
- Missing `skipKitchen` is treated as KDS ON.
- `lib/` and `src/` behave the same.
- All tests in Phase 6 pass.
- The device check in Phase 7 passes.

## 7. Open questions for the owner

1. Should the KOT go to the counter printer or to a separate kitchen printer? If it is a separate kitchen printer, which one is it: a second Bluetooth device or a PrintNode printer?
2. Should auto-print be ON by default for new accounts?
3. Is the existing `skipKitchen` label in the UI ("KITCHEN ALERT ON" / "NO KITCHEN ALERT") the wording you want staff to see?
