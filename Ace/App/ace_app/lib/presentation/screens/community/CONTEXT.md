# Feature — Communauté

## Fichiers
- `community_screen.dart` — Screen principal avec deux tabs
- `community_view_model.dart` — State (tab actif, annonces, conversations) + providers Firestore
- `chat_screen.dart` — Écran de chat, messages streamés en temps réel depuis Firestore
- `propose_slot_modal.dart` — Modal de création/édition d'annonce

## Firestore (branché)
Deux collections :
- `broadcasts` — une annonce par document (`AnnouncementModel.toJson()`). CRUD via `BroadcastRepository` (`lib/data/repositories/broadcast_repository.dart`). `interestedUserIds` est modifié via `FieldValue.arrayUnion`/`arrayRemove` (atomique, pas de compteur séparé à resynchroniser — `interestedCount` est recalculé depuis la taille du tableau dans `AnnouncementModel.fromJson`).
- `messages` — un document par message, à plat (pas de sous-collection par conversation). Chaque message porte `conversationId` + `participantIds` (dénormalisé). `MessageRepository` (`lib/data/repositories/message_repository.dart`) :
  - `conversationIdFor(userIdA, userIdB)` — id déterministe (ids triés + joints), donc pas besoin de vérifier/créer une conversation au préalable
  - `watchConversationsForUser(userId, resolveName: ...)` — un seul listener sur tous les messages où l'utilisateur est participant (`array-contains`), regroupés côté client par `conversationId` pour produire les `ConversationModel` (dernier message + unread count). Pas de collection `conversations` séparée.
  - `watchMessagesForConversation(conversationId)`, `sendMessage(...)`, `markConversationRead(...)`

Index composites requis (déjà dans `firestore.indexes.json`, déployés) :
- `messages` : `conversationId ASC, createdAt ASC`
- `messages` : `participantIds ARRAY_CONTAINS, createdAt DESC`

Règles Firestore (`firestore.rules`) : lecture publique sur les deux collections, écriture ouverte (contrairement à `users`, pas encore scopée par `request.auth` — à durcir plus tard).

## Auth / invités
Poster une annonce, "Je suis dispo", envoyer un message et lancer une conversation nécessitent un compte (voir `_requireAuth` dans `community_screen.dart`, qui redirige vers `/login` si `currentUserProvider` est `null`). Parcourir les annonces reste possible sans compte. Le tab Messages affiche un message "Connecte-toi pour discuter" pour les invités.

## Tab Annonces
- Feed des `AnnouncementModel` (stream `BroadcastRepository.watchAll()`), triées par `createdAt desc`, filtrées côté client (créneau passé depuis +2h retiré)
- "Je suis dispo !" → `toggleInterested()` (écrit dans Firestore)
- "Proposer un créneau" → `ProposeSlotModal` → écrit dans `broadcasts` (id assigné par le repository à la création)

## Tab Messages
- Liste des `ConversationModel` dérivée du stream `messages` (badge unread calculé depuis les messages non lus dont l'expéditeur n'est pas l'utilisateur courant)
- Tap → `ChatScreen(conversationId, otherUserId, otherUserName, otherUserInitials)` — plus de `ConversationModel` complet passé en argument, juste l'id déterministe + les infos d'affichage
- `ChatScreen` marque la conversation comme lue à l'ouverture (`markConversationRead`)

## Règles
- `interestedUserIds` contient les IDs des joueurs ayant cliqué "Je suis dispo"
- Un joueur ne peut pas être intéressé deux fois (toggle, `arrayUnion`/`arrayRemove`)
- `ProposeSlotModal` requiert terrain + message (validation `isValid`)

## Utilisateurs
Les noms affichés (auteur d'annonce, participants de conversation) sont résolus via `allUsersProvider` (collection Firestore `users`, partagée avec le reste de l'app — voir `screens/auth/auth_view_model.dart`). Plus de `MockData.allUsers`.
