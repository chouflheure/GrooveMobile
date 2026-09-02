# Feature — Profil

## Fichiers
- `profile_screen.dart` — Vue complète avec CustomScrollView
- `profile_view_model.dart` — State (user courant + bookings)

## Sections
1. **Header** : avatar, nom, classement FFT, localisation, rating, matchs/mois (fond gradient vert)
2. **Stats grid 2x2** : matchs joués, victoires, win rate (calculé), heures jouées
3. **Surfaces préférées** : 3 progress bars (Terre battue, Dur, Gazon)
4. **Réservations à venir** : `upcomingBookings` (non passées + confirmées)
5. **Historique** : `pastBookings` (passées avec résultat W/L)
6. **Settings** : Notifications, Paramètres, Déconnexion (placeholders)

## Computed getters (ProfileState)
- `pastBookings` : bookings avec `result != null` et date passée
- `upcomingBookings` : bookings non passés et non annulés

## addBooking()
Appelé depuis `CourtsScreen` et `CourtDetailScreen` après confirmation d'une réservation. Met à jour la liste locale.

## Migration Firestore
- `user` : lire `users/{currentUserId}` au démarrage (+ écoute snapshot)
- `bookings` : query `bookings` where `userId == currentUserId`, orderBy `date desc`
