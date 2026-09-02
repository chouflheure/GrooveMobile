# Feature — Détail d'un Terrain

## Fichiers
- `court_detail_screen.dart` — Vue complète avec SliverAppBar hero

## Fonctionnement
1. Reçoit un `CourtDetailArgs` (`court` + `initialSlot?`) via `GoRouter extra` (pas de rechargement réseau), mais le screen est un `ConsumerStatefulWidget` qui watch `courtsViewModelProvider` et affiche la version à jour du terrain dès qu'elle est disponible (fallback sur le snapshot le temps du premier chargement)
2. Si `initialSlot` est fourni (tap sur un créneau depuis `CourtCard`), il est présélectionné à l'ouverture
3. Affiche galerie (hero image), infos rapides (type, surface, prix — plus de note/rating), description, adresse (cliquable, ouvre Maps ; "Pas renseigné" si vide), équipements
4. La liste de créneaux est construite depuis `court.freeSlots` (créneaux `isAvailable: true`)
5. Sélection d'un créneau → bouton "Réserver" actif dans la `BottomBar`
6. Tap "Réserver" → `BookingConfirmationScreen` → `ProfileViewModel.addBooking()`

## Firestore (déjà branché)
`CourtsViewModel` (`courts/courts_view_model.dart`) combine en temps réel :
- `CourtRepository.watchAll()` — les terrains (collection `courts`)
- `BookingRepository.watchBookedSlotsForDate()` — les créneaux réservés (collection `bookings`), pour la date de `AppConstants.defaultBookingDate()` (pas encore de sélecteur de date dans l'UI)

et recalcule `court.availableSlots` en conséquence. Une réservation retire donc son créneau de la liste partout où `courtsViewModelProvider` est observé, y compris sur cet écran.
