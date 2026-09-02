# Feature — Administration

## Fichiers
- `admin_screen.dart` — Vue admin complète
- `admin_view_model.dart` — State + logique de création de réservations

## Accès
- Visible uniquement si `MockData.currentUser.role == UserRole.admin`
- Tab "Admin" apparaît dans le `MainScaffold` uniquement pour les admins
- Changer `MockData.currentUser` vers `adminUser` pour tester la vue admin

## Fonctionnement
1. **Stats row** : nombre de terrains, total réservations, réservations confirmées
2. **Formulaire de création** :
   - Terrain (dropdown)
   - Date (date picker)
   - Heure de début (dropdown créneaux)
   - Durée : 1h, 2h, 3h ou 4h (selector)
   - Inviter des joueurs : liste de tous les joueurs (multi-sélection)
3. `createBooking()` crée **une réservation par joueur invité** (chaque joueur a sa propre entrée)
4. `isAdminBooking: true` sur les `BookingModel` créés par l'admin
5. Message de succès affiché via SnackBar après création

## AdminBookingForm (state interne)
- `isValid` : courtId + date + startTime + au moins 1 joueur invité
- `invitedUserIds` : multi-select avec toggle

## Migration Firestore
- Remplacer `MockData.courts` et `MockData.allUsers` par des Repository
- `createBooking()` : écrire dans `bookings/` via `BookingRepository.create()`
- Envoyer notifications push aux joueurs invités via Firebase Messaging
