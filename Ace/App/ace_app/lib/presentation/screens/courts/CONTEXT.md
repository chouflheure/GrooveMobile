# Feature — Listing des Terrains

## Fichiers
- `courts_screen.dart` — Vue principale
- `courts_view_model.dart` — Logique (filtres, recherche, chargement, disponibilité live)

## Fonctionnement
1. `CourtsViewModel` combine en temps réel `CourtRepository.watchAll()` (collection Firestore `courts`) et `BookingRepository.watchBookedSlotsForDate()` (collection `bookings`) pour ne montrer que les créneaux réellement libres
2. `CourtsState.filteredCourts` applique le filtre actif + la recherche textuelle
3. Taper sur un créneau dans `CourtCard` navigue directement vers `/court/:id` avec ce créneau présélectionné (`CourtDetailArgs.initialSlot`) — plus de sélection inline dans la card
4. Un tap sur le reste de la card navigue aussi vers `/court/:id` (extra: `CourtDetailArgs`, sans `initialSlot`)
5. La réservation (partenaire, confirmation) se fait entièrement sur l'écran de détail via `BookingConfirmationScreen` → `ProfileViewModel.addBooking()`

## Filtres disponibles
`Tous | Extérieur | Intérieur | Terre battue | Dur | Gazon`
Définis dans `AppConstants.surfaceTypes`
