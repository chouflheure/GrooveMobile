# Feature — Communauté

## Fichiers
- `community_screen.dart` — Screen principal avec deux tabs
- `community_view_model.dart` — State (tab actif, annonces, conversations)
- `chat_screen.dart` — Écran de chat temps réel (simulé localement)
- `propose_slot_modal.dart` — Modal de création d'annonce

## Tab Annonces
- Feed des `AnnouncementModel` triées par date de création
- "Je suis dispo !" → `toggleInterested()` dans le ViewModel (optimistic update)
- "Proposer un créneau" → `ProposeSlotModal` → création locale + ajout en tête de liste

## Tab Messages
- Liste des `ConversationModel` avec badge unread
- Tap → `ChatScreen` (gestion locale des messages dans l'état local du widget)
- `onSend` remonte au ViewModel pour mettre à jour `lastMessage`

## Règles
- `interestedUserIds` contient les IDs des joueurs ayant cliqué "Je suis dispo"
- Un joueur ne peut pas être intéressé deux fois (toggle)
- `ProposeSlotModal` requiert terrain + message (validation `isValid`)

## Migration Firestore
- Annonces : `onSnapshot` sur collection `announcements` (temps réel)
- Messages : `onSnapshot` sur `conversations/{id}/messages` (temps réel)
- Remplacer `MockData.conversations` par `ConversationRepository.streamForUser(userId)`
