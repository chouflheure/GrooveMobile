# Feature — Profil

## Fichiers
- `profile_screen.dart` — Vue complète avec CustomScrollView
- `profile_view_model.dart` — State (user courant + bookings, Firestore live)

## Sections
1. **Header** : avatar, nom, classement FFT, localisation, rating, matchs/mois (fond gradient vert)
2. **Stats grid** : matchs joués, heures jouées (victoires et win rate retirés)
3. **Réservations à venir** : `upcomingBookings` (non passées + confirmées)
4. **Historique** : `pastBookings` (toutes les réservations passées, avec ou sans résultat enregistré)
5. **Settings** : Notifications, Paramètres, Déconnexion (placeholders)

Le dernier élément du `CustomScrollView` (spacer sous Settings) inclut `MediaQuery.paddingOf(context).bottom` pour ne pas passer sous la bottom nav bar (même pattern que `courts_screen.dart`).

## Computed getters (ProfileState)
- `pastBookings` : bookings dont la date est passée (`isPast`), peu importe si un résultat/score a été renseigné
- `upcomingBookings` : bookings non passés et non annulés

## Firestore (déjà branché)
`ProfileViewModel` watch `BookingRepository.watchByUser(currentUser.id)` en temps réel. `addBooking()`/`updateBooking()`/`cancelBooking()` écrivent directement dans Firestore (collection `bookings`) — voir `data/repositories/booking_repository.dart`.
`user` reste `MockData.currentUser` (pas d'auth Firebase pour l'instant).
