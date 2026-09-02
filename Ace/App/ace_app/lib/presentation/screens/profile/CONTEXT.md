# Feature — Profil

## Fichiers
- `profile_screen.dart` — Vue complète avec CustomScrollView
- `profile_view_model.dart` — State (user courant + bookings, Firestore live)

## Sections
1. **Header** : avatar, nom, classement FFT, localisation, rating, matchs/mois (fond gradient vert)
2. **Stats grid** : matchs joués, heures jouées (victoires et win rate retirés)
3. **Réservations à venir** : `upcomingBookings` (non passées + confirmées)
4. **Historique** : `pastBookings` (toutes les réservations passées, avec ou sans résultat enregistré)
5. **Settings** : Notifications, Paramètres, Déconnexion (déconnexion réelle via `AuthViewModel.signOut()` → redirection `/login`)

## Invité (pas connecté)
Si `currentUserProvider` vaut `null`, l'écran affiche `_GuestProfilePrompt` (CTA "Se connecter") au lieu du contenu du profil — pas de crash, pas d'accès aux stats/réservations tant qu'on n'est pas connecté.

Le dernier élément du `CustomScrollView` (spacer sous Settings) inclut `MediaQuery.paddingOf(context).bottom` pour ne pas passer sous la bottom nav bar (même pattern que `courts_screen.dart`).

## Computed getters (ProfileState)
- `pastBookings` : bookings dont la date est passée (`isPast`), peu importe si un résultat/score a été renseigné
- `upcomingBookings` : bookings non passés et non annulés

## Firestore + Auth (déjà branché)
`ProfileViewModel` watch `BookingRepository.watchByUser(userId)` en temps réel, où `userId` vient de `currentUserProvider` (voir `screens/auth/auth_view_model.dart`) — le ViewModel se recrée (et re-souscrit) quand l'utilisateur change (connexion/déconnexion). `addBooking()`/`updateBooking()`/`cancelBooking()` écrivent directement dans Firestore (collection `bookings`).
L'utilisateur courant est un vrai compte Firebase Auth + document Firestore `users/{uid}` — plus de `MockData.currentUser`. `EditProfileScreen` écrit via `UserRepository.update()`.
