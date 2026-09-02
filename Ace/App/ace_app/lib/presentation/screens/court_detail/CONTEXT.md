# Feature — Détail d'un Terrain

## Fichiers
- `court_detail_screen.dart` — Vue complète avec SliverAppBar hero, calendrier 10 jours, sélection de créneau

## Fonctionnement
1. Reçoit un `CourtDetailArgs` (`court` + `initialSlot?`) via `GoRouter extra` (pas de rechargement réseau au premier affichage)
2. Le screen watch en live `_courtByIdProvider(court.id)` (Firestore `courts/{id}`) pour le template du terrain, et `_bookedSlotsProvider((courtId, date))` (Firestore `bookings`, filtré sur `_selectedDate`) pour les créneaux déjà pris ce jour-là — les deux sont recombinés à chaque frame pour produire les créneaux réellement disponibles
3. `_DateSelector` affiche 10 jours à partir d'aujourd'hui (`AppConstants.today()` / `AppConstants.bookingCalendarDays`). Changer de jour réinitialise le créneau sélectionné et redéclenche la requête `_bookedSlotsProvider` pour ce jour
4. Affiche galerie (hero image), infos rapides (type, surface, prix — masqué si `pricePerHour <= 0`), description, adresse (cliquable, ouvre Maps ; "Pas renseigné" si vide), équipements (fond blanc, texte noir)
5. La liste de créneaux est construite depuis `court.freeSlots` (créneaux `isAvailable: true` pour le jour sélectionné)
6. Sélection d'un créneau → bouton "Réserver" actif dans la `BottomBar`
7. Tap "Réserver" → `BookingConfirmationSheet.show()` (bottom sheet à 70% de l'écran, sans image du terrain) → `ProfileViewModel.addBooking()` avec la date sélectionnée (plus de date figée sur "demain")
