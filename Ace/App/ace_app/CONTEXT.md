# CourtConnect — Contexte Global du Projet

## Vue d'ensemble
Application de réservation de terrains de tennis multi-plateforme (Android, iOS, Web) développée en **Flutter**, avec un backend **Firebase Firestore** (en cours de mise en place). En attendant Firestore, toutes les données sont **mockées localement**.

---

## Stack technique

| Technologie | Usage |
|---|---|
| Flutter | Framework UI multi-plateforme |
| Riverpod (`StateNotifierProvider`) | State management (pattern MVVM) |
| GoRouter | Navigation déclarative + deep links |
| Firestore | Backend (à connecter — mock actif pour l'instant) |
| Firebase Auth | Authentification Magic Link (à implémenter) |
| intl | Internationalisation (locale fr_FR) |
| equatable | Comparaison d'objets dans les models |
| uuid | Génération d'IDs locaux |

---

## Architecture

**Atomic Architecture + MVVM** :

```
lib/
├── core/
│   ├── constants/     # AppColors, AppTypography, AppSpacing, AppConstants
│   ├── theme/         # AppTheme (MaterialTheme light)
│   └── router/        # GoRouter (appRouter)
│
├── data/
│   ├── models/        # User, Court, Booking, Announcement, Message, TimeSlot
│   ├── mock/          # MockData (données de test statiques)
│   └── repositories/  # (à implémenter — connexion Firestore)
│
└── presentation/
    ├── atoms/         # AppButton, AppBadge, AppAvatar, AppSearchField, AppSurfaceProgress
    ├── molecules/     # CourtCard, TimeSlotChip, StatCard, AnnouncementCard, BookingHistoryItem, ConversationItem
    ├── organisms/     # BookingModal
    ├── templates/     # MainScaffold (navigation + bottom nav)
    └── screens/
        ├── courts/         # CourtsScreen + CourtsViewModel
        ├── court_detail/   # CourtDetailScreen
        ├── community/      # CommunityScreen + ChatScreen + ProposeSlotModal + CommunityViewModel
        ├── profile/        # ProfileScreen + ProfileViewModel
        └── admin/          # AdminScreen + AdminViewModel
```

---

## Screens

| Screen | Route | Description |
|---|---|---|
| Listing des terrains | `/courts` | Recherche + filtres surface/type + créneaux inline |
| Détail d'un terrain | `/court/:id` | Galerie, infos, créneaux, booking flow |
| Communauté — Annonces | `/community` (tab 1) | Feed d'annonces joueurs, "Je suis dispo" |
| Communauté — Messages | `/community` (tab 2) | Liste conversations + écran de chat |
| Profil | `/profile` | Stats, surfaces préférées, historique réservations |
| Admin | `/admin` | Réservations multi-joueurs, vue globale |

---

## Règles métier

- **Réservation** : toujours 2 joueurs minimum (le réservant + 1 partenaire choisi)
- **Durée standard** : 1h30 pour les joueurs ; 1h à 4h pour l'admin
- **Paiement** : simulé (pas de Stripe pour l'instant)
- **Classement** : système FFT français (N.C., 40, 30/5…, -30)
- **Rôles** : `UserRole.player` (vue normale) / `UserRole.admin` (tab Admin visible + création de réservations multi-personnes)
- **Auth** : Magic Link Firebase (à implémenter — login page à créer)
- **Notifications push** : prévues (Firebase Messaging à connecter)

---

## Données mockées (MockData)

Fichier : `lib/data/mock/mock_data.dart`

- **currentUser** : Alexandre Dupont (joueur, 15/2)
- **adminUser** : Club Manager (admin)
- **allUsers** : 5 joueurs + 1 admin
- **courts** : 5 terrains (Philippe Chatrier, Central Indoor, Arthur Ashe, Wimbledon, Montmartre)
- **bookings** : 6 réservations (4 passées avec scores, 2 à venir)
- **announcements** : 3 annonces communauté
- **conversations** : 3 conversations avec messages

---

## Connexion Firestore (à faire)

Collections prévues :
- `users/{userId}` — profils, stats, surfaces, classement
- `courts/{courtId}` — terrains, caractéristiques
- `availability/{courtId}/slots/{date}` — créneaux par date
- `bookings/{bookingId}` — réservations
- `announcements/{announcementId}` — annonces communauté
- `conversations/{conversationId}/messages/{messageId}` — messagerie

Migration : remplacer `MockData.xxx` par les `Repository` correspondants dans chaque ViewModel.

---

## Décisions techniques

- **Riverpod `StateNotifier`** (pas de code generation pour l'instant) pour rester simple avant Firestore
- **GoRouter `ShellRoute`** pour partager le `MainScaffold` entre les routes principales
- **Atomic Architecture** : les Atoms ne dépendent de rien, les Molecules dépendent des Atoms, etc.
- **Pas de BLoC** : MVVM avec Riverpod est suffisant pour la complexité actuelle
