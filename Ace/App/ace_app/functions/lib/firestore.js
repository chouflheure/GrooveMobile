const admin = require("firebase-admin");

/** Deletes every ref in `refs`, chunked to stay under Firestore's 500
 * writes-per-batch limit. */
async function deleteAll(refs) {
  const chunkSize = 400;
  for (let i = 0; i < refs.length; i += chunkSize) {
    const chunk = refs.slice(i, i + chunkSize);
    const batch = admin.firestore().batch();
    chunk.forEach((ref) => batch.delete(ref));
    await batch.commit();
  }
}

module.exports = { deleteAll };
